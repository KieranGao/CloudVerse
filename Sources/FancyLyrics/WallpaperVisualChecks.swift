import AppKit
import LyricsCore

@MainActor
 enum WallpaperVisualChecks {
    static func run() -> Bool {
        var failures = 0
        func check(_ condition: Bool, _ name: String) {
            if !condition { failures += 1; print("VISUAL FAIL: \(name)") }
        }
        let suite = "FancyLyrics.VisualChecks.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else { return false }
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("ink", forKey: "theme")
        defaults.set(55, forKey: "fontSize")
        defaults.set(900, forKey: "width")
        defaults.set(true, forKey: "nextLine")
        defaults.set(false, forKey: "locked")
        let preferences = Preferences(defaults: defaults)
        check(preferences.theme == .ink, "classic theme survives upgrade")
        check(preferences.fontSize == 55, "saved font survives upgrade")
        check(preferences.width == 900, "saved width survives upgrade")
        check(preferences.nextLine, "next-line preference survives upgrade")
        check(!preferences.locked, "unlocked preference survives upgrade")
        preferences.theme = .moonlight
        preferences.fontSize = 20
        preferences.translation = true
        preferences.showPrevious = true
        preferences.nextLine = true
        preferences.showMetadata = true
        check(preferences.overlayHeight >= 360, "small font with all auxiliary rows has enough height")
        for theme in LyricTheme.allCases.filter(\.isWallpaper) {
            let text = String(repeating: "漫长的旋律会在这里完整展开，", count: 12)
            let fitted = WallpaperTextFitting.font(for: text, theme: theme, requestedSize: 72, width: 220, height: 200)
            let height = WallpaperTextFitting.measuredHeight(text, font: fitted, tracking: min(theme.letterSpacing, Double(fitted.pointSize) * 0.03), width: 220)
            check(height <= 200, "\(theme.rawValue) long LRC fits without losing its tail")
        }
        let fonts = Set(LyricTheme.allCases.filter(\.isWallpaper).map { $0.nativeFont(size: 48).fontName })
        check(fonts.count >= 7, "wallpaper themes render with visibly distinct Chinese font families")
        let desktop = DesktopWindowPolicy.level(for: .desktop, positioning: false)
        check(desktop.rawValue < NSWindow.Level.normal.rawValue, "desktop below regular windows")
        check(desktop.rawValue > Int(CGWindowLevelForKey(.desktopWindow)), "desktop above wallpaper")
        check(DesktopWindowPolicy.level(for: .desktop, positioning: true) == .floating, "positioning temporarily floats")
        check(DesktopWindowPolicy.level(for: .floating, positioning: false) == .floating, "floating mode retained")
        print("VISUAL CHECKS: \(failures) failures")
        return failures == 0
    }
}
