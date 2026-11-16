import Foundation
import LyricsCore

struct MusicTests {
    func run() {
        let track = Track(title: "夜航", artist: "Artist", album: "Album", duration: 180)
        let wrongArtist = SongCandidate(id: 1, title: "夜航", artists: ["Other"], album: "Album", duration: 180)
        let correct = SongCandidate(id: 2, title: "夜航", artists: ["Artist"], album: "Album", duration: 181)
        let live = SongCandidate(id: 3, title: "夜航 (Live)", artists: ["Artist"], album: "Album", duration: 220)
        expectEqual(SongMatcher.ranked([wrongArtist, live, correct], for: track).first?.id, 2)
        expectEqual(SongMatcher.automatic([wrongArtist, live, correct], for: track)?.id, 2)
        expectNil(SongMatcher.automatic([wrongArtist], for: track))
        expectNil(SongMatcher.automatic([live], for: track))
        expectEqual(SongMatcher.automatic([SongCandidate(id: 4, title: "SAY GOODBYE", artists: ["Lodoni"], album: "", duration: 106)], for: Track(title: "Say Goodbye", artist: "LODONI", duration: 106))?.id, 4)
        do {
            let data = Data(#"{"code":200,"result":{"songs":[{"id":2,"name":"夜航","artists":[{"name":"Artist"}],"album":{"name":"Album","picUrl":"https://example.org/a.jpg"},"duration":180000}]}}"#.utf8)
            let songs = try MusicPayload.search(data)
            expectEqual(songs.first?.id, 2)
            expectEqual(songs.first?.duration, 180)
            expectEqual(songs.first?.artists, ["Artist"])
            let modern = try MusicPayload.search(Data(#"{"code":200,"result":{"songs":[{"id":3,"name":"Modern","ar":[{"name":"A"}],"al":{"name":"B"},"dt":120000}]}}"#.utf8))
            expectEqual(modern.first?.duration, 120)
            let lyrics = try MusicPayload.lyrics(Data(#"{"code":200,"lrc":{"lyric":"[00:01]Hello"},"tlyric":{"lyric":"[00:01]你好"}}"#.utf8))
            expectEqual(lyrics.lines.first?.translation, "你好")
            let empty = try MusicPayload.lyrics(Data(#"{"code":200,"nolyric":true}"#.utf8))
            expectTrue(empty.lines.isEmpty)
        } catch {
            expectTrue(false)
            print("Unexpected payload error: \(error)")
        }
        do {
            _ = try MusicPayload.search(Data(#"{"code":400,"msg":"wrong params"}"#.utf8))
            expectTrue(false)
        } catch { expectTrue(true) }
        do {
            _ = try MusicPayload.lyrics(Data(#"{"code":200,"unexpected":"shape"}"#.utf8))
            expectTrue(false)
        } catch { expectTrue(true) }
        do {
            _ = try MusicPayload.lyrics(Data("<html>error</html>".utf8))
            expectTrue(false)
        } catch { expectTrue(true) }
    }
}
