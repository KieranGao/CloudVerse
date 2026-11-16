import Foundation

public actor MusicService {
    private let session: URLSession
    private let cache: LyricCache

    public init(cacheDirectory: URL? = nil) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 12
        configuration.timeoutIntervalForResource = 20
        configuration.httpShouldSetCookies = false
        session = URLSession(configuration: configuration)
        let folder = cacheDirectory ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("FancyLyrics/Lyrics", isDirectory: true)
        cache = LyricCache(directory: folder)
    }

    public func search(_ query: String) async throws -> [SongCandidate] {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return [] }
        let data = try await fetch(path: "/api/search/get", query: ["s": String(clean.prefix(300)), "type": "1", "limit": "12"])
        return try MusicPayload.search(data)
    }

    public func lyrics(songID: Int, forceRefresh: Bool = false) async throws -> LyricDocument {
        guard songID > 0 else { throw MusicError.invalidPayload }
        if !forceRefresh, let saved = await cache.load(songID: songID) { return saved }
        let data = try await fetch(path: "/api/song/lyric", query: ["id": String(songID), "lv": "-1", "kv": "-1", "tv": "-1", "rv": "-1", "yv": "-1"])
        let document = try MusicPayload.lyrics(data)
        try Task.checkCancellation()
        try? await cache.save(document, songID: songID)
        return document
    }

    private func fetch(path: String, query: [String: String]) async throws -> Data {
        var url = URLComponents()
        url.scheme = "https"
        url.host = "music.163.com"
        url.path = path
        url.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let endpoint = url.url else { throw MusicError.invalidPayload }
        var request = URLRequest(url: endpoint)
        request.setValue("Mozilla/5.0 FancyLyrics/0.1", forHTTPHeaderField: "User-Agent")
        request.setValue("https://music.163.com/", forHTTPHeaderField: "Referer")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw MusicError.invalidPayload }
        guard (200..<300).contains(http.statusCode) else { throw MusicError.service(http.statusCode, HTTPURLResponse.localizedString(forStatusCode: http.statusCode)) }
        guard data.count <= 8 * 1024 * 1024 else { throw MusicError.responseTooLarge }
        try Task.checkCancellation()
        return data
    }
}
