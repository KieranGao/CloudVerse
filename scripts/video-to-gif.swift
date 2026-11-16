import Foundation
import AVFoundation
import ImageIO

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("Video conversion failed: \(message)\n".utf8))
    exit(1)
}

let arguments = CommandLine.arguments
 guard arguments.count == 8,
      let start = Double(arguments[3]), start.isFinite, start >= 0,
      let length = Double(arguments[4]), length.isFinite, length > 0, length <= 60,
      let width = Double(arguments[5]), width.isFinite, (320...1920).contains(width),
      let fps = Double(arguments[6]), fps.isFinite, (1...30).contains(fps),
      let cropTop = Double(arguments[7]), cropTop.isFinite, cropTop >= 0 else {
    fail("Usage: swift scripts/video-to-gif.swift INPUT OUTPUT START_SECONDS DURATION_SECONDS WIDTH FPS CROP_TOP_SOURCE_PIXELS")
}

let input = URL(fileURLWithPath: arguments[1]).standardizedFileURL
let output = URL(fileURLWithPath: arguments[2]).standardizedFileURL
 guard input != output, FileManager.default.fileExists(atPath: input.path), output.pathExtension.lowercased() == "gif" else {
    fail("Input must exist and output must be a different GIF file")
}

Task {
    do {
        let asset = AVURLAsset(url: input)
        let duration = try await asset.load(.duration)
        guard duration.seconds.isFinite, start < duration.seconds,
              let track = try await asset.loadTracks(withMediaType: .video).first else {
            fail("No video track or invalid start time")
        }
        let naturalSize = try await track.load(.naturalSize)
        let transform = try await track.load(.preferredTransform)
        let oriented = CGRect(origin: .zero, size: naturalSize).applying(transform).standardized.size
        guard oriented.width > 0, oriented.height > cropTop else { fail("Crop removes the entire picture") }
        let seconds = min(length, duration.seconds - start)
        let count = Int(ceil(seconds * fps))
        let frameDelay = seconds / Double(count)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: width, height: ceil(width * oriented.height / oriented.width))
        generator.requestedTimeToleranceBefore = CMTime(seconds: 1 / fps / 2, preferredTimescale: 60000)
        generator.requestedTimeToleranceAfter = generator.requestedTimeToleranceBefore
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "com.compuserve.gif" as CFString, count, nil) else {
            fail("Cannot create GIF destination")
        }
        CGImageDestinationSetProperties(destination, [
            kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]
        ] as CFDictionary)
        var dimensions = CGSize.zero
        for index in 0..<count {
            let position = start + Double(index) * frameDelay
            let (image, _) = try await generator.image(at: CMTime(seconds: position, preferredTimescale: 60000))
            let top = Int((cropTop * Double(image.width) / oriented.width).rounded())
            guard let cropped = image.cropping(to: CGRect(x: 0, y: top, width: image.width, height: image.height - top)) else {
                fail("Cannot crop frame \(index)")
            }
            dimensions = CGSize(width: cropped.width, height: cropped.height)
            autoreleasepool {
                CGImageDestinationAddImage(destination, cropped, [
                    kCGImagePropertyGIFDictionary: [
                        kCGImagePropertyGIFDelayTime: frameDelay,
                        kCGImagePropertyGIFUnclampedDelayTime: frameDelay
                    ]
                ] as CFDictionary)
            }
        }
        guard CGImageDestinationFinalize(destination) else { fail("GIF encoder failed") }
        try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
        try (data as Data).write(to: output, options: .atomic)
        print("GIF written: \(output.path)")
        print("\(Int(dimensions.width))×\(Int(dimensions.height)); \(count) frames; \(seconds)s; \(fps)fps; \(data.length) bytes; source untouched")
        exit(0)
    } catch {
        fail(error.localizedDescription)
    }
}
RunLoop.main.run()
