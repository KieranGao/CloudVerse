import AppKit
import Combine
import SwiftUI
import LyricsCore

@MainActor
final class OverlayWindow: NSPanel {
    private let preferences: Preferences
    private var subscriptions = Set<AnyCancellable>()
    private var displayed = false
    private let frameName: String
    private var dragMonitor: Any?

    init(model: AppModel, autosaveName: String = "FancyLyricsOverlay") {
        preferences = model.preferences
        frameName = autosaveName
        super.init(contentRect: NSRect(x: 0, y: 0, width: preferences.width, height: preferences.overlayHeight), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        let host = DragHostingView(rootView: OverlayView(model: model, preferences: preferences))
        host.onDragCompleted = { [weak self] in
            self?.preferences.anchor = .custom
            if let self { self.saveFrame(usingName: self.frameName) }
        }
        contentView = host
        dragMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self, event.window === self, !self.ignoresMouseEvents else { return event }
            self.performDrag(with: event)
            self.preferences.anchor = .custom
            self.saveFrame(usingName: self.frameName)
            return nil
        }
        setFrameAutosaveName(frameName)
        if preferences.anchor == .custom { _ = setFrameUsingName(frameName) }
        applyPreferences()
        preferences.objectWillChange.debounce(for: .milliseconds(12), scheduler: RunLoop.main).sink { [weak self] _ in
            self?.applyPreferences()
        }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification).sink { [weak self] _ in
            self?.applyPreferences()
        }.store(in: &subscriptions)
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.activeSpaceDidChangeNotification).sink { [weak self] _ in
            self?.applyPreferences()
        }.store(in: &subscriptions)
    }

    override func close() {
        if let dragMonitor { NSEvent.removeMonitor(dragMonitor); self.dragMonitor = nil }
        super.close()
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func resetPosition() {
        preferences.anchor = preferences.theme.defaultsToCentered ? .lowerCenter : .lowerLeft
        applyPreferences()
        saveFrame(usingName: frameName)
    }

    func centerOnSecondaryDisplay() {
        guard let target = DesktopPlacement.frameOnSecondaryDisplay(screens: NSScreen.screens.map(\.visibleFrame), width: preferences.width, height: preferences.overlayHeight) else { return }
        preferences.anchor = .custom
        setFrame(target, display: true)
        saveFrame(usingName: frameName)
    }

    private func applyPreferences() {
        let interactive = preferences.positioning || !preferences.locked
        let targetLevel = DesktopWindowPolicy.level(for: preferences.layer, positioning: interactive)
        let changedLayer = level != targetLevel
        isFloatingPanel = interactive || preferences.layer == .floating
        collectionBehavior = DesktopWindowPolicy.behavior(for: preferences.layer, positioning: interactive)
        level = targetLevel
        ignoresMouseEvents = preferences.locked && !preferences.positioning
        let screens = NSScreen.screens
        guard let index = WallpaperLayout.preferredScreen(for: frame, screens: screens.map(\.visibleFrame)) else { return }
        let bounds = screens[index].visibleFrame
        var target = frame
        if preferences.anchor == .custom {
            target.size = NSSize(width: preferences.width, height: preferences.overlayHeight)
            target = DesktopWindowPolicy.boundedFrame(target, to: bounds)
        } else {
            target = DesktopPlacement.frame(in: bounds, width: preferences.width, height: preferences.overlayHeight, anchor: preferences.anchor)
        }
        if target != frame { setFrame(target, display: true) }
        let shouldDisplay = preferences.visible || preferences.positioning
        if shouldDisplay && (!displayed || changedLayer) { orderFrontRegardless() }
        if !shouldDisplay && displayed { orderOut(nil) }
        displayed = shouldDisplay
    }
}

private final class DragHostingView: NSHostingView<OverlayView> {
    var onDragCompleted: (() -> Void)?
    override var mouseDownCanMoveWindow: Bool { true }
    override func mouseDown(with event: NSEvent) {
        guard let window, !window.ignoresMouseEvents else { return }
        window.performDrag(with: event)
        onDragCompleted?()
    }
}
