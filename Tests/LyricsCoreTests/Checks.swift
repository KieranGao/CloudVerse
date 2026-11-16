import Foundation

private var failures = 0
private var assertions = 0

func expectEqual<T: Equatable>(_ actual: T, _ expected: T, file: StaticString = #filePath, line: UInt = #line) {
    assertions += 1
    if actual != expected {
        failures += 1
        print("FAIL \(file):\(line): expected \(expected), received \(actual)")
    }
}

func expectTrue(_ value: Bool, file: StaticString = #filePath, line: UInt = #line) {
    expectEqual(value, true, file: file, line: line)
}

func expectFalse(_ value: Bool, file: StaticString = #filePath, line: UInt = #line) {
    expectEqual(value, false, file: file, line: line)
}

func expectNil<T>(_ value: T?, file: StaticString = #filePath, line: UInt = #line) {
    expectTrue(value == nil, file: file, line: line)
}

@main
struct CoreChecks {
    static func main() async {
        let parser = ParserTests()
        parser.testLRCPreservesMultipleTimestampsAndFractions()
        parser.testOffsetAndMalformedLines()
        parser.testYRCUsesAbsoluteWordTimes()
        parser.testTranslationAttachesOnlyToNearbyTimestamp()
        parser.testYRCWinsAndLRCDoesNotInventWordTiming()
        parser.testEmptyAndInstrumentalLyrics()
        PlaybackTests().run()
        MusicTests().run()
        await CacheTests().run()
        DisplaySafetyTests().run()
        ProcessTests().run()
        ThemeTests().run()
        SyncRegressionTests().run()
        print("\(assertions) assertions, \(failures) failures")
        exit(failures == 0 ? 0 : 1)
    }
}
