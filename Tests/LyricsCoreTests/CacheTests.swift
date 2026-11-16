import Foundation
import LyricsCore

struct CacheTests {
    func run() async {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("CloudVerseChecks-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let cache = LyricCache(directory: folder)
        let document = LyricDocument(lines: [LyricLine(start: 1, text: "Hello", translation: "你好")])
        let now = Date(timeIntervalSince1970: 1000)
        expectNil(await cache.load(songID: 1, now: now))
        do {
            try await cache.save(document, songID: 1, now: now)
            expectEqual(await cache.load(songID: 1, now: now), document)
            expectNil(await cache.load(songID: 1, now: now.addingTimeInterval(31 * 86400)))
            try Data("broken".utf8).write(to: folder.appendingPathComponent("1.json"))
            expectNil(await cache.load(songID: 1, now: now))
            try await cache.save(document, songID: -1, now: now)
            expectFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("-1.json").path))
            try await cache.save(LyricDocument(lines: []), songID: 2, now: now)
            expectNil(await cache.load(songID: 2, now: now))
        } catch {
            print("Unexpected cache error: \(error)")
            expectTrue(false)
        }
    }
}
