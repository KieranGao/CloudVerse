import AppKit
import LyricsCore

 enum WallpaperTextFitting {
    static func font(for text: String, theme: LyricTheme, requestedSize: Double, width: Double, height: Double, choice: FontChoice = .theme) -> NSFont {
        func fits(_ size: Double) -> Bool {
            let font = theme.nativeFont(size: size, choice: choice)
            let tracking = size >= requestedSize - 0.1 ? theme.letterSpacing : min(theme.letterSpacing, Double(font.pointSize) * 0.03)
            return measuredHeight(text, font: font, tracking: tracking, width: width - 6) <= height * 0.82
        }
        if fits(requestedSize) { return theme.nativeFont(size: requestedSize, choice: choice) }
        var low = 10.0
        var high = requestedSize
        for _ in 0..<12 {
            let middle = (low + high) / 2
            if fits(middle) { low = middle } else { high = middle }
        }
        return theme.nativeFont(size: low, choice: choice)
    }

    static func measuredHeight(_ text: String, font: NSFont, tracking: Double, width: Double) -> Double {
        ceil((text as NSString).boundingRect(with: NSSize(width: max(1, width), height: 100000), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: font, .kern: tracking]).height)
    }
}
