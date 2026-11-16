import AppKit
import SwiftUI
import LyricsCore

extension LyricTheme {
    var accent: Color {
        switch self {
        case .aurora: return Color(red: 0.58, green: 0.76, blue: 1)
        case .ink: return Color(red: 0.67, green: 0.3, blue: 0.19)
        case .signal: return Color(red: 0.76, green: 1, blue: 0.42)
        case .terminal: return Color(red: 0.72, green: 0.86, blue: 0.68)
        case .moonlight: return Color(red: 0.9, green: 0.85, blue: 0.69)
        default: return Color(red: 0.94, green: 0.92, blue: 0.86)
        }
    }

    var foreground: Color { self == .ink ? Color(red: 0.2, green: 0.17, blue: 0.14) : .white }
    var background: Color {
        switch self {
        case .aurora: return Color(red: 0.07, green: 0.09, blue: 0.16)
        case .ink: return Color(red: 0.96, green: 0.94, blue: 0.89)
        default: return .clear
        }
    }

    func ink(_ tone: InkTone) -> Color {
        if tone == .dark {
            return self == .terminal ? Color(red: 0.12, green: 0.23, blue: 0.17) : Color(red: 0.19, green: 0.19, blue: 0.17)
        }
        switch self {
        case .terminal: return Color(red: 0.77, green: 0.9, blue: 0.72)
        case .moonlight: return Color(red: 0.96, green: 0.92, blue: 0.8)
        case .poem, .editorial, .vinyl: return Color(red: 0.98, green: 0.95, blue: 0.88)
        default: return Color(red: 0.96, green: 0.97, blue: 0.96)
        }
    }

    func nativeFont(size: Double, choice: FontChoice = .theme) -> NSFont {
        if choice != .theme { return choice.nativeFont(size: size) }
        let name: String
        switch self {
        case .poem: name = "STKaiti"
        case .relief: name = "STHeiti"
        case .cinema: name = "PingFangSC-Medium"
        case .editorial: name = "STSongti-SC-Black"
        case .mist: name = "PingFangSC-Ultralight"
        case .moonlight: name = "STYuanti-SC-Bold"
        case .terminal: name = "Menlo"
        case .vinyl: name = "Hannotate SC"
        default: return NSFont.systemFont(ofSize: size, weight: .semibold)
        }
        return NSFont(name: name, size: size) ?? NSFont.systemFont(ofSize: size, weight: .regular)
    }

    var letterSpacing: Double {
        switch self {
        case .poem: return 2.5
        case .relief: return 3.5
        case .cinema: return 1.8
        case .editorial: return 1.2
        case .mist: return 4
        case .moonlight: return 3
        case .terminal: return 0.7
        case .vinyl: return 2
        default: return 0
        }
    }
}

extension DesktopLayer {
    var title: String { self == .desktop ? "融入桌面" : "始终置顶" }
}

extension InkTone {
    var title: String { self == .light ? "浅色字 · 深色壁纸" : "深色字 · 浅色壁纸" }
}

extension LyricAlignment {
    var title: String {
        switch self {
        case .automatic: return "跟随主题"
        case .leading: return "左对齐"
        case .center: return "居中"
        case .trailing: return "右对齐"
        }
    }
    func resolved(for theme: LyricTheme) -> HorizontalAlignment {
        switch self {
        case .automatic: return theme.defaultsToCentered ? .center : .leading
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
}

extension DesktopAnchor {
    var title: String {
        switch self {
        case .lowerLeft: return "左下留白"
        case .lowerCenter: return "底部居中"
        case .lowerRight: return "右下留白"
        case .center: return "画面中央"
        case .upperLeft: return "左上留白"
        case .custom: return "自由拖动"
        }
    }
}
