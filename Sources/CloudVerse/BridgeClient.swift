import Foundation
import LyricsCore

struct BridgeClient {
    func read() -> (snapshot: PlaybackSnapshot, artwork: Data?)? { probe().playback }

    func probe() -> (playback: (snapshot: PlaybackSnapshot, artwork: Data?)?, otherSource: String?) {
        guard let module = moduleURL(), FileManager.default.isExecutableFile(atPath: "/usr/bin/perl"),
              let data = BoundedProcess.run(executable: "/usr/bin/perl", arguments: ["-e", Self.loader, module.path], timeout: 4, maxBytes: 384 * 1024) else { return (nil, nil) }
        if let playback = PlaybackPayload.decode(data) { return (playback, nil) }
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any], object["status"] as? String == "otherPlayer" {
            return (nil, object["source"] as? String)
        }
        return (nil, nil)
    }

    func control(action: String) -> ControlResult {
        guard ["play", "pause", "next", "previous", "check"].contains(action), let module = moduleURL() else {
            return ControlResult(accepted: false, reason: "播放辅助模块不可用")
        }
        let script = #"use strict; use warnings; use DynaLoader; my $l=DynaLoader::dl_load_file($ARGV[0],0) or die; my $s=DynaLoader::dl_find_symbol($l,'cloudverse_control') or die; DynaLoader::dl_install_xsub('main::control',$s); main::control();"#
        guard let data = BoundedProcess.run(executable: "/usr/bin/perl", arguments: ["-e", script, module.path, action], timeout: 4, maxBytes: 8192),
              let result = try? JSONDecoder().decode(ControlResult.self, from: data) else {
            return ControlResult(accepted: false, reason: "控制接口无响应；请直接在网易云操作")
        }
        return result
    }

    private func moduleURL() -> URL? {
        if let bundled = Bundle.main.url(forResource: "PlaybackBridge", withExtension: "dylib") { return bundled }
        let binary = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
        let local = binary.deletingLastPathComponent().appendingPathComponent("libPlaybackBridge.dylib")
        return FileManager.default.fileExists(atPath: local.path) ? local : nil
    }

    private static let loader = #"use strict; use warnings; use DynaLoader; my $library = DynaLoader::dl_load_file($ARGV[0], 0) or die "bridge load failed"; my $symbol = DynaLoader::dl_find_symbol($library, "cloudverse_probe") or die "bridge symbol missing"; DynaLoader::dl_install_xsub("main::probe", $symbol); main::probe();"#
}
