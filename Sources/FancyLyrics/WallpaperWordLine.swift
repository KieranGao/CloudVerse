import AppKit
import SwiftUI
import LyricsCore

struct WallpaperWordLine: View {
    let line: LyricLine
    let theme: LyricTheme
    let tone: InkTone
    let time: Double
    let fontSize: Double
    let alignment: HorizontalAlignment
    let effects: Double
    var fontChoice: FontChoice = .theme

    private var font: NSFont { theme.nativeFont(size: fontSize, choice: fontChoice) }
    private var ink: Color { theme.ink(tone) }
    private var textAlignment: TextAlignment { alignment == .leading ? .leading : (alignment == .trailing ? .trailing : .center) }

    var body: some View {
        Group {
            if line.words.isEmpty {
                GeometryReader { geometry in
                    let height = fontSize * 2.6 + 6
                    let fitted = WallpaperTextFitting.font(for: line.text, theme: theme, requestedSize: fontSize, width: geometry.size.width, height: height, choice: fontChoice)
                    let tracking = fitted.pointSize >= font.pointSize - 0.1 ? theme.letterSpacing : min(theme.letterSpacing, Double(fitted.pointSize) * 0.03)
                    ScrollView(.vertical, showsIndicators: false) {
                        Text(line.text)
                            .font(Font(fitted))
                            .tracking(tracking)
                            .foregroundStyle(ink)
                            .multilineTextAlignment(textAlignment)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, minHeight: height, alignment: .center)
                    }
                    .frame(height: height)
                }
                .frame(height: fontSize * 2.6 + 6)
            } else {
                timedWords
            }
        }
        .modifier(WallpaperInkEffect(theme: theme, tone: tone, amount: effects))
        .accessibilityLabel(line.text)
    }

    private var frameAlignment: Alignment {
        alignment == .leading ? .leading : (alignment == .trailing ? .trailing : .center)
    }

    private var timedWords: some View {
        GeometryReader { geometry in
            let widths = WordMeasurements.widths(for: line, font: font, tracking: theme.letterSpacing)
            let current = line.words.lastIndex(where: { $0.start <= time }) ?? 0
            let page = WordPagination.page(widths: widths.map(Double.init), availableWidth: Double(geometry.size.width), currentWord: current)
            WordFlow(spacing: 0, centered: alignment == .center, trailing: alignment == .trailing) {
                ForEach(Array(line.words.enumerated()).filter { page.contains($0.offset) }, id: \.offset) { index, word in
                    let width = min(geometry.size.width, widths[index])
                    let height = fontSize * 1.3
                    Text(word.text)
                        .font(Font(font))
                        .tracking(theme.letterSpacing)
                        .lineLimit(1)
                        .minimumScaleFactor(0.1)
                        .frame(width: width, height: height)
                        .foregroundStyle(ink.opacity(0.35))
                        .overlay {
                            Text(word.text)
                                .font(Font(font))
                                .tracking(theme.letterSpacing)
                                .lineLimit(1)
                                .minimumScaleFactor(0.1)
                                .frame(width: width, height: height)
                                .foregroundStyle(ink)
                                .mask(alignment: .leading) {
                                    Rectangle().frame(width: width * word.progress(at: time))
                                }
                        }
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .frame(height: fontSize * 2.6 + 6)
    }
}

private enum WordMeasurements {
    private static let cache: NSCache<NSString, NSArray> = {
        let cache = NSCache<NSString, NSArray>()
        cache.countLimit = 160
        return cache
    }()

    static func widths(for line: LyricLine, font: NSFont, tracking: Double) -> [CGFloat] {
        let key = "\(font.fontName)|\(font.pointSize)|\(tracking)|\(line.words.map(\.text).joined(separator: "\u{1f}"))" as NSString
        if let saved = cache.object(forKey: key) as? [NSNumber] { return saved.map { CGFloat($0.doubleValue) } }
        let widths: [CGFloat] = line.words.map { word in
            ceil((word.text as NSString).size(withAttributes: [.font: font, .kern: tracking]).width) + CGFloat(max(1, tracking))
        }
        cache.setObject(widths.map { NSNumber(value: Double($0)) } as NSArray, forKey: key)
        return widths
    }
}

private struct WallpaperInkEffect: ViewModifier {
    let theme: LyricTheme
    let tone: InkTone
    let amount: Double

    func body(content: Content) -> some View {
        switch theme {
        case .relief:
            content
                .opacity(0.9)
                .shadow(color: .black.opacity(0.3 * amount), radius: 0.5, x: 1, y: 1.3)
                .shadow(color: .white.opacity(0.7 * amount), radius: 0.3, x: -0.7, y: -0.9)
                .overlay {
                    LinearGradient(stops: [.init(color: .white, location: 0), .init(color: Color(white: 0.62), location: 0.38), .init(color: .white, location: 0.48), .init(color: Color(white: 0.3), location: 0.53), .init(color: Color(white: 0.92), location: 1)], startPoint: .top, endPoint: .bottom).opacity(amount).mask(content)
                }
        case .mist:
            content.shadow(color: theme.ink(tone).opacity(0.35 * amount), radius: 10 * amount)
                .shadow(color: .black.opacity(tone == .light ? 0.25 * amount : 0), radius: 4)
        case .moonlight:
            content.shadow(color: theme.ink(tone).opacity(0.28 * amount), radius: 6 * amount)
        case .poem, .editorial:
            content
                .shadow(color: .black.opacity(tone == .light ? 0.3 * amount : 0), radius: 1.4, y: 1)
                .overlay {
                    InkGrain().opacity(0.22 * amount).mask(content)
                }
        case .terminal:
            content.shadow(color: theme.ink(tone).opacity(0.45 * amount), radius: 3 * amount)
                .overlay {
                    ScanlineTexture().opacity(0.18 * amount).mask(content)
                }
        default:
            content.shadow(color: .black.opacity(tone == .light ? 0.42 * amount : 0), radius: 2, y: 1)
        }
    }
}

private struct InkGrain: View {
    var body: some View {
        Canvas { context, size in
            for index in 0..<280 {
                let x = CGFloat((index * 73 + 19) % 997) / 997 * size.width
                let y = CGFloat((index * 97 + 41) % 991) / 991 * size.height
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: index % 3 == 0 ? 1.4 : 0.8, height: 0.8)), with: .color(.black))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct ScanlineTexture: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            for y in stride(from: CGFloat(0), to: size.height, by: 4) {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(path, with: .color(.black), lineWidth: 0.6)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
