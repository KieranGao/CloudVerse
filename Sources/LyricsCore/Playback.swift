import Foundation

public struct Track: Codable, Equatable, Sendable {
    public let title: String
    public let artist: String
    public let album: String
    public let duration: TimeInterval
    public var key: String {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "\(normalizedTitle)|\(normalizedArtist)"
    }

    public init(title: String, artist: String, album: String = "", duration: TimeInterval = 0) {
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration.isFinite ? max(0, duration) : 0
    }
}

public struct PlaybackSnapshot: Equatable, Sendable {
    public let track: Track
    public let elapsed: TimeInterval
    public let rate: Double
    public let sampledAt: Date

    public init(track: Track, elapsed: TimeInterval, rate: Double, sampledAt: Date = Date()) {
        self.track = track
        self.elapsed = elapsed
        self.rate = rate
        self.sampledAt = sampledAt
    }

    public func position(at date: Date) -> TimeInterval {
        let base = elapsed.isFinite ? max(0, elapsed) : 0
        let speed = rate.isFinite ? max(0, rate) : 0
        let value = base + max(0, date.timeIntervalSince(sampledAt)) * speed
        return track.duration > 0 ? min(track.duration, value) : value
    }
}

public enum PlaybackText {
    public static func time(_ text: String) -> TimeInterval? {
        let parts = text.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ":", omittingEmptySubsequences: false)
        guard (2...3).contains(parts.count), parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }) else { return nil }
        let values = parts.compactMap { Double($0) }
        guard values.count == parts.count, values.allSatisfy(\.isFinite),
              values.dropFirst().allSatisfy({ $0 < 60 }) else { return nil }
        return values.reduce(0) { $0 * 60 + $1 }
    }

    public static func timePair(_ text: String) -> (elapsed: TimeInterval, duration: TimeInterval)? {
        let parts = text.components(separatedBy: "/")
        guard parts.count == 2, let elapsed = time(parts[0]), let duration = time(parts[1]), duration > 0, elapsed <= duration else { return nil }
        return (elapsed, duration)
    }
}
