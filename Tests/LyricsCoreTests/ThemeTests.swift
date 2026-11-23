import Foundation
import CoreGraphics
import LyricsCore

struct ThemeTests {
    func run() {
        expectEqual(LyricTheme.restored(nil, isUpgraded: false), .poem)
        expectEqual(LyricTheme.restored("aurora", isUpgraded: false), .poem)
        expectEqual(LyricTheme.restored("aurora", isUpgraded: true), .aurora)
        expectEqual(LyricTheme.restored("ink", isUpgraded: false), .ink)
        expectEqual(LyricTheme.restored("signal", isUpgraded: false), .signal)
        expectEqual(LyricTheme.restored("mist", isUpgraded: true), .mist)
        expectEqual(LyricTheme.restored("unknown", isUpgraded: true), .poem)
        for theme in [LyricTheme.poem, .relief, .cinema, .editorial, .mist, .moonlight, .terminal, .vinyl] {
            expectTrue(theme.isWallpaper)
            expectTrue(theme.defaultsToCentered)
            expectEqual(LyricTheme(rawValue: theme.rawValue), theme)
        }
        expectFalse(LyricTheme.aurora.isWallpaper)
        expectFalse(LyricTheme.ink.isWallpaper)
        expectEqual(VisualSettings.bounded(.nan, fallback: 42, range: 20...72), 42)
        expectEqual(VisualSettings.bounded(.infinity, fallback: 0.95, range: 0.3...1), 0.95)
        expectEqual(VisualSettings.bounded(200, fallback: 42, range: 20...72), 72)
        expectEqual(VisualSettings.bounded(-5, fallback: 42, range: 20...72), 20)
        expectEqual(VisualSettings.bounded(nil, fallback: 42, range: 20...72), 42)
        let bounds = CGRect(x: 100, y: 100, width: 1000, height: 600)
        expectEqual(DesktopPlacement.frame(in: bounds, width: 400, height: 200, anchor: .lowerLeft), CGRect(x: 136, y: 136, width: 400, height: 200))
        expectEqual(DesktopPlacement.frame(in: bounds, width: 400, height: 200, anchor: .lowerRight), CGRect(x: 664, y: 136, width: 400, height: 200))
        expectEqual(DesktopPlacement.frame(in: bounds, width: 400, height: 200, anchor: .center), CGRect(x: 400, y: 300, width: 400, height: 200))
        expectEqual(DesktopPlacement.frame(in: bounds, width: 400, height: 200, anchor: .upperLeft), CGRect(x: 136, y: 464, width: 400, height: 200))
        expectEqual(DesktopPlacement.frame(in: bounds, width: 2000, height: 2000, anchor: .lowerRight), bounds)
        let primaryDisplay = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let secondaryDisplay = CGRect(x: 1440, y: -200, width: 1920, height: 1040)
        expectNil(DesktopPlacement.frameOnSecondaryDisplay(screens: [], width: 400, height: 200))
        expectNil(DesktopPlacement.frameOnSecondaryDisplay(screens: [primaryDisplay], width: 400, height: 200))
        expectEqual(DesktopPlacement.frameOnSecondaryDisplay(screens: [primaryDisplay, secondaryDisplay], width: 400, height: 200), CGRect(x: 2200, y: 220, width: 400, height: 200))
        let small = DesktopPlacement.frame(in: CGRect(x: 0, y: 0, width: 300, height: 180), width: 420, height: 428, anchor: .lowerCenter)
        expectEqual(small, CGRect(x: 0, y: 0, width: 300, height: 180))
        let screens = [CGRect(x: 0, y: 0, width: 1000, height: 700), CGRect(x: 1000, y: 0, width: 1000, height: 700)]
        expectEqual(WallpaperLayout.preferredScreen(for: CGRect(x: 950, y: 50, width: 500, height: 300), screens: screens), 1)
        expectEqual(WallpaperLayout.preferredScreen(for: CGRect(x: 900, y: 50, width: 120, height: 300), screens: screens), 0)
        expectNil(WallpaperLayout.preferredScreen(for: .zero, screens: []))
        let height = WallpaperLayout.height(theme: .moonlight, fontSize: 20, translation: true, previous: true, next: true, metadata: true)
        expectTrue(height >= 360)
        expectTrue(WallpaperLayout.height(theme: .moonlight, fontSize: 20, translation: false, previous: false, next: false, metadata: false) < height)
        let clock = PreviewClock(startedAt: Date(timeIntervalSince1970: 100))
        expectEqual(clock.position(at: Date(timeIntervalSince1970: 103)), 3)
        expectEqual(clock.position(at: Date(timeIntervalSince1970: 139)), 3)
        expectEqual(clock.position(at: Date(timeIntervalSince1970: 90)), 0)
    }
}
