import LyricsCore

struct ParserTests {
    func testLRCPreservesMultipleTimestampsAndFractions() {
        let lines = LyricParser.lrc("[ar:Someone]\n[00:12.34][01:02.345] 同一句\n[00:03.5]前一句")
        expectEqual(lines.map(\.text), ["前一句", "同一句", "同一句"])
        expectEqual(lines.map(\.start), [3.5, 12.34, 62.345])
    }

    func testOffsetAndMalformedLines() {
        let lines = LyricParser.lrc("[offset:-250]\n[00:02.000]hello\n[00:99]bad\nnot timed\n[00:03.0]")
        expectEqual(lines.count, 1)
        expectEqual(lines.first?.start, 1.75)
    }

    func testYRCUsesAbsoluteWordTimes() {
        let lines = LyricParser.yrc("[10000,2000](10000,500,0)你(10500,1000,0)好\n{\"t\":0,\"c\":[]}")
        expectEqual(lines.count, 1)
        expectEqual(lines.first?.text, "你好")
        expectEqual(lines.first?.start, 10)
        expectEqual(lines.first?.words.map(\.start), [10, 10.5])
        expectEqual(lines.first?.words.map(\.duration), [0.5, 1])
    }

    func testTranslationAttachesOnlyToNearbyTimestamp() {
        let result = LyricParser.document(lrc: "[00:01.00]Hello\n[00:05.00]World", yrc: nil, translation: "[00:01.01]你好\n[00:12.0]不匹配")
        expectEqual(result.lines.first?.translation, "你好")
        expectNil(result.lines.last?.translation)
    }

    func testYRCWinsAndLRCDoesNotInventWordTiming() {
        let result = LyricParser.document(lrc: "[00:01.00]普通歌词", yrc: "[1000,2000](1000,1000,0)逐字", translation: nil)
        expectEqual(result.lines.first?.text, "逐字")
        expectTrue(result.hasWordTiming)
        expectFalse(LyricParser.document(lrc: "[00:01]Hello", yrc: nil, translation: nil).hasWordTiming)
    }

    func testEmptyAndInstrumentalLyrics() {
        expectTrue(LyricParser.lrc("纯音乐，请欣赏").isEmpty)
        expectTrue(LyricParser.yrc("malformed").isEmpty)
        expectTrue(LyricParser.document(lrc: nil, yrc: nil, translation: nil).lines.isEmpty)
    }
}
