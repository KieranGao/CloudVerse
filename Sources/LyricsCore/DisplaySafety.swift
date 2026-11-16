import Foundation

public struct SelectionScope: Equatable, Sendable {
    public let trackKey: String
    public let generation: Int
    public init(trackKey: String, generation: Int) { self.trackKey = trackKey; self.generation = generation }
    public func permits(trackKey: String?, generation: Int) -> Bool {
        self.trackKey == trackKey && self.generation == generation
    }
}

public enum WordPagination {
    public static func page(widths: [Double], availableWidth: Double, currentWord: Int, maxRows: Int = 2) -> Range<Int> {
        guard !widths.isEmpty else { return 0..<0 }
        let limit = availableWidth.isFinite ? max(1, availableWidth) : 1
        let current = min(widths.count - 1, max(0, currentWord))
        var start = 0
        var row = 1
        var used = 0.0
        for index in widths.indices {
            let width = widths[index].isFinite ? min(limit, max(0, widths[index])) : limit
            if used > 0 && used + width > limit {
                row += 1
                used = 0
            }
            if row > max(1, maxRows) {
                if current < index { return start..<index }
                start = index
                row = 1
            }
            used += width
        }
        return start..<widths.count
    }
}
