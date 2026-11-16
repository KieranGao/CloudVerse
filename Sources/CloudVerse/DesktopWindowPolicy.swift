import AppKit
import LyricsCore

struct DesktopWindowPolicy {
    static func level(for layer: DesktopLayer, positioning: Bool) -> NSWindow.Level {
        if positioning || layer == .floating { return .floating }
        return NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
    }

    static func behavior(for layer: DesktopLayer, positioning: Bool) -> NSWindow.CollectionBehavior {
        if positioning || layer == .floating { return [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle] }
        return [.canJoinAllSpaces, .stationary, .ignoresCycle]
    }

    static func boundedFrame(_ frame: NSRect, to bounds: NSRect) -> NSRect {
        var result = frame
        result.size.width = min(result.width, bounds.width)
        result.size.height = min(result.height, bounds.height)
        result.origin.x = max(bounds.minX, min(result.minX, bounds.maxX - result.width))
        result.origin.y = max(bounds.minY, min(result.minY, bounds.maxY - result.height))
        return result
    }
}
