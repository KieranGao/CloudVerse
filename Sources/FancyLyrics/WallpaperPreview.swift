import AppKit
import ImageIO
import SwiftUI
import LyricsCore

 enum PreviewScene: String, CaseIterable, Identifiable {
    case dusk, sand, forest, desktop
    var id: String { rawValue }
    var title: String {
        switch self {
        case .dusk: return "暮色山海"
        case .sand: return "浅色沙丘"
        case .forest: return "深林薄雾"
        case .desktop: return "当前壁纸"
        }
    }
    var suggestedTone: InkTone { self == .sand ? .dark : .light }
    static func suggested(for theme: LyricTheme) -> PreviewScene {
        switch theme {
        case .relief: return .sand
        case .poem, .mist, .terminal: return .forest
        default: return .dusk
        }
    }
}

struct WallpaperBackdrop: View {
    let scene: PreviewScene
    var image: NSImage? = nil

    var body: some View {
        GeometryReader { geometry in
            if scene == .desktop, let image {
                Image(nsImage: image).resizable().scaledToFill().frame(width: geometry.size.width, height: geometry.size.height).clipped()
            } else {
                let sand = scene == .sand
                let forest = scene == .forest
                LinearGradient(colors: sand ? [Color(red: 0.88, green: 0.87, blue: 0.81), Color(red: 0.69, green: 0.64, blue: 0.54)] : (forest ? [Color(red: 0.23, green: 0.3, blue: 0.29), Color(red: 0.055, green: 0.12, blue: 0.12)] : [Color(red: 0.33, green: 0.35, blue: 0.43), Color(red: 0.13, green: 0.2, blue: 0.25)]), startPoint: .top, endPoint: .bottom)
                Canvas { context, size in
                    if !sand && !forest {
                        let sun = CGRect(x: size.width * 0.73, y: size.height * 0.23, width: size.width * 0.035, height: size.width * 0.035)
                        context.fill(Path(ellipseIn: sun), with: .color(Color(red: 0.94, green: 0.83, blue: 0.7).opacity(0.55)))
                    }
                    for layer in 0..<5 {
                        let baseline = size.height * (CGFloat(layer) * 0.11 + 0.34)
                        var path = Path()
                        path.move(to: CGPoint(x: -10, y: size.height + 10))
                        path.addLine(to: CGPoint(x: -10, y: baseline))
                        for step in 0...80 {
                            let x = CGFloat(step) / 80 * size.width
                            let phase = CGFloat(step) * (sand ? 0.035 : 0.085) + CGFloat(layer) * 1.7
                            let y = baseline + sin(phase) * size.height * (sand ? 0.18 : 0.09) + cos(phase * 2.7) * size.height * (sand ? 0.01 : 0.035)
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                        path.addLine(to: CGPoint(x: size.width + 10, y: size.height + 10))
                        path.closeSubpath()
                        let shade = Double(layer) * 0.045
                        let color = sand ? Color(red: 0.72 - shade, green: 0.67 - shade, blue: 0.56 - shade) : (forest ? Color(red: 0.12 - shade * 0.25, green: 0.22 - shade * 0.5, blue: 0.19 - shade * 0.35) : Color(red: 0.14 - shade * 0.3, green: 0.23 - shade * 0.5, blue: 0.29 - shade * 0.55))
                        context.fill(path, with: .color(color))
                    }
                    if forest {
                        for index in 0..<50 {
                            let x = CGFloat(index) / 49 * size.width
                            let height = size.height * (0.11 + CGFloat((index * 17) % 23) / 230)
                            let bottom = size.height * 0.93
                            var tree = Path()
                            tree.move(to: CGPoint(x: x, y: bottom - height))
                            tree.addLine(to: CGPoint(x: x - height * 0.18, y: bottom))
                            tree.addLine(to: CGPoint(x: x + height * 0.18, y: bottom))
                            tree.closeSubpath()
                            context.fill(tree, with: .color(Color(red: 0.06, green: 0.12, blue: 0.105).opacity(0.4)))
                        }
                    }
                    for index in 0..<1600 {
                        let x = CGFloat((index * 73 + 11) % 1597) / 1597 * size.width
                        let y = CGFloat((index * 113 + 29) % 1583) / 1583 * size.height
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 0.8, height: 0.8)), with: .color(.white.opacity(0.035)))
                    }
                }
                LinearGradient(colors: [.clear, .black.opacity(sand ? 0.02 : 0.14)], startPoint: .center, endPoint: .bottom)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private typealias PreviewState<Value> = SwiftUI.State<Value>

struct ThemePreview: View {
    let theme: LyricTheme
    var scene: PreviewScene = .dusk
    var wallpaper: NSImage? = nil
    var tone: InkTone = .light
    var fontSize: Double = 48
    var effects: Double = 0.45
    var showTranslation: Bool = true
    var showPrevious: Bool = false
    var showNext: Bool = false
    var showMetadata: Bool = false
    var textAlignment: LyricAlignment = .automatic
    var anchor: DesktopAnchor = .lowerLeft
    var live: Bool = false
    var opacity: Double = 0.95
    var layoutWidth: Double = 820
    var canvasSize: CGSize = CGSize(width: 900, height: 520)
    var motionEnabled: Bool = true
    var fontChoice: FontChoice = .theme
    @PreviewState private var startedAt = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if live {
                TimelineView(.periodic(from: .now, by: reduceMotion ? 0.5 : 1.0 / 30)) { context in
                    stage(time: PreviewClock(startedAt: startedAt).position(at: context.date))
                }
            } else {
                stage(time: 22)
            }
        }
        .onChange(of: live) { playing in if playing { startedAt = Date() } }
    }

