// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FancyLyrics",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "LyricsCore", targets: ["LyricsCore"]),
        .library(name: "PlaybackBridge", type: .dynamic, targets: ["PlaybackBridge"]),
        .executable(name: "FancyLyrics", targets: ["FancyLyrics"])
    ],
    targets: [
        .target(name: "LyricsCore"),
        .target(name: "PlaybackBridge"),
        .executableTarget(name: "FancyLyrics", dependencies: ["LyricsCore"]),
        .executableTarget(name: "CoreChecks", dependencies: ["LyricsCore"], path: "Tests/LyricsCoreTests")
    ]
)
