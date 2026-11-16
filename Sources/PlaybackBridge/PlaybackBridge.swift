import Foundation
import Darwin

private final class ResultBox {
    private let lock = NSLock()
    private var value: [String: Any]?
    func store(_ info: [String: Any]?) { lock.lock(); defer { lock.unlock() }; value = info }
    func load() -> [String: Any]? { lock.lock(); defer { lock.unlock() }; return value }
}

@_cdecl("cloudverse_probe")
public func cloudverseProbe() {
    guard let library = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_LAZY),
          let symbol = dlsym(library, "MRMediaRemoteGetNowPlayingInfo") else {
        emit(["status": "unsupported"])
    }
    typealias Function = @convention(c) (DispatchQueue, @escaping (CFDictionary?) -> Void) -> Void
    let query = unsafeBitCast(symbol, to: Function.self)
    let semaphore = DispatchSemaphore(value: 0)
    let result = ResultBox()
    query(DispatchQueue.global(qos: .utility)) { dictionary in
        result.store(dictionary as? [String: Any])
        semaphore.signal()
    }
    guard semaphore.wait(timeout: .now() + 2) == .success,
          let info = result.load(),
          let title = info["kMRMediaRemoteNowPlayingInfoTitle"] as? String, !title.isEmpty,
          let elapsed = (info["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? NSNumber)?.doubleValue,
          let rate = (info["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? NSNumber)?.doubleValue,
          let timestamp = info["kMRMediaRemoteNowPlayingInfoTimestamp"] as? Date else {
        emit(["status": "unavailable"])
    }
    let source = RemoteControl.bundleID(library: library)
    guard source == "com.netease.163music" else {
        emit(["status": "otherPlayer", "source": source ?? "无法确认"])
    }
    var payload: [String: Any] = [
        "title": title,
        "artist": info["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? "",
        "album": info["kMRMediaRemoteNowPlayingInfoAlbum"] as? String ?? "",
        "elapsed": elapsed,
        "duration": (info["kMRMediaRemoteNowPlayingInfoDuration"] as? NSNumber)?.doubleValue ?? 0,
        "rate": rate,
        "sampledAt": timestamp.timeIntervalSince1970,
        "bridgeVersion": 3
    ]
    if let data = info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data, data.count <= 192 * 1024 {
        payload["artwork"] = data.base64EncodedString()
    }
    emit(payload)
}

private func emit(_ object: [String: Any]) -> Never {
    guard JSONSerialization.isValidJSONObject(object), let data = try? JSONSerialization.data(withJSONObject: object) else {
        FileHandle.standardOutput.write(Data("{\"status\":\"invalid\"}\n".utf8))
        exit(1)
    }
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data([10]))
    exit(0)
}
