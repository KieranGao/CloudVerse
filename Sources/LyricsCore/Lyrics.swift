import Foundation

public struct LyricWord: Codable, Equatable, Sendable {
    public let text: String
    public let start: TimeInterval
    public let duration: TimeInterval

    public init(text: String, start: TimeInterval, duration: TimeInterval) {
        self.text = text
        self.start = start
        self.duration = duration
    }

    public func progress(at time: TimeInterval) -> Double {
        guard time >= start else { return 0 }
        guard duration > 0 else { return 1 }
        return min(1, max(0, (time - start) / duration))
    }
}

public struct LyricLine: Codable, Equatable, Identifiable, Sendable {
    public var id: String { "\(start):\(text)" }
    public let start: TimeInterval
    public let text: String
    public var words: [LyricWord]
    public var translation: String?

    public init(start: TimeInterval, text: String, words: [LyricWord] = [], translation: String? = nil) {
        self.start = start
        self.text = text
        self.words = words
        self.translation = translation
    }
}

public struct LyricDocument: Codable, Equatable, Sendable {
    public var lines: [LyricLine]
    public var hasWordTiming: Bool { lines.contains { !$0.words.isEmpty } }

    public init(lines: [LyricLine]) { self.lines = lines }
    public func index(at time: TimeInterval) -> Int? {
        guard let first = lines.first, time >= first.start else { return nil }
        var low = 0
        var high = lines.count
        while low < high {
            let mid = (low + high) / 2
            if lines[mid].start <= time { low = mid + 1 } else { high = mid }
        }
        return low - 1
    }
}

public enum LyricParser {
    public static func lrc(_ input: String) -> [LyricLine] {
        guard let stamp = try? NSRegularExpression(pattern: #"\[(\d+):([0-5]\d)(?:[.:](\d{1,3}))?\]"#) else { return [] }
        let offsetRE = try? NSRegularExpression(pattern: #"\[offset:([+-]?\d+)\]"#)
        let ns = input as NSString
        let offsetMatch = offsetRE?.firstMatch(in: input, range: NSRange(location: 0, length: ns.length))
        let offset = offsetMatch.flatMap { Double(ns.substring(with: $0.range(at: 1))) }.map { $0 / 1000 } ?? 0
        var lines: [LyricLine] = []
        for row in input.components(separatedBy: .newlines) {
            let text = row as NSString
            let matches = stamp.matches(in: row, range: NSRange(location: 0, length: text.length))
            guard let last = matches.last else { continue }
            let content = text.substring(from: NSMaxRange(last.range)).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !content.isEmpty else { continue }
            for match in matches {
                guard let minutes = Double(text.substring(with: match.range(at: 1))),
                      let seconds = Double(text.substring(with: match.range(at: 2))) else { continue }
                let fractionRange = match.range(at: 3)
                let fraction = fractionRange.location == NSNotFound ? 0 : (Double("0." + text.substring(with: fractionRange)) ?? 0)
                lines.append(LyricLine(start: max(0, minutes * 60 + seconds + fraction + offset), text: content))
            }
        }
        return sortedUnique(lines)
    }

    public static func yrc(_ input: String) -> [LyricLine] {
        guard let header = try? NSRegularExpression(pattern: #"^\[(\d+),(\d+)\]"#),
              let tokens = try? NSRegularExpression(pattern: #"\((\d+),(\d+),[^)]*\)(.*?)(?=\(\d+,\d+,|\z)"#) else { return [] }
        var lines: [LyricLine] = []
        for row in input.components(separatedBy: .newlines) {
            let ns = row as NSString
            guard let match = header.firstMatch(in: row, range: NSRange(location: 0, length: ns.length)),
                  let start = Double(ns.substring(with: match.range(at: 1))) else { continue }
            let words: [LyricWord] = tokens.matches(in: row, range: NSRange(location: NSMaxRange(match.range), length: ns.length - NSMaxRange(match.range))).compactMap { token in
                guard let time = Double(ns.substring(with: token.range(at: 1))),
                      let duration = Double(ns.substring(with: token.range(at: 2))) else { return nil }
                let text = ns.substring(with: token.range(at: 3))
                guard !text.isEmpty else { return nil }
                return LyricWord(text: text, start: time / 1000, duration: duration / 1000)
            }
            guard !words.isEmpty else { continue }
            lines.append(LyricLine(start: start / 1000, text: words.map(\.text).joined(), words: words))
        }
        return sortedUnique(lines)
    }

    public static func document(lrc: String?, yrc: String?, translation: String?) -> LyricDocument {
        let words = yrc.map(Self.yrc) ?? []
        var lines = words.isEmpty ? (lrc.map(Self.lrc) ?? []) : words
        let translations = translation.map(Self.lrc) ?? []
        for i in lines.indices {
            if let nearest = translations.min(by: { abs($0.start - lines[i].start) < abs($1.start - lines[i].start) }),
               abs(nearest.start - lines[i].start) <= 0.12,
               nearest.text != lines[i].text {
                lines[i].translation = nearest.text
            }
        }
        return LyricDocument(lines: lines)
    }

    private static func sortedUnique(_ lines: [LyricLine]) -> [LyricLine] {
        var seen = Set<String>()
        return lines.enumerated().sorted { a, b in
            a.element.start == b.element.start ? a.offset < b.offset : a.element.start < b.element.start
        }.map(\.element).filter { seen.insert($0.id).inserted }
    }
}
