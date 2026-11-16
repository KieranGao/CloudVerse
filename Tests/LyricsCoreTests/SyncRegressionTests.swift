import Foundation
import LyricsCore

struct SyncRegressionTests {
    func run() {
        let a = Track(title: " Song  ", artist: "Artist", duration: 199.9)
        let b = Track(title: "song", artist: "artist", duration: 200.01)
        expectEqual(a.key, b.key)
        expectEqual(Track(title: "song", artist: "artist", duration: 0).key, b.key)
        let start = Date(timeIntervalSince1970: 100)
        let playing = PlaybackSnapshot(track: b, elapsed: 10, rate: 1, sampledAt: start)
        var continuity = PlaybackContinuity()
        expectEqual(continuity.accept(playing, at: start), playing)
        let held = continuity.accept(nil, at: start.addingTimeInterval(2))
        expectEqual(held?.track.key, b.key)
        expectEqual(held?.rate, 0)
        expectEqual(held?.position(at: start.addingTimeInterval(3)), 12)
        expectEqual(continuity.accept(nil, at: start.addingTimeInterval(4))?.elapsed, 12)
        expectNil(continuity.accept(nil, at: start.addingTimeInterval(7)))
        let sought = PlaybackSnapshot(track: b, elapsed: 3, rate: 1, sampledAt: start.addingTimeInterval(8))
        expectEqual(continuity.accept(sought, at: start.addingTimeInterval(8))?.elapsed, 3)
        let paused = PlaybackSnapshot(track: b, elapsed: 11, rate: 0, sampledAt: start.addingTimeInterval(1))
        expectTrue(PlayerCommand.pause.observed(before: playing, after: paused))
        expectTrue(PlayerCommand.play.observed(before: paused, after: playing))
        expectFalse(PlayerCommand.pause.observed(before: playing, after: playing))
        let next = PlaybackSnapshot(track: Track(title: "New", artist: "artist", duration: 180), elapsed: 0, rate: 1, sampledAt: start)
        expectTrue(PlayerCommand.next.observed(before: playing, after: next))
        expectFalse(PlayerCommand.next.observed(before: playing, after: playing))
        let restarted = PlaybackSnapshot(track: b, elapsed: 0, rate: 1, sampledAt: start.addingTimeInterval(1))
        expectTrue(PlayerCommand.previous.observed(before: playing, after: restarted))
        expectTrue(PlayerTarget.permitted(bundleID: "com.netease.163music"))
        expectFalse(PlayerTarget.permitted(bundleID: "com.apple.Music"))
        expectFalse(PlayerTarget.permitted(bundleID: nil))
    }
}
