import Foundation

public enum FontChoice: String, CaseIterable, Identifiable, Sendable {
    case theme, calligraphy, songti, rounded, handwriting, thin, bold, mono
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .theme: return "主题字体"
        case .calligraphy: return "楷体 · 书写"
        case .songti: return "宋体 · 高对比"
        case .rounded: return "圆体 · 柔软"
        case .handwriting: return "手写 · 随性"
        case .thin: return "超细 · 空气感"
        case .bold: return "粗黑 · 海报"
        case .mono: return "等宽 · 打字机"
        }
    }
}
