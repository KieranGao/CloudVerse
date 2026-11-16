import SwiftUI
import AppKit
import LyricsCore

@MainActor
final class Preferences: ObservableObject {
    private let defaults: UserDefaults
    @Published var theme: LyricTheme { didSet { save() } }
    @Published var fontSize: Double { didSet { save() } }
    @Published var offset: Double { didSet { save() } }
    @Published var translation: Bool { didSet { save() } }
    @Published var nextLine: Bool { didSet { save() } }
    @Published var albumColor: Bool { didSet { save() } }
    @Published var locked: Bool { didSet { save() } }
    @Published var visible: Bool { didSet { save() } }
    @Published var opacity: Double { didSet { save() } }
    @Published var width: Double { didSet { save() } }
    @Published var bridgeEnabled: Bool { didSet { save() } }
    @Published var layer: DesktopLayer { didSet { save() } }
    @Published var inkTone: InkTone { didSet { save() } }
    @Published var anchor: DesktopAnchor { didSet { save() } }
    @Published var alignment: LyricAlignment { didSet { save() } }
    @Published var showMetadata: Bool { didSet { save() } }
    @Published var effects: Double { didSet { save() } }
    @Published var animate: Bool { didSet { save() } }
    @Published var showPrevious: Bool { didSet { save() } }
    @Published var positioning = false
    @Published var fontChoice: FontChoice { didSet { save() } }

    var overlayHeight: Double {
        WallpaperLayout.height(theme: theme, fontSize: fontSize, translation: translation, previous: showPrevious, next: nextLine, metadata: showMetadata)
    }

    func finishPositioning() {
        positioning = false
        locked = true
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let upgraded = defaults.integer(forKey: "wallpaperThemeVersion") >= 2
        func number(_ key: String, fallback: Double, range: ClosedRange<Double>) -> Double {
            VisualSettings.bounded((defaults.object(forKey: key) as? NSNumber)?.doubleValue, fallback: fallback, range: range)
        }
        theme = LyricTheme.restored(defaults.string(forKey: "theme"), isUpgraded: upgraded)
        fontSize = number("fontSize", fallback: 42, range: 20...72)
        offset = number("offset", fallback: 0, range: -10...10)
        translation = defaults.object(forKey: "translation") as? Bool ?? true
        nextLine = defaults.object(forKey: "nextLine") as? Bool ?? false
        albumColor = defaults.object(forKey: "albumColor") as? Bool ?? true
        locked = defaults.object(forKey: "locked") as? Bool ?? true
        visible = defaults.object(forKey: "visible") as? Bool ?? true
        opacity = number("opacity", fallback: 0.95, range: 0.3...1)
        width = number("width", fallback: 820, range: 420...1400)
        bridgeEnabled = defaults.object(forKey: "bridgeEnabled") as? Bool ?? true
        layer = DesktopLayer(rawValue: defaults.string(forKey: "layer") ?? "") ?? .desktop
        inkTone = InkTone(rawValue: defaults.string(forKey: "inkTone") ?? "") ?? .light
        let centeredEdition = defaults.integer(forKey: "centeredEdition") >= 3
        anchor = centeredEdition ? DesktopAnchor(rawValue: defaults.string(forKey: "anchor") ?? "") ?? .lowerCenter : .lowerCenter
        alignment = centeredEdition ? LyricAlignment(rawValue: defaults.string(forKey: "alignment") ?? "") ?? .center : .center
        fontChoice = FontChoice(rawValue: defaults.string(forKey: "fontChoice") ?? "") ?? .theme
        showMetadata = defaults.bool(forKey: "showMetadata")
        effects = number("effects", fallback: 0.45, range: 0...1)
        animate = defaults.object(forKey: "animate") as? Bool ?? true
        showPrevious = defaults.object(forKey: "showPrevious") as? Bool ?? false
        save()
    }

    private func save() {
        defaults.set(theme.rawValue, forKey: "theme")
        defaults.set(fontSize, forKey: "fontSize")
        defaults.set(offset, forKey: "offset")
        defaults.set(translation, forKey: "translation")
        defaults.set(nextLine, forKey: "nextLine")
        defaults.set(albumColor, forKey: "albumColor")
        defaults.set(locked, forKey: "locked")
        defaults.set(visible, forKey: "visible")
        defaults.set(opacity, forKey: "opacity")
        defaults.set(width, forKey: "width")
        defaults.set(bridgeEnabled, forKey: "bridgeEnabled")
        defaults.set(layer.rawValue, forKey: "layer")
        defaults.set(inkTone.rawValue, forKey: "inkTone")
        defaults.set(anchor.rawValue, forKey: "anchor")
        defaults.set(alignment.rawValue, forKey: "alignment")
        defaults.set(showMetadata, forKey: "showMetadata")
        defaults.set(effects, forKey: "effects")
        defaults.set(animate, forKey: "animate")
        defaults.set(showPrevious, forKey: "showPrevious")
        defaults.set(2, forKey: "wallpaperThemeVersion")
        defaults.set(3, forKey: "centeredEdition")
        defaults.set(fontChoice.rawValue, forKey: "fontChoice")
    }
}

