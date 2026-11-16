import AppKit
import LyricsCore

extension FontChoice {
    func nativeFont(size: Double) -> NSFont {
        let name: String
        switch self {
        case .theme: name = "PingFangSC-Regular"
        case .calligraphy: name = "STKaiti"
        case .songti: name = "STSongti-SC-Black"
        case .rounded: name = "STYuanti-SC-Bold"
        case .handwriting: name = "Hannotate SC"
        case .thin: name = "PingFangSC-Ultralight"
        case .bold: name = "PingFangSC-Heavy"
        case .mono: name = "Menlo"
        }
        return NSFont(name: name, size: size) ?? NSFont.systemFont(ofSize: size)
    }
}
