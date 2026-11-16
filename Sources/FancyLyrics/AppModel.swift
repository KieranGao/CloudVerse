import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers
import LyricsCore

@MainActor
final class AppModel: ObservableObject {
    let preferences: Preferences
    @Published private(set) var snapshot: PlaybackSnapshot?
    @Published private(set) var document = LyricDocument(lines: [])
    @Published private(set) var candidates: [SongCandidate] = []
    @Published private(set) var selectedSong: SongCandidate?
    @Published private(set) var playbackStatus = "正在连接播放器…"
    @Published private(set) var lyricStatus = "等待播放信息"
    @Published private(set) var needsPermission = false
    @Published private(set) var isDemo = false
    @Published private(set) var isLoading = false
    @Published private(set) var artwork: NSImage?
    @Published private(set) var artworkColor: Color?
    private let reader = PlaybackReader()
    private let service: MusicService
    private var timer: Timer?
    private var requestTask: Task<Void, Never>?
    private var requestID = UUID()
    private var readGeneration = 0
    private var reading = false
    private var artworkData: Data?
    private var continuity = PlaybackContinuity()
    private var forceLyricRefresh = false
    private var controlTask: Task<Void, Never>?
    private var controlToken = UUID()
    private var automaticallySelected = false
    @Published private(set) var reconnecting = false
    @Published private(set) var controlStatus = ""
    @Published private(set) var controlling = false

    init(preferences: Preferences, service: MusicService = MusicService()) {
        self.preferences = preferences
        self.service = service
    }

    var isPlaying: Bool { (snapshot?.rate ?? 0) > 0 }
    var canControl: Bool { snapshot != nil && !isDemo && !reconnecting && preferences.bridgeEnabled && !controlling }
    var displayStatus: String {
        if reconnecting { return "连接短暂中断，正在重新读取…" }
        if snapshot == nil { return playbackStatus }
        return lyricStatus
    }

    func send(_ command: PlayerCommand) {
        guard canControl, let before = snapshot else { return }
        controlling = true
        let token = UUID()
        controlToken = token
        controlStatus = "正在操作网易云…"
        controlTask = Task {
            let result = await PlayerController().send(command)
            guard controlToken == token, !isDemo, !Task.isCancelled else { return }
            guard result.accepted else {
                controlling = false
                controlStatus = result.reason
                return
            }
            var confirmed = false
            for _ in 0..<5 {
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard controlToken == token, !isDemo, !Task.isCancelled else { return }
                let fresh: PlaybackReading = await withCheckedContinuation { continuation in
                    reader.read(bridgeEnabled: preferences.bridgeEnabled) { continuation.resume(returning: $0) }
                }
                guard controlToken == token, !isDemo, !Task.isCancelled else { return }
                if let after = fresh.snapshot, command.observed(before: before, after: after) { confirmed = true; break }
            }
            guard controlToken == token, !isDemo, !Task.isCancelled else { return }
            poll()
            controlling = false
            controlStatus = confirmed ? "播放器已确认操作" : "命令已发送但未确认变化；请检查网易云"
        }
    }
    var accent: Color {
        preferences.albumColor && preferences.theme == .aurora ? artworkColor ?? preferences.theme.accent : preferences.theme.accent
    }

