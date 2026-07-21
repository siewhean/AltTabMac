#!/usr/bin/env swift

import AppKit
import AVFoundation
import Foundation

struct ShowcaseManifest: Decodable {
    struct Asset: Decodable {
        let id: String
        let poster: String
        let video: String
        let width: Int
        let height: Int
        let frameRate: Int
        let durationSeconds: Double
        let posterBytes: Int
        let videoBytes: Int
        let videoCodec: String
        let hasAudio: Bool
        let sourceType: String
        let disclosure: String
    }

    let schemaVersion: Int
    let reviewedAt: String
    let source: String
    let fixturePolicy: String
    let assets: [Asset]
}

enum ValidationError: Error, CustomStringConvertible {
    case failed(String)

    var description: String {
        switch self {
        case let .failed(message): return message
        }
    }
}

@main
struct ShowcaseMediaValidator {
    static func main() async {
        do {
            try await validate()
        } catch {
            fputs("Showcase media validation failed: \(error)\n", stderr)
            exit(EXIT_FAILURE)
        }
    }

    private static func validate() async throws {
        let arguments = CommandLine.arguments
        guard arguments.count == 2 else {
            throw ValidationError.failed("Usage: validate_showcase_media.swift <showcase-directory>")
        }

        let directory = URL(fileURLWithPath: arguments[1], isDirectory: true)
        let manifestURL = directory.appendingPathComponent("manifest.json")
        let manifest = try JSONDecoder().decode(
            ShowcaseManifest.self,
            from: Data(contentsOf: manifestURL)
        )

        guard manifest.schemaVersion == 1 else {
            throw ValidationError.failed("Unexpected manifest schema version")
        }
        guard manifest.source.contains("production SwiftUI/AppKit") else {
            throw ValidationError.failed("Manifest must identify the production view source")
        }
        guard manifest.fixturePolicy.contains("no private desktop capture") else {
            throw ValidationError.failed("Manifest must preserve the privacy-safe fixture policy")
        }

        let expectedIDs = Set([
            "overview",
            "classic-grid",
            "command-palette",
            "radial-menu",
            "quick-actions",
        ])
        guard Set(manifest.assets.map(\.id)) == expectedIDs else {
            throw ValidationError.failed("Manifest asset IDs do not match the expected showcase set")
        }

        for asset in manifest.assets {
            try validateManifestAsset(asset)
            try validatePoster(asset, directory: directory)
            try await validateVideo(asset, directory: directory)
        }

        try validateContactSheet(directory: directory)

        let totalBytes = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey]
        )
        .reduce(0) { partial, url in
            let values = try url.resourceValues(forKeys: [.fileSizeKey])
            return partial + (values.fileSize ?? 0)
        }
        guard totalBytes < 45_000_000 else {
            throw ValidationError.failed("Showcase package is too large: \(totalBytes) bytes")
        }

        print("Showcase media validation passed for \(manifest.assets.count) MP4 loops.")
        print("Total package size: \(totalBytes) bytes")
    }

    private static func validateManifestAsset(_ asset: ShowcaseManifest.Asset) throws {
        guard asset.width == 1280, asset.height == 800 else {
            throw ValidationError.failed("\(asset.id) has unexpected dimensions in manifest")
        }
        guard asset.frameRate == 20 else {
            throw ValidationError.failed("\(asset.id) has unexpected frame rate")
        }
        guard asset.durationSeconds >= 3.5, asset.durationSeconds <= 12.5 else {
            throw ValidationError.failed("\(asset.id) duration is outside the short-loop range")
        }
        guard asset.posterBytes >= 80_000, asset.posterBytes <= 3_500_000 else {
            throw ValidationError.failed("\(asset.id) poster size is implausible: \(asset.posterBytes)")
        }
        // A short, mostly static H.264 loop can be well below 120 KB without being
        // broken. Track validation, duration, dimensions, audio absence, and visual
        // variance provide the substantive checks.
        guard asset.videoBytes >= 50_000, asset.videoBytes <= 8_000_000 else {
            throw ValidationError.failed("\(asset.id) video size is implausible: \(asset.videoBytes)")
        }
        guard asset.videoCodec == "H.264" else {
            throw ValidationError.failed("\(asset.id) must use H.264")
        }
        guard asset.hasAudio == false else {
            throw ValidationError.failed("\(asset.id) must be silent")
        }
        guard asset.sourceType.contains("production SwiftUI render") else {
            throw ValidationError.failed("\(asset.id) source type is not explicit")
        }
        guard asset.disclosure.contains("controlled fixture windows") else {
            throw ValidationError.failed("\(asset.id) fixture disclosure is missing")
        }
    }

    private static func validatePoster(
        _ asset: ShowcaseManifest.Asset,
        directory: URL
    ) throws {
        let url = directory.appendingPathComponent(asset.poster)
        guard let image = NSImage(contentsOf: url) else {
            throw ValidationError.failed("Could not decode poster \(asset.poster)")
        }
        var rect = NSRect(origin: .zero, size: image.size)
        guard let cgImage = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
            throw ValidationError.failed("Could not inspect poster \(asset.poster)")
        }
        guard cgImage.width == asset.width, cgImage.height == asset.height else {
            throw ValidationError.failed(
                "\(asset.poster) is \(cgImage.width)x\(cgImage.height), expected \(asset.width)x\(asset.height)"
            )
        }

        let fileBytes = try Data(contentsOf: url).count
        guard fileBytes == asset.posterBytes else {
            throw ValidationError.failed("Poster byte count diverges from manifest for \(asset.id)")
        }
        try validateImageVariance(cgImage, name: asset.poster)
        try validateSwitcherRegionVariance(cgImage, name: asset.poster)
    }

    private static func validateVideo(
        _ asset: ShowcaseManifest.Asset,
        directory: URL
    ) async throws {
        let url = directory.appendingPathComponent(asset.video)
        let fileBytes = try Data(contentsOf: url).count
        guard fileBytes == asset.videoBytes else {
            throw ValidationError.failed("Video byte count diverges from manifest for \(asset.id)")
        }

        let avAsset = AVURLAsset(url: url)
        let duration = try await avAsset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        guard durationSeconds.isFinite,
              abs(durationSeconds - asset.durationSeconds) <= 0.16 else {
            throw ValidationError.failed(
                "\(asset.video) duration \(durationSeconds) does not match manifest \(asset.durationSeconds)"
            )
        }

        let videoTracks = try await avAsset.loadTracks(withMediaType: .video)
        let audioTracks = try await avAsset.loadTracks(withMediaType: .audio)
        guard videoTracks.count == 1 else {
            throw ValidationError.failed("\(asset.video) must contain one video track")
        }
        guard audioTracks.isEmpty else {
            throw ValidationError.failed("\(asset.video) unexpectedly contains audio")
        }

        let naturalSize = try await videoTracks[0].load(.naturalSize)
        let transform = try await videoTracks[0].load(.preferredTransform)
        let transformed = naturalSize.applying(transform)
        let width = Int(abs(transformed.width).rounded())
        let height = Int(abs(transformed.height).rounded())
        guard width == asset.width, height == asset.height else {
            throw ValidationError.failed(
                "\(asset.video) track is \(width)x\(height), expected \(asset.width)x\(asset.height)"
            )
        }
    }

    private static func validateContactSheet(directory: URL) throws {
        let url = directory.appendingPathComponent("contact-sheet.png")
        guard let image = NSImage(contentsOf: url) else {
            throw ValidationError.failed("Missing contact-sheet.png")
        }
        var rect = NSRect(origin: .zero, size: image.size)
        guard let cgImage = image.cgImage(forProposedRect: &rect, context: nil, hints: nil),
              cgImage.width == 1600,
              cgImage.height == 1100 else {
            throw ValidationError.failed("Contact sheet must be 1600x1100")
        }
        try validateImageVariance(cgImage, name: "contact-sheet.png")
    }

    private static func validateImageVariance(_ image: CGImage, name: String) throws {
        let stats = try imageStats(
            image,
            xRange: 0..<image.width,
            yRange: 0..<image.height,
            horizontalSamples: 24,
            verticalSamples: 18
        )

        guard stats.bucketCount >= 18 else {
            throw ValidationError.failed("\(name) appears visually blank or uniform")
        }
        guard stats.meanLuminance >= 5, stats.meanLuminance <= 245 else {
            throw ValidationError.failed("\(name) has implausible mean luminance \(stats.meanLuminance)")
        }
    }

    /// The surrounding desktop is intentionally decorative, so whole-image
    /// variance alone cannot catch a blank switcher panel. Sample the central
    /// product region separately and require both color variety and luminance
    /// deviation. This would have rejected the first LazyVGrid/LazyVStack pass.
    private static func validateSwitcherRegionVariance(_ image: CGImage, name: String) throws {
        let xRange = Int(Double(image.width) * 0.12)..<Int(Double(image.width) * 0.88)
        let yRange = Int(Double(image.height) * 0.14)..<Int(Double(image.height) * 0.78)
        let stats = try imageStats(
            image,
            xRange: xRange,
            yRange: yRange,
            horizontalSamples: 30,
            verticalSamples: 22
        )

        guard stats.bucketCount >= 14, stats.luminanceStandardDeviation >= 3.0 else {
            throw ValidationError.failed(
                "\(name) central switcher region appears blank: buckets=\(stats.bucketCount), luminanceSD=\(stats.luminanceStandardDeviation)"
            )
        }
    }

    private static func imageStats(
        _ image: CGImage,
        xRange: Range<Int>,
        yRange: Range<Int>,
        horizontalSamples: Int,
        verticalSamples: Int
    ) throws -> (bucketCount: Int, meanLuminance: Double, luminanceStandardDeviation: Double) {
        guard let dataProvider = image.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else {
            throw ValidationError.failed("Could not sample image pixels")
        }

        let bytesPerPixel = max(1, image.bitsPerPixel / 8)
        let bytesPerRow = image.bytesPerRow
        let xStep = max(1, xRange.count / max(1, horizontalSamples))
        let yStep = max(1, yRange.count / max(1, verticalSamples))
        var buckets = Set<Int>()
        var luminances: [Double] = []

        for y in stride(from: yRange.lowerBound, to: yRange.upperBound, by: yStep) {
            for x in stride(from: xRange.lowerBound, to: xRange.upperBound, by: xStep) {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let first = Int(bytes[offset])
                let second = Int(bytes[offset + min(1, bytesPerPixel - 1)])
                let third = Int(bytes[offset + min(2, bytesPerPixel - 1)])
                buckets.insert((first / 24) * 100 + (second / 24) * 10 + (third / 24))
                luminances.append(0.2126 * Double(first) + 0.7152 * Double(second) + 0.0722 * Double(third))
            }
        }

        let mean = luminances.reduce(0, +) / Double(max(1, luminances.count))
        let variance = luminances.reduce(0) { partial, value in
            let delta = value - mean
            return partial + delta * delta
        } / Double(max(1, luminances.count))

        return (buckets.count, mean, sqrt(variance))
    }
}
