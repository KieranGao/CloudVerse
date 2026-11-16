import Foundation

public struct SongCandidate: Codable, Equatable, Identifiable, Sendable {
    public let id: Int
    public let title: String
    public let artists: [String]
    public let album: String
    public let duration: TimeInterval
    public let artworkURL: URL?
    public var artist: String { artists.joined(separator: " / ") }

    public init(id: Int, title: String, artists: [String], album: String, duration: TimeInterval, artworkURL: URL? = nil) {
        self.id = id
        self.title = title
        self.artists = artists
        self.album = album
        self.duration = duration
        self.artworkURL = artworkURL
    }
}

public enum SongMatcher {
    public static func ranked(_ songs: [SongCandidate], for track: Track) -> [SongCandidate] {
        songs.sorted { score($0, track) > score($1, track) }
    }

    public static func automatic(_ songs: [SongCandidate], for track: Track) -> SongCandidate? {
        ranked(songs, for: track).first { song in
            normalize(song.title) == normalize(track.title) && artistMatches(song, track) &&
            (track.duration == 0 || song.duration == 0 || abs(song.duration - track.duration) <= 8)
        }
    }

    private static func score(_ song: SongCandidate, _ track: Track) -> Double {
        let title = normalize(song.title)
        let target = normalize(track.title)
        let titleScore = title == target ? 0.6 : (!target.isEmpty && title.contains(target) ? 0.3 : 0)
        let artistScore = artistMatches(song, track) ? 0.28 : 0
        let durationScore = track.duration > 0 && song.duration > 0 ? 0.1 * max(0, 1 - abs(track.duration - song.duration) / 30) : 0
        let albumScore = !track.album.isEmpty && normalize(song.album) == normalize(track.album) ? 0.02 : 0
        return titleScore + artistScore + durationScore + albumScore
    }

    private static func artistMatches(_ song: SongCandidate, _ track: Track) -> Bool {
        let target = normalize(track.artist)
        guard !target.isEmpty else { return false }
        return normalize(song.artist) == target || song.artists.contains { normalize($0) == target }
    }

    private static func normalize(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.map(String.init).joined()
    }
}

public enum MusicError: LocalizedError {
    case invalidPayload
    case service(Int, String)
    case responseTooLarge
    public var errorDescription: String? {
        switch self {
        case .invalidPayload: return "歌词服务返回了无法识别的数据"
        case .service(let code, let message): return "歌词服务错误 \(code)：\(message)"
        case .responseTooLarge: return "歌词服务返回的数据过大"
        }
    }
}

public enum MusicPayload {
    public static func search(_ data: Data) throws -> [SongCandidate] {
        let root = try object(data)
        let result = root["result"] as? [String: Any] ?? [:]
        return (result["songs"] as? [[String: Any]] ?? []).compactMap { song in
            guard let id = song["id"] as? Int, id > 0, let title = song["name"] as? String, !title.isEmpty else { return nil }
            let artists = (song["artists"] ?? song["ar"]) as? [[String: Any]] ?? []
            let album = (song["album"] ?? song["al"]) as? [String: Any] ?? [:]
            let duration = ((song["duration"] ?? song["dt"]) as? NSNumber)?.doubleValue ?? 0
            var artwork = (album["picUrl"] as? String).flatMap(URL.init(string:))
            if let url = artwork, url.scheme == "http", var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                components.scheme = "https"
                artwork = components.url
            }
            if artwork?.scheme != "https" { artwork = nil }
            return SongCandidate(id: id, title: title, artists: artists.compactMap { $0["name"] as? String }, album: album["name"] as? String ?? "", duration: duration / 1000, artworkURL: artwork)
        }
    }

    public static func lyrics(_ data: Data) throws -> LyricDocument {
        let root = try object(data)
        func text(_ key: String) -> String? { (root[key] as? [String: Any])?["lyric"] as? String }
        guard root["nolyric"] as? Bool == true || root["uncollected"] as? Bool == true || text("lrc") != nil || text("yrc") != nil else { throw MusicError.invalidPayload }
        return LyricParser.document(lrc: text("lrc"), yrc: text("yrc"), translation: text("ytlrc") ?? text("tlyric"))
    }

    private static func object(_ data: Data) throws -> [String: Any] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any], let code = root["code"] as? Int else { throw MusicError.invalidPayload }
        guard code == 200 else { throw MusicError.service(code, root["msg"] as? String ?? root["message"] as? String ?? "请求未成功") }
        return root
    }
}
