import LyricsCore

struct DisplaySafetyTests {
    func run() {
        let scope = SelectionScope(trackKey: "A", generation: 1)
        expectTrue(scope.permits(trackKey: "A", generation: 1))
        expectFalse(scope.permits(trackKey: "B", generation: 1))
        expectFalse(scope.permits(trackKey: nil, generation: 1))
        expectFalse(scope.permits(trackKey: "A", generation: 2))
        let widths = Array(repeating: 60.0, count: 15)
        expectEqual(WordPagination.page(widths: widths, availableWidth: 180, currentWord: 0), 0..<6)
        expectEqual(WordPagination.page(widths: widths, availableWidth: 180, currentWord: 7), 6..<12)
        expectEqual(WordPagination.page(widths: widths, availableWidth: 180, currentWord: 14), 12..<15)
        expectEqual(WordPagination.page(widths: [], availableWidth: 180, currentWord: 0), 0..<0)
        expectEqual(WordPagination.page(widths: [500, 500, 500], availableWidth: 180, currentWord: 2), 2..<3)
        expectEqual(WordPagination.page(widths: widths, availableWidth: 180, currentWord: -1), 0..<6)
    }
}