    private func stage(time: Double) -> some View {
        let document = DemoContent.document
        let index = document.index(at: time) ?? 0
        let line = document.lines[index]
        let next = document.lines.indices.contains(index + 1) ? document.lines[index + 1].text : nil
        let previous = index > 0 ? document.lines[index - 1].text : nil
        let previewBounds = CGRect(origin: .zero, size: canvasSize)
        let height = WallpaperLayout.height(theme: theme, fontSize: fontSize, translation: showTranslation, previous: showPrevious, next: showNext, metadata: showMetadata)
        let placement = DesktopPlacement.frame(in: previewBounds, width: layoutWidth, height: height, anchor: anchor == .custom ? .lowerLeft : anchor)
        return GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                WallpaperBackdrop(scene: scene, image: wallpaper)
                LyricCard(theme: theme, accent: theme.accent, title: "城市的另一面", artist: "原创预览", line: line, next: showNext ? next : nil, time: time, fontSize: fontSize, showTranslation: showTranslation, status: "本地预览", demo: true, locked: true, previous: showPrevious ? previous : nil, tone: tone, textAlignment: textAlignment, effects: effects, showMetadata: showMetadata, ordinal: index + 1, motionEnabled: live && motionEnabled && !reduceMotion, fontChoice: fontChoice)
                    .frame(width: max(1, placement.width - 32), height: max(1, placement.height - 32))
                    .opacity(opacity)
                    .position(x: placement.midX, y: canvasSize.height - placement.midY)
            }
            .frame(width: canvasSize.width, height: canvasSize.height)
            .scaleEffect(geometry.size.width / max(1, canvasSize.width), anchor: .topLeading)
        }
        .aspectRatio(canvasSize.width / max(1, canvasSize.height), contentMode: .fit)
        .clipped()
    }
}

 enum WallpaperSample {
    static func current() -> NSImage? {
        guard let screen = NSScreen.main, let url = NSWorkspace.shared.desktopImageURL(for: screen), url.isFileURL,
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 1400, kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary) else { return nil }
        return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }
}
