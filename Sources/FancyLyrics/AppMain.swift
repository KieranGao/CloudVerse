import AppKit

@main
@MainActor
struct FancyLyricsMain {
    static func main() {
        let application = NSApplication.shared
        if CommandLine.arguments.contains("--render-themes") {
            application.setActivationPolicy(.prohibited)
            let directory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("dist/ThemePreviews", isDirectory: true)
            exit(ThemePreviewExport.run(directory: directory) ? 0 : 1)
        } else if CommandLine.arguments.contains("--check-desktop") {
            application.setActivationPolicy(.accessory)
            exit(DesktopIntegrationChecks.run() ? 0 : 1)
        } else if CommandLine.arguments.contains("--check-visual") {
            application.setActivationPolicy(.prohibited)
            exit(WallpaperVisualChecks.run() ? 0 : 1)
        } else if CommandLine.arguments.contains("--smoke-test") {
            exit(Diagnostics.smokeCheck() ? 0 : 1)
        } else if CommandLine.arguments.contains("--check-network") {
            application.setActivationPolicy(.prohibited)
            Diagnostics.networkCheck()
            application.run()
        } else if CommandLine.arguments.contains("--check-integration") {
            application.setActivationPolicy(.prohibited)
            Diagnostics.integrationCheck()
            application.run()
        } else if let index = CommandLine.arguments.firstIndex(of: "--control") {
            application.setActivationPolicy(.prohibited)
            let action = CommandLine.arguments.indices.contains(index + 1) ? CommandLine.arguments[index + 1] : "check"
            Diagnostics.controlCheck(action: action)
            application.run()
        } else if CommandLine.arguments.contains("--monitor-sync") {
            application.setActivationPolicy(.prohibited)
            Diagnostics.monitorSync()
            application.run()
        } else if CommandLine.arguments.contains("--check-playback") {
            application.setActivationPolicy(.prohibited)
            Diagnostics.playbackCheck()
            application.run()
        } else {
            let delegate = AppDelegate()
            application.delegate = delegate
            application.run()
            withExtendedLifetime(delegate) {}
        }
    }
}
