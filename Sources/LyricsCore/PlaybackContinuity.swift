import Foundation

public struct PlaybackContinuity: Sendable {
    private var last: PlaybackSnapshot?
    private var receivedAt: Date?
    public init() {}
    public mutating func accept(_ snapshot: PlaybackSnapshot?, at now: Date) -> PlaybackSnapshot? {
        if let snapshot {
            last = snapshot
            receivedAt = now
            return snapshot
        }
        guard let last, let receivedAt, now.timeIntervalSince(receivedAt) <= 6 else {
            self.last = nil
            self.receivedAt = nil
            return nil
        }
        let frozen = PlaybackSnapshot(track: last.track, elapsed: last.position(at: now), rate: 0, sampledAt: now)
        self.last = frozen
        return frozen
    }
}

public enum PlayerCommand: String, CaseIterable, Sendable {
    case play, pause, next, previous
    public var remoteValue: Int32 {
        switch self { case .play: return 0; case .pause: return 1; case .next: return 4; case .previous: return 5 }
    }
    public func observed(before: PlaybackSnapshot, after: PlaybackSnapshot) -> Bool {
        switch self {
        case .play: return after.rate > 0
        case .pause: return after.rate == 0
        case .next: return before.track.key != after.track.key || after.elapsed + 3 < before.elapsed
        case .previous: return before.track.key != after.track.key || after.elapsed + 3 < before.elapsed
        }
    }
}

public enum PlayerTarget {
    public static func permitted(bundleID: String?) -> Bool { bundleID == "com.netease.163music" }
}
