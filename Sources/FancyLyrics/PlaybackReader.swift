import AppKit
import ApplicationServices
import LyricsCore

struct PlaybackReading {
    let snapshot: PlaybackSnapshot?
    let artwork: Data?
    let status: String
    let needsPermission: Bool
}

final class PlaybackReader {
    private typealias InfoFunction = @convention(c) (DispatchQueue, @escaping (CFDictionary?) -> Void) -> Void
    private let framework: UnsafeMutableRawPointer?
    private let queue = DispatchQueue(label: "FancyLyrics.Playback", qos: .utility)

    init() {
        framework = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_LAZY)
    }

    func read(bridgeEnabled: Bool = true, completion: @escaping (PlaybackReading) -> Void) {
        let finish: (PlaybackReading) -> Void = { reading in
            DispatchQueue.main.async { completion(reading) }
        }
        queue.async { [self] in
            if let info = mediaInfo(), let snapshot = snapshot(from: info) {
                finish(PlaybackReading(snapshot: snapshot, artwork: info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data, status: "系统正在播放 · 私有 API，可能因系统更新失效", needsPermission: false))
                return
            }
            if bridgeEnabled {
                let probe = BridgeClient().probe()
                if let result = probe.playback {
                    finish(PlaybackReading(snapshot: result.snapshot, artwork: result.artwork, status: "网易云系统媒体时间轴 · 本地适配", needsPermission: false))
                    return
                }
                if let source = probe.otherSource {
                    finish(PlaybackReading(snapshot: nil, artwork: nil, status: "系统媒体源被 \(source) 占用；请在网易云点播放后重新同步", needsPermission: false))
                    return
                }
            }
            guard AXIsProcessTrusted() else {
                finish(PlaybackReading(snapshot: nil, artwork: nil, status: "系统播放信息不可用；请授权辅助功能后读取网易云", needsPermission: true))
                return
            }
            finish(readAccessibility())
        }
    }

    static func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private func mediaInfo() -> [String: Any]? {
        guard let framework, let symbol = dlsym(framework, "MRMediaRemoteGetNowPlayingInfo") else { return nil }
        let call = unsafeBitCast(symbol, to: InfoFunction.self)
        let box = InfoBox()
        let semaphore = DispatchSemaphore(value: 0)
        call(DispatchQueue.global(qos: .utility)) { value in
            box.store(value as? [String: Any])
            semaphore.signal()
        }
        guard semaphore.wait(timeout: .now() + 1) == .success, isNetease(library: framework) else { return nil }
        return box.load()
    }

    private func isNetease(library: UnsafeMutableRawPointer) -> Bool {
        guard let symbol = dlsym(library, "MRMediaRemoteGetNowPlayingApplicationPID") else { return false }
        typealias Query = @convention(c) (DispatchQueue, @escaping (Int32) -> Void) -> Void
        let query = unsafeBitCast(symbol, to: Query.self)
        let box = InfoBox()
        let semaphore = DispatchSemaphore(value: 0)
        query(DispatchQueue.global()) { pid in box.store(["pid": pid]); semaphore.signal() }
        guard semaphore.wait(timeout: .now() + 1) == .success, let pid = box.load()?["pid"] as? Int32 else { return false }
        return PlayerTarget.permitted(bundleID: NSRunningApplication(processIdentifier: pid)?.bundleIdentifier)
    }

    private func snapshot(from info: [String: Any]) -> PlaybackSnapshot? {
        guard let title = info["kMRMediaRemoteNowPlayingInfoTitle"] as? String, !title.isEmpty,
              let elapsed = (info["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? NSNumber)?.doubleValue,
              let rate = (info["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? NSNumber)?.doubleValue,
              let timestamp = info["kMRMediaRemoteNowPlayingInfoTimestamp"] as? Date,
              elapsed.isFinite, rate.isFinite, rate >= 0, timestamp <= Date().addingTimeInterval(5) else { return nil }
        let artist = info["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? ""
        let duration = (info["kMRMediaRemoteNowPlayingInfoDuration"] as? NSNumber)?.doubleValue ?? 0
        return PlaybackSnapshot(track: Track(title: title, artist: artist, album: info["kMRMediaRemoteNowPlayingInfoAlbum"] as? String ?? "", duration: duration), elapsed: elapsed, rate: rate, sampledAt: timestamp)
    }

    private func readAccessibility() -> PlaybackReading {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.netease.163music").first else {
            return unavailable("网易云音乐未运行")
        }
        let root = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(root, 0.25)
        guard let windows = attribute(root, kAXWindowsAttribute) as? [AXUIElement], !windows.isEmpty else {
            return unavailable("网易云窗口不可读；请打开主窗口或迷你播放器")
        }
        var budget = 500
        let deadline = Date().addingTimeInterval(1.5)
        for window in windows {
            var nodes: [AXNode] = []
            collect(window, depth: 0, budget: &budget, deadline: deadline, output: &nodes)
            let texts = nodes.flatMap(\.texts)
            let pairs = texts.compactMap(PlaybackText.timePair)
            let timed = nodes.filter { $0.role == kAXStaticTextRole }.flatMap(\.texts).compactMap(PlaybackText.time)
            guard let pair = pairs.first ?? (timed.count == 2 && timed[1] > 0 && timed[0] <= timed[1] ? (elapsed: timed[0], duration: timed[1]) : nil) else { continue }
            let pause = nodes.first { node in
                node.role == kAXButtonRole && node.texts.contains { $0 == "暂停" || $0.lowercased() == "pause" }
            }
            let play = nodes.first { node in
                node.role == kAXButtonRole && node.texts.contains { $0 == "播放" || $0.lowercased() == "play" }
            }
            guard pause != nil || play != nil else { continue }
            let labelledTitle = labelled(nodes, labels: ["歌曲名", "歌曲名称", "歌名", "song title", "track title"])
            let labelledArtist = labelled(nodes, labels: ["歌手", "艺术家", "artist"])
            guard let title = labelledTitle, !title.isEmpty else { continue }
            let track = Track(title: title, artist: labelledArtist ?? "", duration: pair.duration)
            return PlaybackReading(snapshot: PlaybackSnapshot(track: track, elapsed: pair.elapsed, rate: pause != nil ? 1 : 0), artwork: nil, status: "网易云辅助功能 · 秒级精度，依赖客户端可访问性标签", needsPermission: false)
        }
        return unavailable("未找到可识别的歌曲、时间和播放控件；此版本的辅助功能界面可能不兼容。可使用演示模式检查效果。")
    }

    private func labelled(_ nodes: [AXNode], labels: [String]) -> String? {
        for node in nodes {
            for label in labels {
                if node.label.lowercased() == label, let value = node.value, !value.isEmpty, value.lowercased() != label { return value }
                for text in node.texts {
                    for separator in [":", "："] {
                        let prefix = label + separator
                        if text.lowercased().hasPrefix(prefix) {
                            let value = String(text.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                            if !value.isEmpty { return value }
                        }
                    }
                }
            }
        }
        return nil
    }

    private func collect(_ element: AXUIElement, depth: Int, budget: inout Int, deadline: Date, output: inout [AXNode]) {
        guard depth < 18, budget > 0, Date() < deadline else { return }
        budget -= 1
        let role = attribute(element, kAXRoleAttribute) as? String ?? ""
        let label = attribute(element, kAXDescriptionAttribute) as? String ?? ""
        let title = attribute(element, kAXTitleAttribute) as? String
        let value = attribute(element, kAXValueAttribute) as? String
        output.append(AXNode(role: role, label: label, value: value, texts: [title, value, label].compactMap { $0 }.filter { !$0.isEmpty }))
        for child in attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? [] {
            collect(child, depth: depth + 1, budget: &budget, deadline: deadline, output: &output)
        }
    }

    private func attribute(_ element: AXUIElement, _ name: String) -> Any? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    private func unavailable(_ status: String) -> PlaybackReading {
        PlaybackReading(snapshot: nil, artwork: nil, status: status, needsPermission: false)
    }
}

private struct AXNode {
    let role: String
    let label: String
    let value: String?
    let texts: [String]
}

private final class InfoBox {
    private let lock = NSLock()
    private var info: [String: Any]?
    func store(_ value: [String: Any]?) { lock.lock(); defer { lock.unlock() }; info = value }
    func load() -> [String: Any]? { lock.lock(); defer { lock.unlock() }; return info }
}
