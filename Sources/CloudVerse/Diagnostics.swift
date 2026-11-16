import AppKit
import SwiftUI
import LyricsCore

@MainActor
enum Diagnostics {
    static func smokeCheck() -> Bool {
        NSApp.setActivationPolicy(.prohibited)
        let suite = "CloudVerse.Diagnostics.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else { return false }
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = Preferences(defaults: defaults)
        let model = AppModel(preferences: preferences)
        let host = NSHostingView(rootView: SettingsView(model: model, preferences: preferences, resetPosition: {}))
        host.frame = NSRect(x: 0, y: 0, width: 820, height: 700)
        host.layoutSubtreeIfNeeded()
        let panel = NSHostingView(rootView: ControlPanelView(model: model, preferences: preferences, openSettings: {}, resetPosition: {}, dismiss: {}))
        panel.frame = NSRect(x: 0, y: 0, width: 370, height: 690)
        panel.layoutSubtreeIfNeeded()
        let longWords = (0..<100).map { index in LyricWord(text: "长", start: Double(index), duration: 1) }
        let longLine = LyricLine(start: 0, text: String(repeating: "长", count: 100), words: longWords, translation: "Long lyric pagination diagnostic")
        for theme in LyricTheme.allCases {
            for fontSize in [20.0, 42.0, 72.0] {
                for tone in InkTone.allCases {
                    for line in [longLine, LyricLine(start: 0, text: String(repeating: "中文 English 长句完整排版。", count: 12), translation: "A long translation that should remain readable across two lines.")] {
                        let preview = NSHostingView(rootView: LyricCard(theme: theme, accent: theme.accent, title: "诊断样例", artist: "本地数据", line: line, next: "下一句", time: 55, fontSize: fontSize, showTranslation: true, status: "诊断", demo: true, locked: true, previous: "上一句", tone: tone, showMetadata: true))
                        preview.frame = NSRect(x: 0, y: 0, width: 388, height: WallpaperLayout.height(theme: theme, fontSize: fontSize, translation: true, previous: true, next: true, metadata: true) - 32)
                        preview.layoutSubtreeIfNeeded()
                    }
                }
            }
        }
        model.toggleDemo()
        let success = model.isDemo && model.document.hasWordTiming && model.document.lines.count == 4
        print(success ? "SMOKE PASS: settings, \(LyricTheme.allCases.count) themes, demo, no network or accessibility prompt" : "SMOKE FAIL")
        return success
    }

    static func networkCheck() {
        Task {
            do {
                let service = MusicService(cacheDirectory: URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".build/network-check-cache"))
                let songs = try await service.search("Say Goodbye LODONI")
                guard let song = songs.first else { throw MusicError.invalidPayload }
                let document = try await service.lyrics(songID: song.id)
                print("NETWORK PASS: search returned \(songs.count) candidates; lyric endpoint decoded \(document.lines.count) lines; YRC=\(document.hasWordTiming)")
                NSApp.terminate(nil)
            } catch {
                print("NETWORK FAIL: \(error.localizedDescription)")
                exit(1)
            }
        }
    }

    static func integrationCheck() {
        let reader = PlaybackReader()
        reader.read { reading in
            guard let snapshot = reading.snapshot else {
                print("INTEGRATION FAIL: \(reading.status)")
                exit(1)
            }
            Task {
                do {
                    let service = MusicService(cacheDirectory: URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".build/integration-check-cache"))
                    let songs = try await service.search("\(snapshot.track.title) \(snapshot.track.artist)")
                    guard let candidate = SongMatcher.automatic(songs, for: snapshot.track) else {
                        print("INTEGRATION NEEDS CONFIRMATION: playback available, \(songs.count) candidates, manual version selection required")
                        exit(2)
                    }
                    let document = try await service.lyrics(songID: candidate.id)
                    let position = snapshot.position(at: Date())
                    let index = document.index(at: position)
                    print("INTEGRATION PASS: playback → matched song → \(document.lines.count) lyric lines; position=\(Int(position)); activeLine=\(index.map(String.init) ?? "intro"); YRC=\(document.hasWordTiming)")
                    NSApp.terminate(nil)
                } catch {
                    print("INTEGRATION FAIL: \(error.localizedDescription)")
                    exit(1)
                }
            }
        }
    }

    static func controlCheck(action: String) {
        Task {
            if action == "check" {
                let result = await Task.detached { BridgeClient().control(action: "check") }.value
                print("CONTROL TARGET: \(result.reason)")
                exit(result.accepted ? 0 : 1)
            }
            guard let command = PlayerCommand(rawValue: action) else { print("CONTROL FAIL: unsupported command"); exit(1) }
            let reader = PlaybackReader()
            func sample() async -> PlaybackReading {
                await withCheckedContinuation { continuation in reader.read { continuation.resume(returning: $0) } }
            }
            guard let before = await sample().snapshot else { print("CONTROL FAIL: no playback data"); exit(1) }
            let result = await PlayerController().send(command)
            guard result.accepted else { print("CONTROL FAIL: \(result.reason)"); exit(1) }
            for _ in 0..<5 {
                try? await Task.sleep(nanoseconds: 700_000_000)
                if let after = await sample().snapshot, command.observed(before: before, after: after) {
                    print("CONTROL PASS: \(action); actual playback change observed; rate=\(after.rate); trackChanged=\(before.track.key != after.track.key)")
                    exit(0)
                }
            }
            print("CONTROL FAIL: command submitted but no change observed")
            exit(1)
        }
    }

    static func monitorSync() {
        let suite = "CloudVerse.Monitor.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else { exit(1) }
        let preferences = Preferences(defaults: defaults)
        let model = AppModel(preferences: preferences)
        model.start()
        Task {
            for sample in 0..<8 {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                let time = model.position(at: Date())
                let index = model.document.index(at: time)
                print("SYNC sample=\(sample) elapsed=\(Int(time)) rate=\(model.snapshot?.rate ?? -1) timestampAge=\(Int(model.snapshot.map { Date().timeIntervalSince($0.sampledAt) } ?? -1)) lines=\(model.document.lines.count) active=\(index.map(String.init) ?? "none") loading=\(model.isLoading) state=\(model.lyricStatus)")
            }
            defaults.removePersistentDomain(forName: suite)
            NSApp.terminate(nil)
        }
    }

    static func playbackCheck() {
        let reader = PlaybackReader()
        reader.read { result in
            print("PLAYBACK STATUS: \(result.status)")
            if let snapshot = result.snapshot {
                print("PLAYBACK DATA: title available; duration=\(snapshot.track.duration); position=\(snapshot.position(at: Date())); rate=\(snapshot.rate)")
            } else {
                print("PLAYBACK UNAVAILABLE: no real-time integration verified")
            }
            NSApp.terminate(nil)
        }
    }
}