    func start() {
        guard timer == nil else { return }
        poll()
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func position(at date: Date) -> Double {
        guard let snapshot else { return 0 }
        if isDemo {
            let elapsed = max(0, date.timeIntervalSince(snapshot.sampledAt))
            return (elapsed.truncatingRemainder(dividingBy: snapshot.track.duration)) + preferences.offset
        }
        return snapshot.position(at: date) + preferences.offset
    }

    func poll() {
        guard !isDemo, !reading else { return }
        reading = true
        let generation = readGeneration
        reader.read(bridgeEnabled: preferences.bridgeEnabled) { [weak self] result in
            guard let self else { return }
            self.reading = false
            guard generation == self.readGeneration, !self.isDemo else { return }
            self.playbackStatus = result.status
            self.needsPermission = result.needsPermission
            let accepted = self.continuity.accept(result.snapshot, at: Date())
            self.reconnecting = result.snapshot == nil && accepted != nil
            if let snapshot = accepted {
                let changed = self.snapshot?.track.key != snapshot.track.key
                let durationArrived = (self.snapshot?.track.duration ?? 0) == 0 && snapshot.track.duration > 0
                self.snapshot = snapshot
                if !changed, durationArrived, self.automaticallySelected, let song = self.selectedSong,
                   song.duration > 0, abs(song.duration - snapshot.track.duration) > 8 {
                    self.reloadLyrics()
                }
                if changed {
                    self.readGeneration += 1
                    self.setArtwork(result.artwork)
                    self.reloadLyrics()
                } else if let data = result.artwork, data != self.artworkData {
                    self.setArtwork(data)
                }
            } else {
                self.snapshot = nil
                self.clearLyrics()
                self.lyricStatus = "播放信息不可用"
                self.setArtwork(nil)
            }
        }
    }

    func reloadLyrics(forceRefresh: Bool = false) {
        guard let track = snapshot?.track, !isDemo else { return }
        forceLyricRefresh = forceRefresh
        clearLyrics()
        search(query: "\(track.title) \(track.artist)", automatic: true)
    }

    func searchManual(_ query: String) {
        guard snapshot != nil, !isDemo else {
            lyricStatus = "请先连接正在播放的歌曲，或使用演示模式"
            return
        }
        search(query: query, automatic: false)
    }

    private func search(query: String, automatic: Bool) {
        guard let track = snapshot?.track else { return }
        requestTask?.cancel()
        let id = UUID()
        requestID = id
        isLoading = true
        lyricStatus = "正在搜索歌词…"
        requestTask = Task { [weak self, service] in
            do {
                let songs = try await service.search(query)
                try Task.checkCancellation()
                guard let self, self.requestID == id, self.snapshot?.track.key == track.key, !self.isDemo else { return }
                let currentTrack = self.snapshot?.track ?? track
                self.candidates = SongMatcher.ranked(songs, for: currentTrack)
                self.isLoading = false
                if automatic, let candidate = SongMatcher.automatic(songs, for: currentTrack) {
                    self.select(candidate, automatic: true)
                } else {
                    self.lyricStatus = songs.isEmpty ? "未找到歌词；可导入本地 LRC / YRC" : "请在设置中确认歌曲版本"
                }
            } catch {
                guard let self, self.requestID == id, !Task.isCancelled else { return }
                self.isLoading = false
                self.lyricStatus = error.localizedDescription
            }
        }
    }

    func select(_ song: SongCandidate, automatic: Bool = false) {
        guard let track = snapshot?.track, !isDemo else { return }
        automaticallySelected = automatic
        requestTask?.cancel()
        let id = UUID()
        requestID = id
        selectedSong = song
        document = LyricDocument(lines: [])
        isLoading = true
        lyricStatus = "正在获取歌词…"
        let force = forceLyricRefresh
        forceLyricRefresh = false
        requestTask = Task { [weak self, service] in
            do {
                let lyrics = try await service.lyrics(songID: song.id, forceRefresh: force)
                try Task.checkCancellation()
                guard let self, self.requestID == id, self.snapshot?.track.key == track.key, !self.isDemo else { return }
                self.document = lyrics
                self.isLoading = false
                self.lyricStatus = lyrics.lines.isEmpty ? "服务未提供此版本歌词；可选其他版本或导入 LRC" : (lyrics.hasWordTiming ? "逐字歌词 · 已同步" : "逐行歌词 · 已同步")
            } catch {
                guard let self, self.requestID == id, !Task.isCancelled else { return }
                self.isLoading = false
                self.selectedSong = nil
                self.lyricStatus = error.localizedDescription
            }
        }
    }

    func toggleDemo() {
        readGeneration += 1
        controlTask?.cancel()
        controlToken = UUID()
        controlling = false
        controlStatus = ""
        continuity = PlaybackContinuity()
        reconnecting = false
        clearLyrics()
        isDemo.toggle()
        if isDemo {
            snapshot = PlaybackSnapshot(track: Track(title: "城市的另一面", artist: "FancyLyrics 原创演示", album: "Night Walk", duration: 36), elapsed: 0, rate: 1)
            document = DemoContent.document
            playbackStatus = "演示模式 · 非网易云实际播放数据"
            lyricStatus = "原创演示 · 模拟逐字时间轴"
            needsPermission = false
            setArtwork(nil)
        } else {
            snapshot = nil
            playbackStatus = "正在连接播放器…"
            poll()
        }
    }

    func importLyrics() {
        guard let trackKey = snapshot?.track.key else {
            lyricStatus = "请先连接歌曲或开启演示，再导入歌词"
            return
        }
        let scope = SelectionScope(trackKey: trackKey, generation: readGeneration)
        let panel = NSOpenPanel()
        panel.title = "导入当前歌曲的 UTF-8 歌词"
        panel.allowedContentTypes = ["lrc", "yrc", "txt"].compactMap { UTType(filenameExtension: $0) }
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard scope.permits(trackKey: snapshot?.track.key, generation: readGeneration) else {
            lyricStatus = "导入已取消：播放歌曲或模式已改变，请重新选择歌词"
            return
        }
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            guard (attributes[.size] as? NSNumber)?.intValue ?? 0 <= 5 * 1024 * 1024 else { throw MusicError.responseTooLarge }
            let content = try String(contentsOf: url, encoding: .utf8)
            let words = LyricParser.yrc(content)
            let imported = LyricDocument(lines: words.isEmpty ? LyricParser.lrc(content) : words)
            guard !imported.lines.isEmpty else { throw MusicError.invalidPayload }
            requestTask?.cancel()
            requestID = UUID()
            isLoading = false
            document = imported
            selectedSong = nil
            lyricStatus = "本地歌词 · \(url.lastPathComponent)"
        } catch { lyricStatus = "导入失败：\(error.localizedDescription)" }
    }

