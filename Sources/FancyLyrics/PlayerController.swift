import Foundation
import LyricsCore

struct ControlResult: Decodable, Sendable {
    let accepted: Bool
    let reason: String
}

actor PlayerController {
    func send(_ command: PlayerCommand) -> ControlResult {
        BridgeClient().control(action: command.rawValue)
    }
}
