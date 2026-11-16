import Foundation
import AppKit
import Darwin

private final class PIDBox {
    private let lock = NSLock()
    private var value: Int32 = 0
    func store(_ pid: Int32) { lock.lock(); defer { lock.unlock() }; value = pid }
    func load() -> Int32 { lock.lock(); defer { lock.unlock() }; return value }
}

 enum RemoteControl {
    static func bundleID(library: UnsafeMutableRawPointer) -> String? {
        guard let symbol = dlsym(library, "MRMediaRemoteGetNowPlayingApplicationPID") else { return nil }
        typealias Query = @convention(c) (DispatchQueue, @escaping (Int32) -> Void) -> Void
        let query = unsafeBitCast(symbol, to: Query.self)
        let box = PIDBox()
        let semaphore = DispatchSemaphore(value: 0)
        query(DispatchQueue.global()) { pid in box.store(pid); semaphore.signal() }
        guard semaphore.wait(timeout: .now() + 1) == .success, box.load() > 0 else { return nil }
        return NSRunningApplication(processIdentifier: box.load())?.bundleIdentifier
    }
}

@_cdecl("fancylyrics_control")
public func fancylyricsControl() {
    guard let library = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_LAZY) else {
        controlOutput(["accepted": false, "reason": "系统媒体框架不可用"])
    }
    let bundleID = RemoteControl.bundleID(library: library)
    guard bundleID == "com.netease.163music" else {
        controlOutput(["accepted": false, "reason": "当前媒体源：\(bundleID ?? "无法确认")；未向其他播放器发送命令"])
    }
    let action = ProcessInfo.processInfo.arguments.last ?? ""
    let code: Int32
    switch action {
    case "play": code = 0
    case "pause": code = 1
    case "next": code = 4
    case "previous": code = 5
    case "check": controlOutput(["accepted": true, "reason": "已确认网易云媒体源；未发送命令"])
    default: controlOutput(["accepted": false, "reason": "不支持的播放命令"])
    }
    guard let symbol = dlsym(library, "MRMediaRemoteSendCommand") else {
        controlOutput(["accepted": false, "reason": "系统播放控制接口不可用"])
    }
    typealias Send = @convention(c) (Int32, CFDictionary?) -> Bool
    let send = unsafeBitCast(symbol, to: Send.self)
    guard RemoteControl.bundleID(library: library) == bundleID else {
        controlOutput(["accepted": false, "reason": "媒体源发生变化，已取消控制"])
    }
    let accepted = send(code, nil)
    Thread.sleep(forTimeInterval: 0.15)
    controlOutput(["accepted": accepted, "reason": accepted ? "命令已提交，等待播放器确认" : "播放器未接受命令"])
}

private func controlOutput(_ value: [String: Any]) -> Never {
    if let data = try? JSONSerialization.data(withJSONObject: value) { FileHandle.standardOutput.write(data) }
    exit(0)
}
