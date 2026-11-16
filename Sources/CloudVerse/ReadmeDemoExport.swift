import AppKit
import ImageIO
import SwiftUI
import LyricsCore

@MainActor
enum ReadmeDemoExport {
    static func run(directory: URL) -> Bool {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let themeFrames = try renderThemeGallery(to: directory.appendingPathComponent("theme-gallery-demo.gif"))
            let panelFrames = try renderControlPanel(to: directory.appendingPathComponent("control-panel-demo.gif"))
            print("README DEMOS PASS: theme gallery \(themeFrames) frames; control panel \(panelFrames) frames; original demo lyrics")
            return true
        } catch {
            print("README DEMOS FAIL: \(error.localizedDescription)")
            return false
        }
    }

    private static func renderThemeGallery(to url: URL) throws -> Int {
        let themes = LyricTheme.allCases.filter(\.isWallpaper)
        let line = DemoContent.document.lines[2]
        let steps = 9
        let wordSpan = Double(line.words.count) * 0.52
        let writer = try GIFWriter(url: url, frameCount: themes.count * steps)
        for theme in themes {
            for step in 0..<steps {
                let time = line.start + wordSpan * Double(step) / Double(steps - 1) + 0.05
                let renderer = ImageRenderer(content: ThemeShowcaseFrame(theme: theme, time: time))
                renderer.proposedSize = ProposedViewSize(ThemeShowcaseFrame.size)
                renderer.scale = 1
                guard let image = renderer.cgImage else { throw MusicError.invalidPayload }
                writer.add(image, delay: step == steps - 1 ? 0.9 : 0.16)
            }
        }
        try writer.finish()
        return themes.count * steps
    }

    private static func renderControlPanel(to url: URL) throws -> Int {
        let suite = "CloudVerse.ReadmeDemo.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else { throw MusicError.invalidPayload }
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = Preferences(defaults: defaults)
        let model = AppModel(preferences: preferences)
        model.toggleDemo()
        let times = stride(from: 6.0, through: 16.0, by: 0.25).map { $0 }
        let writer = try GIFWriter(url: url, frameCount: times.count)
        let size = CGSize(width: 370, height: 646)
        for time in times {
            model.seekDemo(to: time)
            let panel = ControlPanelView(model: model, preferences: preferences, openSettings: {}, resetPosition: {}, dismiss: {}, panelHeight: size.height)
                .environment(\.colorScheme, .dark)
            writer.add(try capture(panel, size: size), delay: 0.25)
        }
        try writer.finish()
        return times.count
    }

    private static func capture<Content: View>(_ content: Content, size: CGSize) throws -> CGImage {
        let host = NSHostingView(rootView: content)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        host.frame = NSRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        defer { window.close() }
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { throw MusicError.invalidPayload }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        guard let image = bitmap.cgImage else { throw MusicError.invalidPayload }
        return image
    }
}

private final class GIFWriter {
    private let destination: CGImageDestination

    init(url: URL, frameCount: Int) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "com.compuserve.gif" as CFString, frameCount, nil) else {
            throw MusicError.invalidPayload
        }
        self.destination = destination
        CGImageDestinationSetProperties(destination, [
            kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]
        ] as CFDictionary)
    }

    func add(_ image: CGImage, delay: Double) {
        CGImageDestinationAddImage(destination, image, [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFDelayTime: delay,
                kCGImagePropertyGIFUnclampedDelayTime: delay
            ]
        ] as CFDictionary)
    }

    func finish() throws {
        guard CGImageDestinationFinalize(destination) else { throw MusicError.invalidPayload }
    }
}

private struct ThemeShowcaseFrame: View {
    static let size = CGSize(width: 760, height: 548)
    let theme: LyricTheme
    let time: Double

    var body: some View {
        let scene = PreviewScene.suggested(for: theme)
        VStack(spacing: 14) {
            HStack(spacing: 6) {
                ForEach(LyricTheme.allCases.filter(\.isWallpaper)) { item in
                    Text(item.title)
                        .font(.system(size: 11, weight: item == theme ? .semibold : .regular))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(item == theme ? Color.white.opacity(0.16) : Color.clear, in: Capsule())
                        .foregroundStyle(item == theme ? Color.white : Color.white.opacity(0.42))
                }
            }
            ThemePreview(theme: theme, scene: scene, tone: scene.suggestedTone, fontSize: 56, showTranslation: true, anchor: .lowerCenter, fixedTime: time)
                .frame(width: 720)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(theme.title).font(.system(size: 15, weight: .semibold))
                Text(theme.subtitle).font(.system(size: 12)).foregroundStyle(Color.white.opacity(0.55))
                Spacer()
                Text("CloudVerse · 主题库").font(.system(size: 10, weight: .medium)).tracking(1).foregroundStyle(Color.white.opacity(0.35))
            }
            .frame(width: 720)
        }
        .padding(20)
        .frame(width: Self.size.width, height: Self.size.height)
        .background(Color(red: 0.07, green: 0.075, blue: 0.09))
        .foregroundStyle(Color.white)
        .environment(\.colorScheme, .dark)
    }
}