    private func clearLyrics() {
        requestTask?.cancel()
        requestID = UUID()
        document = LyricDocument(lines: [])
        selectedSong = nil
        candidates = []
        isLoading = false
    }

    private func setArtwork(_ data: Data?) {
        artworkData = data
        artwork = data.flatMap(NSImage.init(data:))
        artworkColor = artwork.flatMap(Self.sampleColor)
    }

    private static func sampleColor(_ image: NSImage) -> Color? {
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 12, pixelsHigh: 12, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        image.draw(in: NSRect(x: 0, y: 0, width: 12, height: 12))
        NSGraphicsContext.restoreGraphicsState()
        var best: NSColor?
        var bestScore: CGFloat = 0
        for x in 0..<12 {
            for y in 0..<12 {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
                let score = color.saturationComponent * color.brightnessComponent
                if score > bestScore { best = color; bestScore = score }
            }
        }
        guard let best, bestScore > 0.08 else { return nil }
        return Color(nsColor: NSColor(calibratedHue: best.hueComponent, saturation: min(best.saturationComponent, 0.65), brightness: max(0.85, best.brightnessComponent), alpha: 1))
    }
}

 enum DemoContent {
    static var document: LyricDocument {
        let phrases = ["灯光在街角慢慢醒来", "晚风把喧嚣留在身后", "让这一刻停在旋律里", "我们向着有光的地方走"]
        let translations = ["The city lights begin to wake", "Leave the noise behind with the breeze", "Let this moment live inside the melody", "We walk toward the light"]
        let lines = phrases.enumerated().map { index, phrase in
            let start = Double(index) * 9 + 0.6
            let words = phrase.enumerated().map { offset, character in
                LyricWord(text: String(character), start: start + Double(offset) * 0.52, duration: 0.52)
            }
            return LyricLine(start: start, text: phrase, words: words, translation: translations[index])
        }
        return LyricDocument(lines: lines)
    }
}
