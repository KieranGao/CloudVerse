import AppKit
import LyricsCore

@MainActor
 enum DesktopIntegrationChecks {
    static func run() -> Bool {
        let suite = "FancyLyrics.DesktopChecks.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else { return false }
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = Preferences(defaults: defaults)
        preferences.theme = .poem
        preferences.layer = .desktop
        preferences.locked = true
        let model = AppModel(preferences: preferences)
        model.toggleDemo()
        let overlay = OverlayWindow(model: model, autosaveName: suite)
        let foreground = NSWindow(contentRect: overlay.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        foreground.backgroundColor = .windowBackgroundColor
        foreground.isReleasedWhenClosed = false
        foreground.level = .normal
        foreground.orderFrontRegardless()
        defer { foreground.close(); overlay.close() }
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        var failures = 0
        func check(_ value: Bool, _ label: String) {
            if !value { failures += 1; print("DESKTOP FAIL: \(label)") }
        }
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        let indices = list.enumerated().reduce(into: [Int: Int]()) { map, element in
            if let number = element.element[kCGWindowNumber as String] as? Int { map[number] = element.offset }
        }
        let windowList = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] ?? []
        let overlayEntry = windowList.first { ($0[kCGWindowNumber as String] as? Int) == overlay.windowNumber }
        check((overlayEntry?[kCGWindowLayer as String] as? Int) == DesktopWindowPolicy.level(for: .desktop, positioning: false).rawValue, "WindowServer confirms desktop layer")
        if let overlayIndex = indices[overlay.windowNumber], let foregroundIndex = indices[foreground.windowNumber] {
            check(foregroundIndex < overlayIndex, "regular window is above lyrics")
        } else {
            check(overlay.level.rawValue < foreground.level.rawValue, "desktop is below regular window")
        }
        check(overlay.ignoresMouseEvents, "default desktop ignores mouse")
        preferences.positioning = true
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        check(overlay.level == .floating && !overlay.ignoresMouseEvents, "positioning switches to interactive floating layer")
        preferences.finishPositioning()
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        check(overlay.level.rawValue < NSWindow.Level.normal.rawValue && overlay.ignoresMouseEvents, "finishing restores desktop and click-through")
        preferences.locked = false
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        check(overlay.level == .floating && !overlay.ignoresMouseEvents, "one-click unlock enables direct drag without positioning mode")
        preferences.locked = true
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        check(overlay.level.rawValue < NSWindow.Level.normal.rawValue && overlay.ignoresMouseEvents, "locking restores desktop immediately")
        preferences.layer = .floating
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        check(overlay.level == .floating, "legacy always-on-top remains available")
        preferences.visible = false
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        check(!overlay.isVisible, "menu visibility hides the window")
        print("DESKTOP CHECKS: \(failures) failures; WindowServer layer, positioning, click-through, floating and hide tested")
        return failures == 0
    }
}
