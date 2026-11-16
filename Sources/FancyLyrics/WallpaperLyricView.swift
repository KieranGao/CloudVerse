import SwiftUI
import LyricsCore

struct WallpaperLyricView: View {
    let theme: LyricTheme
    let line: LyricLine?
    let previous: String?
    let next: String?
    let title: String
    let artist: String
    let time: Double
    let fontSize: Double
    let tone: InkTone
    let textAlignment: LyricAlignment
    let effects: Double
    let showTranslation: Bool
    let showMetadata: Bool
    let ordinal: Int
    let animate: Bool
    var status: String = "等待播放"
    var fontChoice: FontChoice = .theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var alignment: HorizontalAlignment { textAlignment.resolved(for: theme) }
    private var frameAlignment: Alignment { alignment == .leading ? .leading : (alignment == .trailing ? .trailing : .center) }
    private var ink: Color { theme.ink(tone) }

    var body: some View {
        ZStack(alignment: frameAlignment) {
            if let line, !line.text.isEmpty {
                composition(line)
                    .id("\(theme.rawValue):\(line.id)")
                    .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: reduceMotion ? 0 : 5)), removal: .opacity))
            } else {
                VStack(spacing: 14) {
                    Text(title).font(Font(theme.nativeFont(size: fontSize, choice: fontChoice))).tracking(theme.letterSpacing)
                        .lineLimit(2).minimumScaleFactor(0.5).foregroundStyle(ink.opacity(0.85))
                    Text(next == nil ? status : "前奏 · 等待第一句").font(.system(size: 12)).foregroundStyle(ink.opacity(0.6)).lineLimit(3)
                }.frame(maxWidth: .infinity).multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 24).padding(.vertical, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: frameAlignment)
        .animation(animate && !reduceMotion ? .easeInOut(duration: theme == .mist ? 0.8 : 0.45) : nil, value: line?.id)
    }

    private func composition(_ line: LyricLine) -> some View {
        VStack(alignment: alignment, spacing: theme == .cinema ? 10 : 14) {
            ornament
            if showMetadata {
                Text(artist.isEmpty ? title : "\(title)  /  \(artist)")
                    .font(.system(size: 10, design: theme == .terminal ? .monospaced : .default)).tracking(2)
                    .foregroundStyle(ink.opacity(0.45)).lineLimit(1).frame(maxWidth: .infinity, alignment: frameAlignment)
            }
            if let previous { context(previous) }
            WallpaperWordLine(line: line, theme: theme, tone: tone, time: time, fontSize: fontSize, alignment: alignment, effects: effects, fontChoice: fontChoice)
                .padding(.horizontal, theme == .cinema ? 24 : 0)
            if showTranslation, let translation = line.translation {
                Text(translation)
                    .font(.system(size: max(11, fontSize * 0.29), weight: theme == .mist ? .ultraLight : .regular, design: theme == .terminal ? .monospaced : .default))
                    .tracking(theme == .cinema ? 1.8 : 0.6)
                    .foregroundStyle(ink.opacity(0.68)).lineLimit(2)
                    .multilineTextAlignment(alignment == .center ? .center : (alignment == .trailing ? .trailing : .leading))
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
            }
            if let next { context(next) }
            bottomOrnament
        }
        .overlay(alignment: .top) {
            if theme == .editorial {
                Text(String(format: "%02d", max(1, ordinal))).font(.custom("Didot", size: fontSize * 2.7))
                    .foregroundStyle(ink.opacity(0.065)).offset(y: -18).allowsHitTesting(false).accessibilityHidden(true)
            }
        }
    }

    @ViewBuilder
    private var ornament: some View {
        switch theme {
        case .poem:
            Text("墨").font(.custom("STKaiti", size: 13)).foregroundStyle(tone == .light ? Color(red: 0.88, green: 0.42, blue: 0.31) : Color(red: 0.65, green: 0.19, blue: 0.12))
                .padding(4).overlay(Rectangle().strokeBorder(ink.opacity(0.3), lineWidth: 0.7)).frame(maxWidth: .infinity)
        case .relief:
            Rectangle().fill(LinearGradient(colors: [.clear, ink.opacity(0.6), .clear], startPoint: .leading, endPoint: .trailing)).frame(width: 100, height: 1).frame(maxWidth: .infinity)
        case .cinema:
            HStack(spacing: 9) {
                ForEach(0..<9, id: \.self) { _ in RoundedRectangle(cornerRadius: 1).fill(ink.opacity(0.23)).frame(width: 5, height: 3) }
            }.frame(maxWidth: .infinity)
        case .editorial:
            Text("N O C T U R N E").font(.custom("Didot", size: 11)).tracking(4).foregroundStyle(ink.opacity(0.65)).frame(maxWidth: .infinity)
        case .mist:
            HStack(spacing: 12) { ForEach(0..<3, id: \.self) { index in Circle().fill(ink.opacity(0.2 + Double(index) * 0.12)).frame(width: 2, height: 2) } }.frame(maxWidth: .infinity)
        case .moonlight:
            HStack(spacing: 8) { Image(systemName: "sparkle").font(.system(size: 12, weight: .light)); Capsule().fill(ink.opacity(0.3)).frame(width: 45, height: 2); Image(systemName: "sparkle").font(.system(size: 9)) }.foregroundStyle(ink.opacity(0.7)).frame(maxWidth: .infinity)
        case .terminal:
            Text("[ \(String(format: "%03d", max(1, ordinal))) : NOW PLAYING ]").font(.system(size: 9, design: .monospaced)).tracking(2).foregroundStyle(ink.opacity(0.6)).frame(maxWidth: .infinity)
        case .vinyl:
            VinylMark(ink: ink).frame(width: 35, height: 35).frame(maxWidth: .infinity)
        default: EmptyView()
        }
    }

    @ViewBuilder
    private var bottomOrnament: some View {
        if theme == .terminal {
            Text("_ / / / _").font(.system(size: 9, design: .monospaced)).tracking(4).foregroundStyle(ink.opacity(0.5)).frame(maxWidth: .infinity)
        } else if theme == .cinema {
            Rectangle().fill(ink.opacity(0.3)).frame(width: 90, height: 0.6).frame(maxWidth: .infinity)
        }
    }

    private func context(_ text: String) -> some View {
        Text(text).font(Font(theme.nativeFont(size: max(12, fontSize * 0.4), choice: fontChoice)))
            .foregroundStyle(ink.opacity(0.25)).lineLimit(1).minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity, alignment: frameAlignment)
    }
}

private struct VinylMark: View {
    let ink: Color
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            for ring in 0..<6 {
                let radius = size.width / 2 - CGFloat(ring) * 2
                context.stroke(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)), with: .color(ink.opacity(ring == 0 ? 0.6 : 0.24)), lineWidth: 0.6)
            }
            context.fill(Path(ellipseIn: CGRect(x: center.x - 1, y: center.y - 1, width: 2, height: 2)), with: .color(ink))
        }.accessibilityHidden(true).allowsHitTesting(false)
    }
}
