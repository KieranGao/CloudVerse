import AppKit
import SwiftUI
import LyricsCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let preferences = Preferences()
    private lazy var model = AppModel(preferences: preferences)
    private var overlay: OverlayWindow?
    private var settings: NSWindow?
    private var statusItem: NSStatusItem?
    private let controlPanel = NSPopover()
    private let fallbackMenu = NSMenu()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        overlay = OverlayWindow(model: model)
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "FancyLyrics")
        item.button?.toolTip = "FancyLyrics · 桌面歌词"
        fallbackMenu.delegate = self
        item.button?.target = self
        item.button?.action = #selector(toggleControlPanel)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        controlPanel.behavior = .transient
        controlPanel.animates = true
        let height = min(690, (NSScreen.main?.visibleFrame.height ?? 800) - 70)
        controlPanel.contentViewController = NSHostingController(rootView: ControlPanelView(model: model, preferences: preferences, openSettings: { [weak self] in self?.showSettings() }, resetPosition: { [weak self] in self?.resetPosition() }, dismiss: { [weak self] in self?.controlPanel.performClose(nil) }, panelHeight: height))
        controlPanel.contentSize = NSSize(width: 370, height: height)
        statusItem = item
        model.start()
        if CommandLine.arguments.contains("--show-controls") { toggleControlPanel() }
        if CommandLine.arguments.contains("--demo") { model.toggleDemo() }
        if !UserDefaults.standard.bool(forKey: "hasLaunched") || !UserDefaults.standard.bool(forKey: "hasSeenWallpaperEdition") {
            UserDefaults.standard.set(true, forKey: "hasLaunched")
            UserDefaults.standard.set(true, forKey: "hasSeenWallpaperEdition")
            showSettings()
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let status = NSMenuItem(title: model.isDemo ? "FancyLyrics · 演示模式" : "FancyLyrics", action: nil, keyEquivalent: "")
        menu.addItem(status)
        if let track = model.snapshot?.track {
            menu.addItem(NSMenuItem(title: String("\(track.title) — \(track.artist)".prefix(50)), action: nil, keyEquivalent: ""))
        }
        menu.addItem(.separator())
        add(menu, "设置…", #selector(showSettings), key: ",")
        let visibility = add(menu, "显示歌词", #selector(toggleVisibility))
        visibility.state = preferences.visible ? .on : .off
        let lock = add(menu, "锁定 / 鼠标穿透", #selector(toggleLock))
        lock.state = preferences.locked ? .on : .off
        let desktop = add(menu, "融入桌面（不覆盖应用窗口）", #selector(toggleLayer))
        desktop.state = preferences.layer == .desktop ? .on : .off
        add(menu, preferences.locked ? "解锁后直接拖动歌词" : "锁定并恢复穿透", #selector(toggleLock))
        let themes = NSMenu()
        for (index, theme) in LyricTheme.allCases.enumerated() {
            let item = add(themes, theme.title, #selector(changeTheme(_:)))
            item.tag = index
            item.state = preferences.theme == theme ? .on : .off
        }
        let themeItem = NSMenuItem(title: "主题", action: nil, keyEquivalent: "")
        themeItem.submenu = themes
        menu.addItem(themeItem)
        add(menu, "重置歌词位置", #selector(resetPosition))
        menu.addItem(.separator())
        add(menu, model.isDemo ? "退出演示模式" : "开启演示模式", #selector(toggleDemo))
        add(menu, "重新匹配歌词", #selector(reloadLyrics)).isEnabled = model.snapshot != nil && !model.isDemo
        menu.addItem(.separator())
        add(menu, "退出 FancyLyrics", #selector(quit), key: "q")
    }

    @discardableResult
    private func add(_ menu: NSMenu, _ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
        return item
    }

    @objc private func toggleControlPanel() {
        guard let button = statusItem?.button else { return }
        if NSApp.currentEvent?.type == .rightMouseUp {
            controlPanel.performClose(nil)
            menuNeedsUpdate(fallbackMenu)
            fallbackMenu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
        } else if controlPanel.isShown {
            controlPanel.performClose(nil)
        } else {
            model.poll()
            controlPanel.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    @objc private func showSettings() {
        controlPanel.performClose(nil)
        if settings == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1020, height: 800), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "FancyLyrics"
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.minSize = NSSize(width: 780, height: 640)
            window.contentView = NSHostingView(rootView: SettingsView(model: model, preferences: preferences, resetPosition: { [weak self] in self?.resetPosition() }))
            window.center()
            settings = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settings?.makeKeyAndOrderFront(nil)
    }

    @objc private func toggleVisibility() { preferences.visible.toggle() }
    @objc private func toggleLock() {
        if preferences.positioning { preferences.finishPositioning() } else { preferences.locked.toggle() }
    }
    @objc private func toggleLayer() { preferences.layer = preferences.layer == .desktop ? .floating : .desktop }
    @objc private func togglePositioning() {
        if preferences.positioning { preferences.finishPositioning() } else { preferences.positioning = true }
    }
    @objc private func resetPosition() { overlay?.resetPosition() }
    @objc private func toggleDemo() { model.toggleDemo() }
    @objc private func reloadLyrics() { model.reloadLyrics(forceRefresh: true); model.poll() }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func changeTheme(_ item: NSMenuItem) {
        if LyricTheme.allCases.indices.contains(item.tag) { preferences.theme = LyricTheme.allCases[item.tag] }
    }
}
