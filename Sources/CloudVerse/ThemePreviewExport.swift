import AppKit
import SwiftUI
import LyricsCore

@MainActor
 enum ThemePreviewExport {
    static func run(directory: URL) -> Bool {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            for theme in LyricTheme.allCases.filter(\.isWallpaper) {
                let scene = PreviewScene.suggested(for: theme)
                let view = ThemePreview(theme: theme, scene: scene, tone: scene.suggestedTone, fontSize: 56, showMetadata: false, anchor: theme.defaultsToCentered ? .lowerCenter : .lowerLeft)
                    .frame(width: 900, height: 520)
                try save(view, size: CGSize(width: 900, height: 520), to: directory.appendingPathComponent("\(theme.rawValue).png"))
            }
            try save(ThemeContactSheet(), size: CGSize(width: 1200, height: 1790), to: directory.appendingPathComponent("gallery.png"))
            let suite = "CloudVerse.PanelPreview.\(UUID().uuidString)"
            if let defaults = UserDefaults(suiteName: suite) {
                defer { defaults.removePersistentDomain(forName: suite) }
                let preferences = Preferences(defaults: defaults)
                let model = AppModel(preferences: preferences)
                model.toggleDemo()
                let panel = ControlPanelView(model: model, preferences: preferences, openSettings: {}, resetPosition: {}, dismiss: {}).environment(\.colorScheme, .dark)
                try saveHosted(panel, size: CGSize(width: 370, height: 690), to: directory.appendingPathComponent("control-panel.png"))
                let settings = SettingsView(model: model, preferences: preferences, resetPosition: {}).environment(\.colorScheme, .light)
                try saveHosted(settings, size: CGSize(width: 1020, height: 800), to: directory.appendingPathComponent("settings.png"))
            }
            print("PREVIEW PASS: 8 centered themes and menu bar panel rendered to \(directory.path)")
            return true
        } catch {
            print("PREVIEW FAIL: \(error.localizedDescription)")
            return false
        }
    }

    private static func saveHosted<Content: View>(_ content: Content, size: CGSize, to url: URL) throws {
        let host = NSHostingView(rootView: content)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        host.frame = NSRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        defer { window.close() }
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { throw MusicError.invalidPayload }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { throw MusicError.invalidPayload }
        try data.write(to: url, options: .atomic)
    }

    private static func save<Content: View>(_ content: Content, size: CGSize, to url: URL) throws {
        let renderer = ImageRenderer(content: content)
        renderer.proposedSize = ProposedViewSize(size)
        renderer.scale = 1.5
        guard let image = renderer.cgImage else { throw MusicError.invalidPayload }
        let bitmap = NSBitmapImageRep(cgImage: image)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { throw MusicError.invalidPayload }
        try data.write(to: url, options: .atomic)
    }
}

private struct ThemeContactSheet: View {
    private let themes = LyricTheme.allCases.filter(\.isWallpaper)
    var body: some View {
        VStack(alignment: .leading, spacing: 25) {
            VStack(alignment: .leading, spacing: 10) {
                Text("THE WALLPAPER EDITION").font(.system(size: 10, weight: .medium, design: .monospaced)).tracking(4).foregroundStyle(Color(red: 0.58, green: 0.54, blue: 0.42))
                Text("让壁纸本身，轻轻唱歌。").font(.custom("Songti SC", size: 36)).foregroundStyle(Color(red: 0.22, green: 0.22, blue: 0.19))
                Text("CloudVerse · 八款无底板歌词主题 · 本地原创样例 / 示意背景").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 22) {
                ForEach(themes) { theme in
                    let scene = PreviewScene.suggested(for: theme)
                    VStack(alignment: .leading, spacing: 10) {
                        ThemePreview(theme: theme, scene: scene, tone: scene.suggestedTone, fontSize: 60, showMetadata: false, anchor: theme.defaultsToCentered ? .lowerCenter : .lowerLeft)
                            .clipShape(RoundedRectangle(cornerRadius: 9))
                        HStack(alignment: .firstTextBaseline) {
                            Text(theme.title).font(.system(size: 14, weight: .semibold))
                            Spacer()
                            Text(theme.subtitle).font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(36)
        .frame(width: 1200, height: 1790, alignment: .topLeading)
        .background(Color(red: 0.955, green: 0.95, blue: 0.925))
        .environment(\.colorScheme, .light)
    }
}
