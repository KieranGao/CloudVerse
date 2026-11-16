import Foundation
import CoreGraphics

public enum WallpaperLayout {
    public static func height(theme: LyricTheme, fontSize: Double, translation: Bool, previous: Bool, next: Bool, metadata: Bool) -> Double {
        let size = VisualSettings.bounded(fontSize, fallback: 42, range: 20...72)
        if !theme.isWallpaper { return size * 4 + 300 }
        var height = 100 + size * 2.6 + 6
        if theme == .moonlight || theme == .terminal || theme == .editorial { height += 48 }
        if translation { height += max(11, size * 0.3) * 2.7 + 24 }
        if previous { height += max(12, size * 0.4) * 1.5 + 24 }
        if next { height += max(12, size * 0.4) * 1.5 + 24 }
        if metadata { height += max(9, size * 0.22) * 1.6 + 24 }
        return max(280, height)
    }

    public static func preferredScreen(for frame: CGRect, screens: [CGRect]) -> Int? {
        guard !screens.isEmpty else { return nil }
        let areas = screens.map { screen -> CGFloat in
            let intersection = frame.intersection(screen)
            return intersection.isNull ? 0 : intersection.width * intersection.height
        }
        if let best = areas.indices.max(by: { areas[$0] < areas[$1] }), areas[best] > 0 { return best }
        return screens.indices.min { a, b in
            hypot(screens[a].midX - frame.midX, screens[a].midY - frame.midY) < hypot(screens[b].midX - frame.midX, screens[b].midY - frame.midY)
        }
    }
}

public struct PreviewClock: Sendable {
    public let startedAt: Date
    public init(startedAt: Date) { self.startedAt = startedAt }
    public func position(at date: Date) -> Double {
        max(0, date.timeIntervalSince(startedAt)).truncatingRemainder(dividingBy: 36)
    }
}
