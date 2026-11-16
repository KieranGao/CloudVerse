import SwiftUI
import LyricsCore

struct OverlayView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var preferences: Preferences

    var body: some View {
        TimelineView(.periodic(from: .now, by: model.isPlaying && preferences.visible ? 1.0 / 30 : 1)) { context in
            let time = model.position(at: context.date)
            let index = model.document.index(at: time)
            let line = index.map { model.document.lines[$0] }
            let nextIndex = (index ?? -1) + 1
            let next = model.document.lines.indices.contains(nextIndex) ? model.document.lines[nextIndex].text : nil
            let previousIndex = (index ?? 0) - 1
            let previous = model.document.lines.indices.contains(previousIndex) ? model.document.lines[previousIndex].text : nil
            LyricCard(theme: preferences.theme, accent: model.accent, title: model.snapshot?.track.title ?? "FancyLyrics", artist: model.snapshot?.track.artist ?? "独立桌面歌词", line: line, next: preferences.nextLine ? next : nil, time: time, fontSize: preferences.fontSize, showTranslation: preferences.translation, status: model.displayStatus, demo: model.isDemo, locked: preferences.locked, artwork: model.artwork, previous: preferences.showPrevious ? previous : nil, tone: preferences.inkTone, textAlignment: preferences.alignment, effects: preferences.effects, showMetadata: preferences.showMetadata, ordinal: (index ?? 0) + 1, motionEnabled: preferences.animate, fontChoice: preferences.fontChoice)
                .opacity(preferences.opacity)
                .padding(16)
        }
        .overlay {
            if preferences.positioning || !preferences.locked {
                RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.55), style: StrokeStyle(lineWidth: 1, dash: [5, 5])).padding(12)
                VStack {
                    Text("直接拖动歌词 · 右键锁定 / 菜单栏锁定").font(.system(size: 11)).padding(.horizontal, 12).padding(.vertical, 7)
                        .background(.black.opacity(0.65), in: Capsule()).foregroundStyle(.white)
                    Spacer()
                }.padding(.top, 20).allowsHitTesting(false)
            }
        }
        .contextMenu {
            if preferences.positioning {
                Button("完成定位，融入桌面") { preferences.finishPositioning() }
                Divider()
            }
            ForEach(LyricTheme.allCases) { theme in
                Button(theme.title) { preferences.theme = theme }
            }
            Divider()
            Button("锁定并穿透鼠标") { preferences.locked = true }
            Button("隐藏歌词") { preferences.visible = false }
        }
    }
}

struct LyricCard: View {
    let theme: LyricTheme
    let accent: Color
    let title: String
    let artist: String
    let line: LyricLine?
    let next: String?
    let time: Double
    let fontSize: Double
    let showTranslation: Bool
    let status: String
    let demo: Bool
    let locked: Bool
    var artwork: NSImage? = nil
    var previous: String? = nil
    var tone: InkTone = .light
    var textAlignment: LyricAlignment = .automatic
    var effects: Double = 0.45
    var showMetadata: Bool = false
    var ordinal: Int = 1
    var motionEnabled: Bool = true
    var fontChoice: FontChoice = .theme

    private var isInk: Bool { theme == .ink }
    private var isSignal: Bool { theme == .signal }

    var body: some View {
        if theme.isWallpaper {
            WallpaperLyricView(theme: theme, line: line, previous: previous, next: next, title: title, artist: artist, time: time, fontSize: fontSize, tone: tone, textAlignment: textAlignment, effects: effects, showTranslation: showTranslation, showMetadata: showMetadata, ordinal: ordinal, animate: motionEnabled, status: status, fontChoice: fontChoice)
        } else {
            classicBody
        }
    }

