// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CloudVerse",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "LyricsCore", targets: ["LyricsCore"]),
        .library(name: "PlaybackBridge", type: .dynamic, targets: ["PlaybackBridge"]),
        .executable(name: "CloudVerse", targets: ["CloudVerse"])
    ],
    targets: [
        .target(name: "LyricsCore"),
        .target(name: "PlaybackBridge"),
        .executableTarget(name: "CloudVerse", dependencies: ["LyricsCore"]),
        .executableTarget(name: "CoreChecks", dependencies: ["LyricsCore"], path: "Tests/LyricsCoreTests")
    ]
)
