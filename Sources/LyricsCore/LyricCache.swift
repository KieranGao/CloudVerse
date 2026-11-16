import Foundation

public actor LyricCache {
    private let directory: URL
    public init(directory: URL) { self.directory = directory }
    private struct Entry: Codable {
        let version: Int
        let savedAt: Date
        let document: LyricDocument
    }

    public func load(songID: Int, now: Date = Date()) -> LyricDocument? {
        guard songID > 0,
              let data = try? Data(contentsOf: directory.appendingPathComponent("\(songID).json")),
              let entry = try? JSONDecoder().decode(Entry.self, from: data), entry.version == 1,
              !entry.document.lines.isEmpty,
              now.timeIntervalSince(entry.savedAt) >= 0, now.timeIntervalSince(entry.savedAt) < 30 * 86400 else { return nil }
        return entry.document
    }

    public func save(_ document: LyricDocument, songID: Int, now: Date = Date()) throws {
        guard songID > 0 else { return }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let entry = Entry(version: 1, savedAt: now, document: document)
        let data = try JSONEncoder().encode(entry)
        try data.write(to: directory.appendingPathComponent("\(songID).json"), options: .atomic)
    }
}