    private var classicBody: some View {
        VStack(alignment: isSignal ? .center : .leading, spacing: 16) {
            header
            Spacer(minLength: 2)
            if let line {
                activeLine(line)
                if showTranslation, let translation = line.translation {
                    Text(translation)
                        .font(.system(size: max(12, fontSize * 0.43), weight: .regular))
                        .foregroundStyle(theme.foreground.opacity(0.62))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text(next == nil ? (demo ? "原创演示" : "等待旋律") : "前奏")
                    .font(.system(size: fontSize, weight: isInk ? .medium : .semibold, design: isInk ? .serif : .default))
                    .foregroundStyle(theme.foreground.opacity(0.8))
                Text(status)
                    .font(.system(size: 12))
                    .foregroundStyle(theme.foreground.opacity(0.55))
                    .lineLimit(3)
            }
            if let next {
                Text(next)
                    .font(.system(size: max(13, fontSize * 0.48), weight: .medium, design: isInk ? .serif : .default))
                    .foregroundStyle(theme.foreground.opacity(0.3))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 2)
            footer
        }
        .padding(isSignal ? 20 : 26)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isSignal ? .center : .leading)
        .background {
            if !isSignal {
                RoundedRectangle(cornerRadius: isInk ? 4 : 24).fill(theme.background)
                if theme == .aurora {
                    GeometryReader { geometry in
                        Ellipse().fill(accent.opacity(0.19)).frame(width: geometry.size.width * 0.72, height: 180).blur(radius: 48).offset(x: geometry.size.width * 0.3, y: -60)
                        Ellipse().fill(Color.purple.opacity(0.14)).frame(width: 260, height: 130).blur(radius: 45).offset(x: -70, y: 150)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                }
            }
        }
        .overlay {
            if !isSignal {
                RoundedRectangle(cornerRadius: isInk ? 4 : 24).strokeBorder(theme.foreground.opacity(isInk ? 0.13 : 0.1), lineWidth: 1)
            }
        }
        .shadow(color: .black.opacity(isSignal ? 0.6 : 0.2), radius: isSignal ? 4 : 14, y: isSignal ? 1 : 8)
    }

    private var header: some View {
        HStack(spacing: 10) {
            if let artwork, !isSignal {
                Image(nsImage: artwork).resizable().aspectRatio(contentMode: .fill).frame(width: 30, height: 30).clipShape(RoundedRectangle(cornerRadius: isInk ? 2 : 8))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(theme.foreground.opacity(0.72)).lineLimit(1)
                Text(artist).font(.system(size: 10)).foregroundStyle(theme.foreground.opacity(0.38)).lineLimit(1)
            }
            if !isSignal { Spacer() }
            Text(demo ? "DEMO" : (line?.words.isEmpty == false ? "WORD SYNC" : "LYRICS"))
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(accent)
        }
    }

    @ViewBuilder
    private func activeLine(_ line: LyricLine) -> some View {
        if line.words.isEmpty {
            Text(line.text)
                .font(.system(size: fontSize, weight: isInk ? .medium : .semibold, design: isInk ? .serif : .default))
                .foregroundStyle(theme.foreground)
                .lineLimit(2)
                .minimumScaleFactor(0.65)
                .multilineTextAlignment(isSignal ? .center : .leading)
        } else {
            GeometryReader { geometry in
                let nativeFont = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
                let widths = line.words.map { ceil(($0.text as NSString).size(withAttributes: [.font: nativeFont]).width) + 2 }
                let current = line.words.lastIndex(where: { $0.start <= time }) ?? 0
                let page = WordPagination.page(widths: widths.map(Double.init), availableWidth: Double(geometry.size.width), currentWord: current)
                WordFlow(spacing: 0, centered: isSignal) {
                    ForEach(Array(line.words.enumerated()).filter { page.contains($0.offset) }, id: \.offset) { index, word in
                        Text(word.text)
                            .font(.system(size: fontSize, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.1)
                            .frame(width: min(geometry.size.width, widths[index]), height: fontSize * 1.25)
                            .foregroundStyle(theme.foreground.opacity(0.3))
                            .overlay(alignment: .leading) {
                                GeometryReader { wordGeometry in
                                    Text(word.text)
                                        .font(.system(size: fontSize, weight: .semibold))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.1)
                                        .foregroundStyle(accent)
                                        .frame(width: wordGeometry.size.width, height: wordGeometry.size.height)
                                        .mask(alignment: .leading) {
                                            Rectangle().frame(width: wordGeometry.size.width * word.progress(at: time))
                                        }
                                }
                            }
                    }
                }
            }
            .frame(height: fontSize * 2.5 + 6)
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Rectangle().fill(accent).frame(width: 16, height: 2)
            Text("FANCY LYRICS").font(.system(size: 8, weight: .medium, design: .monospaced)).tracking(2).foregroundStyle(theme.foreground.opacity(0.34))
            Spacer()
            if !locked {
                Image(systemName: "hand.draw").font(.system(size: 9))
                Text("拖动移动 · 右键操作").font(.system(size: 9))
            }
        }
        .foregroundStyle(theme.foreground.opacity(0.3))
    }
}

struct WordFlow: Layout {
    var spacing: CGFloat
    var centered: Bool
    var trailing: Bool = false

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrangement(width: proposal.width ?? 600, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let layout = arrangement(width: bounds.width, subviews: subviews)
        for (index, item) in layout.items.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + item.origin.x, y: bounds.minY + item.origin.y), proposal: ProposedViewSize(item.size))
        }
    }

    private func arrangement(width: CGFloat, subviews: Subviews) -> (size: CGSize, items: [CGRect]) {
        var rows: [[CGRect]] = [[]]
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: width, height: nil))
            if x > 0 && x + size.width > width {
                y += rowHeight + 6
                rowHeight = 0
                x = 0
                rows.append([])
            }
            rows[rows.count - 1].append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        if centered || trailing {
            rows = rows.map { row in
                let padding = max(0, (width - (row.last?.maxX ?? 0)) / (trailing ? 1 : 2))
                return row.map { $0.offsetBy(dx: padding, dy: 0) }
            }
        }
        return (CGSize(width: width, height: y + rowHeight), rows.flatMap { $0 })
    }
}
