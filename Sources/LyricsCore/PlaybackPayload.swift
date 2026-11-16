import Foundation

public enum PlaybackPayload {
    private struct Envelope: Decodable {
        let title: String
        let artist: String?
        let album: String?
        let duration: Double
        let elapsed: Double
        let rate: Double
        let sampledAt: Double
        let artwork: String?
    }

    public static func decode(_ data: Data) -> (snapshot: PlaybackSnapshot, artwork: Data?)? {
        guard data.count <= 384 * 1024, let payload = try? JSONDecoder().decode(Envelope.self, from: data),
              !payload.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              [payload.duration, payload.elapsed, payload.rate, payload.sampledAt].allSatisfy(\.isFinite),
              payload.duration >= 0, payload.elapsed >= 0, payload.rate >= 0 else { return nil }
        let track = Track(title: payload.title, artist: payload.artist ?? "", album: payload.album ?? "", duration: payload.duration)
        let snapshot = PlaybackSnapshot(track: track, elapsed: payload.elapsed, rate: payload.rate, sampledAt: Date(timeIntervalSince1970: payload.sampledAt))
        let artwork = payload.artwork.flatMap { Data(base64Encoded: $0) }
        return (snapshot, artwork)
    }
}
