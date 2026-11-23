import Foundation
import CoreGraphics

public enum LyricTheme: String, CaseIterable, Identifiable, Sendable {
    case poem, relief, cinema, editorial, mist, moonlight, terminal, vinyl
    case aurora, ink, signal
    public var id: String { rawValue }
    public var isWallpaper: Bool { self != .aurora && self != .ink && self != .signal }
    public static func restored(_ value: String?, isUpgraded: Bool) -> LyricTheme {
        guard let value, let theme = Self(rawValue: value) else { return .poem }
        return !isUpgraded && theme == .aurora ? .poem : theme
    }

    public var title: String {
        switch self {
        case .poem: return "墨迹手书"
        case .relief: return "液态银铬"
        case .cinema: return "银幕字幕"
        case .editorial: return "高对比海报"
        case .mist: return "空气细线"
        case .moonlight: return "奶油圆体"
        case .terminal: return "模拟终端"
        case .vinyl: return "手写唱片"
        case .aurora: return "Aurora"
        case .ink: return "Ink"
        case .signal: return "Signal"
        }
    }

    public var subtitle: String {
        switch self {
        case .poem: return "楷书笔触 · 居中题字"
        case .relief: return "粗黑字形 · 镜面银铬"
        case .cinema: return "中黑字幕 · 宽银幕"
        case .editorial: return "极粗宋体 · 杂志封面"
        case .mist: return "超细黑体 · 留白呼吸"
        case .moonlight: return "圆体字形 · 奶油光泽"
        case .terminal: return "等宽字符 · 磷光扫描"
        case .vinyl: return "手写字形 · 唱片刻纹"
        case .aurora: return "经典卡片 · 极光渐变"
        case .ink: return "经典卡片 · 温暖纸张"
        case .signal: return "经典透明 · 荧光高亮"
        }
    }

    public var defaultsToCentered: Bool {
        isWallpaper || self == .signal
    }
}

public enum DesktopLayer: String, CaseIterable, Identifiable, Sendable {
    case desktop, floating
    public var id: String { rawValue }
}

public enum InkTone: String, CaseIterable, Identifiable, Sendable {
    case light, dark
    public var id: String { rawValue }
}

public enum LyricAlignment: String, CaseIterable, Identifiable, Sendable {
    case automatic, leading, center, trailing
    public var id: String { rawValue }
}

public enum DesktopAnchor: String, CaseIterable, Identifiable, Sendable {
    case lowerLeft, lowerCenter, lowerRight, center, upperLeft, custom
    public var id: String { rawValue }
}

public enum VisualSettings {
    public static func bounded(_ value: Double?, fallback: Double, range: ClosedRange<Double>) -> Double {
        guard let value, value.isFinite else { return fallback }
        return min(range.upperBound, max(range.lowerBound, value))
    }
}

public enum DesktopPlacement {
    public static func frameOnSecondaryDisplay(screens: [CGRect], width: Double, height: Double) -> CGRect? {
        guard let secondaryDisplay = screens.dropFirst().first else { return nil }
        return frame(in: secondaryDisplay, width: width, height: height, anchor: .center)
    }

    public static func frame(in bounds: CGRect, width: Double, height: Double, anchor: DesktopAnchor) -> CGRect {
        let w = min(bounds.width, max(1, width.isFinite ? width : 820))
        let h = min(bounds.height, max(1, height.isFinite ? height : 360))
        let marginX = min(36, max(0, (bounds.width - w) / 2))
        let marginY = min(36, max(0, (bounds.height - h) / 2))
        let x: CGFloat
        let y: CGFloat
        switch anchor {
        case .lowerLeft, .upperLeft, .custom: x = bounds.minX + marginX
        case .lowerRight: x = bounds.maxX - w - marginX
        case .lowerCenter, .center: x = bounds.midX - w / 2
        }
        switch anchor {
        case .upperLeft: y = bounds.maxY - h - marginY
        case .center: y = bounds.midY - h / 2
        default: y = bounds.minY + marginY
        }
        return CGRect(x: x, y: y, width: w, height: h)
    }
}
