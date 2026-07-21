import AppKit
import AVFoundation
import CoreImage
import CoreVideo
import SwiftUI

#if canImport(Darwin)
import Darwin
#endif

enum ShowcaseRendererError: Error, CustomStringConvertible {
    case invalidArguments(String)
    case renderFailed(String)
    case videoEncodingFailed(String)
    case writeFailed(String)

    var description: String {
        switch self {
        case let .invalidArguments(message):
            return message
        case let .renderFailed(message):
            return "Showcase render failed: \(message)"
        case let .videoEncodingFailed(message):
            return "Showcase video encoding failed: \(message)"
        case let .writeFailed(message):
            return "Showcase file write failed: \(message)"
        }
    }
}

/// Generates deterministic website media from CmdTab's production SwiftUI views.
///
/// The switcher UI is real production code. Window contents are controlled fixture
/// previews so the generated assets contain no private desktop data and are stable
/// across CI runs.
@MainActor
enum ShowcaseRenderer {
    private static let canvasSize = CGSize(width: 1280, height: 800)
    private static let frameRate: Int32 = 20
    private static let reviewDate = "2026-07-21"
    private static let disclosure =
        "Production CmdTab SwiftUI rendered with controlled fixture windows; not a recording of a user's desktop."

    private struct RenderedClip {
        let id: String
        let title: String
        let description: String
        let posterURL: URL
        let videoURL: URL
        let posterImage: CGImage
        let states: [CGImage]
        let duration: Double
    }

    static func render(to outputDirectory: URL) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )

        let preferences = SwitcherPreferences.shared
        preferences.enableVibrancy = false
        preferences.showSelectedPreviewBackdrop = false

        let allItems = try ShowcaseFixtureFactory.makeItems()
        guard allItems.count >= 8 else {
            throw ShowcaseRendererError.renderFailed("Expected at least eight fixture windows")
        }

        let classicStates = try renderClassicStates(items: Array(allItems.prefix(6)))
        let paletteStates = try renderPaletteStates(items: allItems)
        let radialStates = try renderRadialStates(items: allItems)
        let quickActionStates = try renderQuickActionStates(items: Array(allItems.prefix(6)))

        let classic = try writeClip(
            id: "classic-grid",
            title: "Classic Grid exact-window selection",
            description: "The production Classic Grid view moves selection across separate exact-window targets, including multiple windows that could belong to one application.",
            states: classicStates,
            posterStateIndex: 1,
            holdDuration: 0.58,
            transitionDuration: 0.24,
            outputDirectory: outputDirectory
        )
        let palette = try writeClip(
            id: "command-palette",
            title: "Command Palette local window search",
            description: "The production Command Palette view narrows the exact-window set as a local query is entered, then returns to the unfiltered recent-use sequence.",
            states: paletteStates,
            posterStateIndex: 3,
            holdDuration: 0.58,
            transitionDuration: 0.22,
            outputDirectory: outputDirectory
        )
        let radial = try writeClip(
            id: "radial-menu",
            title: "Radial Menu directional selection",
            description: "The production Radial Menu view advances the highlighted exact-window target around the circular viewport.",
            states: radialStates,
            posterStateIndex: 2,
            holdDuration: 0.42,
            transitionDuration: 0.18,
            outputDirectory: outputDirectory
        )
        let quickActions = try writeClip(
            id: "quick-actions",
            title: "Quick Action selected-item removal",
            description: "The production Classic Grid item mutation shows a selected fixture window leaving the switcher after an annotated close action. The key badge is an explanatory capture annotation, not an in-app overlay.",
            states: quickActionStates,
            posterStateIndex: 0,
            holdDuration: 0.66,
            transitionDuration: 0.26,
            outputDirectory: outputDirectory
        )

        let overviewStates = [
            classic.states[0],
            classic.states[min(2, classic.states.count - 1)],
            palette.states[0],
            palette.states[min(3, palette.states.count - 1)],
            radial.states[0],
            radial.states[min(3, radial.states.count - 1)],
            quickActions.states[0],
            quickActions.states[min(2, quickActions.states.count - 1)],
        ]
        let overview = try writeClip(
            id: "overview",
            title: "CmdTab app switcher showcase",
            description: "A short overview assembled from real production renders of Classic Grid, Command Palette, Radial Menu, and a Quick Action item mutation using controlled fixture windows.",
            states: overviewStates,
            posterStateIndex: 0,
            holdDuration: 0.72,
            transitionDuration: 0.30,
            outputDirectory: outputDirectory
        )

        let clips = [overview, classic, palette, radial, quickActions]
        try writeContactSheet(clips: [classic, palette, radial, quickActions], to: outputDirectory)
        try writeManifest(clips: clips, outputDirectory: outputDirectory)
        try writeReadme(outputDirectory: outputDirectory)

        print("Rendered CmdTab showcase media to \(outputDirectory.path)")
        for clip in clips {
            print(String(format: "- %@: %.2fs", clip.id, clip.duration))
        }
    }

    // MARK: - Production view states

    private static func renderClassicStates(items: [SwitcherItem]) throws -> [CGImage] {
        let selectedIndices = [0, 1, 2, 4, 5, 3]
        return try selectedIndices.map { index in
            let viewModel = SwitcherViewModel()
            viewModel.items = items
            viewModel.selectedIndex = min(index, items.count - 1)
            viewModel.layout = SwitcherLayoutMetrics.make(
                itemCount: items.count,
                visibleFrame: CGRect(x: 0, y: 0, width: 1180, height: 700)
            )
            return try renderCanvas(
                panel: AnyView(
                    ClassicGridView(viewModel: viewModel)
                        .frame(
                            width: viewModel.layout.contentWidth,
                            height: viewModel.layout.contentHeight
                        )
                ),
                modeLabel: "Classic Grid",
                detail: "Individual exact-window previews",
                annotation: nil
            )
        }
    }

    private static func renderPaletteStates(items: [SwitcherItem]) throws -> [CGImage] {
        let queries = ["", "s", "sw", "swi", "switch", ""]
        return try queries.enumerated().map { stateIndex, query in
            let filtered = query.isEmpty
                ? items
                : PaletteSearch.rankedItems(items, query: query)
            let viewModel = SwitcherViewModel()
            viewModel.items = filtered
            viewModel.selectedIndex = min(stateIndex == queries.count - 1 ? 1 : 0, max(0, filtered.count - 1))
            viewModel.searchQuery = query
            viewModel.layout = SwitcherLayoutMetrics.makePalette(
                itemCount: max(items.count, filtered.count),
                visibleFrame: CGRect(x: 0, y: 0, width: 1180, height: 700)
            )
            return try renderCanvas(
                panel: AnyView(CommandPaletteView(viewModel: viewModel)),
                modeLabel: "Command Palette",
                detail: query.isEmpty ? "Local app and window search" : "Query: \(query)",
                annotation: nil
            )
        }
    }

    private static func renderRadialStates(items: [SwitcherItem]) throws -> [CGImage] {
        let selectedIndices = [0, 1, 2, 3, 4, 5, 6, 7]
        return try selectedIndices.map { index in
            let viewModel = SwitcherViewModel()
            viewModel.items = items
            viewModel.selectedIndex = index
            viewModel.layout = SwitcherLayoutMetrics.makeRadial(itemCount: items.count)
            var viewport = RadialMenuViewportState()
            viewport.reset(itemCount: items.count, selectedIndex: index)
            viewModel.radialViewportState = viewport
            return try renderCanvas(
                panel: AnyView(RadialMenuView(viewModel: viewModel)),
                modeLabel: "Radial Menu",
                detail: "Directional exact-window selection",
                annotation: nil
            )
        }
    }

    private static func renderQuickActionStates(items: [SwitcherItem]) throws -> [CGImage] {
        let selectedIndex = min(2, items.count - 1)
        let selectedTitle = items[selectedIndex].title
        let remainingItems = items.enumerated()
            .filter { $0.offset != selectedIndex }
            .map(\.element)

        let definitions: [(items: [SwitcherItem], selected: Int, annotation: String?)] = [
            (items, selectedIndex, "⌘W  Close ‘\(selectedTitle)’"),
            (items, selectedIndex, "Quick Action dispatched"),
            (remainingItems, min(selectedIndex, remainingItems.count - 1), "Selected target removed"),
            (remainingItems, min(selectedIndex + 1, remainingItems.count - 1), nil),
        ]

        return try definitions.map { state in
            let viewModel = SwitcherViewModel()
            viewModel.items = state.items
            viewModel.selectedIndex = max(0, state.selected)
            viewModel.layout = SwitcherLayoutMetrics.make(
                itemCount: state.items.count,
                visibleFrame: CGRect(x: 0, y: 0, width: 1180, height: 700)
            )
            return try renderCanvas(
                panel: AnyView(
                    ClassicGridView(viewModel: viewModel)
                        .frame(
                            width: viewModel.layout.contentWidth,
                            height: viewModel.layout.contentHeight
                        )
                ),
                modeLabel: "Quick Actions",
                detail: "Annotated exact-window item mutation",
                annotation: state.annotation
            )
        }
    }

    // MARK: - Rendering

    private static func renderCanvas(
        panel: AnyView,
        modeLabel: String,
        detail: String,
        annotation: String?
    ) throws -> CGImage {
        let content = ShowcaseDesktopCanvas(
            panel: panel,
            modeLabel: modeLabel,
            detail: detail,
            annotation: annotation,
            disclosure: disclosure
        )
        .frame(width: canvasSize.width, height: canvasSize.height)
        .environment(\.colorScheme, .dark)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 1
        renderer.isOpaque = true

        guard let image = renderer.nsImage else {
            throw ShowcaseRendererError.renderFailed("ImageRenderer returned no image for \(modeLabel)")
        }
        return try cgImage(from: image)
    }

    private static func cgImage(from image: NSImage) throws -> CGImage {
        var rect = NSRect(origin: .zero, size: image.size)
        guard let cgImage = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
            throw ShowcaseRendererError.renderFailed("Could not create CGImage")
        }
        return cgImage
    }

    private static func blend(
        from first: CGImage,
        to second: CGImage,
        progress: CGFloat
    ) throws -> CGImage {
        let width = Int(canvasSize.width)
        let height = Int(canvasSize.height)
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw ShowcaseRendererError.renderFailed("Could not create blend context")
        }

        let rect = CGRect(origin: .zero, size: canvasSize)
        context.draw(first, in: rect)
        context.saveGState()
        context.setAlpha(min(max(progress, 0), 1))
        context.draw(second, in: rect)
        context.restoreGState()

        guard let image = context.makeImage() else {
            throw ShowcaseRendererError.renderFailed("Could not create blended image")
        }
        return image
    }

    // MARK: - Clip writing

    private static func writeClip(
        id: String,
        title: String,
        description: String,
        states: [CGImage],
        posterStateIndex: Int,
        holdDuration: Double,
        transitionDuration: Double,
        outputDirectory: URL
    ) throws -> RenderedClip {
        guard !states.isEmpty else {
            throw ShowcaseRendererError.renderFailed("No states supplied for \(id)")
        }

        let posterImage = states[min(max(0, posterStateIndex), states.count - 1)]
        let posterURL = outputDirectory.appendingPathComponent("\(id)-poster.png")
        let videoURL = outputDirectory.appendingPathComponent("\(id).mp4")

        try writePNG(posterImage, to: posterURL)
        try? FileManager.default.removeItem(at: videoURL)

        let writer = try ShowcaseH264Writer(
            outputURL: videoURL,
            size: canvasSize,
            frameRate: frameRate
        )
        let holdFrames = max(1, Int((holdDuration * Double(frameRate)).rounded()))
        let transitionFrames = max(1, Int((transitionDuration * Double(frameRate)).rounded()))
        var frameIndex = 0

        for stateIndex in states.indices {
            let current = states[stateIndex]
            let next = states[(stateIndex + 1) % states.count]

            for _ in 0..<holdFrames {
                try writer.append(current, frameIndex: frameIndex)
                frameIndex += 1
            }

            for transitionIndex in 1...transitionFrames {
                let progress = CGFloat(transitionIndex) / CGFloat(transitionFrames + 1)
                let frame = try blend(from: current, to: next, progress: progress)
                try writer.append(frame, frameIndex: frameIndex)
                frameIndex += 1
            }
        }

        try writer.finish()
        let duration = Double(frameIndex) / Double(frameRate)

        return RenderedClip(
            id: id,
            title: title,
            description: description,
            posterURL: posterURL,
            videoURL: videoURL,
            posterImage: posterImage,
            states: states,
            duration: duration
        )
    }

    private static func writePNG(_ image: CGImage, to url: URL) throws {
        let representation = NSBitmapImageRep(cgImage: image)
        guard let data = representation.representation(
            using: .png,
            properties: [.compressionFactor: 0.82]
        ) else {
            throw ShowcaseRendererError.writeFailed("Could not encode \(url.lastPathComponent)")
        }
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw ShowcaseRendererError.writeFailed("\(url.lastPathComponent): \(error)")
        }
    }

    // MARK: - Contact sheet and manifest

    private static func writeContactSheet(
        clips: [RenderedClip],
        to outputDirectory: URL
    ) throws {
        let entries = clips.map { clip in
            ShowcaseContactSheet.Entry(
                title: clip.title,
                image: NSImage(cgImage: clip.posterImage, size: canvasSize)
            )
        }
        let size = CGSize(width: 1600, height: 1100)
        let renderer = ImageRenderer(
            content: ShowcaseContactSheet(entries: entries)
                .frame(width: size.width, height: size.height)
                .environment(\.colorScheme, .dark)
        )
        renderer.scale = 1
        renderer.isOpaque = true
        guard let image = renderer.nsImage else {
            throw ShowcaseRendererError.renderFailed("Could not render contact sheet")
        }
        try writePNG(
            try cgImage(from: image),
            to: outputDirectory.appendingPathComponent("contact-sheet.png")
        )
    }

    private static func writeManifest(
        clips: [RenderedClip],
        outputDirectory: URL
    ) throws {
        let fileManager = FileManager.default
        let assets: [[String: Any]] = try clips.map { clip in
            let posterAttributes = try fileManager.attributesOfItem(atPath: clip.posterURL.path)
            let videoAttributes = try fileManager.attributesOfItem(atPath: clip.videoURL.path)
            return [
                "id": clip.id,
                "title": clip.title,
                "description": clip.description,
                "poster": clip.posterURL.lastPathComponent,
                "video": clip.videoURL.lastPathComponent,
                "width": Int(canvasSize.width),
                "height": Int(canvasSize.height),
                "frameRate": Int(frameRate),
                "durationSeconds": Double(String(format: "%.2f", clip.duration)) ?? clip.duration,
                "posterBytes": posterAttributes[.size] as? NSNumber ?? 0,
                "videoBytes": videoAttributes[.size] as? NSNumber ?? 0,
                "videoCodec": "H.264",
                "hasAudio": false,
                "sourceType": "production SwiftUI render with controlled fixture windows",
                "disclosure": disclosure,
            ]
        }

        let manifest: [String: Any] = [
            "schemaVersion": 1,
            "reviewedAt": reviewDate,
            "canvas": [
                "width": Int(canvasSize.width),
                "height": Int(canvasSize.height),
            ],
            "source": "CmdTab production SwiftUI/AppKit views",
            "fixturePolicy": "Generic deterministic fixture windows and system app icons; no private desktop capture.",
            "assets": assets,
        ]

        guard JSONSerialization.isValidJSONObject(manifest) else {
            throw ShowcaseRendererError.writeFailed("Showcase manifest is not valid JSON")
        }
        let data = try JSONSerialization.data(
            withJSONObject: manifest,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        try data.write(
            to: outputDirectory.appendingPathComponent("manifest.json"),
            options: .atomic
        )
    }

    private static func writeReadme(outputDirectory: URL) throws {
        let body = """
        # CmdTab showcase media

        These assets are generated from CmdTab's production SwiftUI/AppKit switcher views with deterministic fixture windows. They are not AI-generated and do not contain a developer's real desktop or personal data.

        The surrounding desktop, fixture window contents, and Quick Action key badge are capture-only explanatory context. The Classic Grid, Command Palette, Radial Menu, item selection, filtering, and item mutation surfaces are rendered from production app views.

        See `manifest.json` for stable filenames, dimensions, durations, codec information, and disclosure text.
        """
        try body.data(using: .utf8)?.write(
            to: outputDirectory.appendingPathComponent("README.md"),
            options: .atomic
        )
    }
}

// MARK: - Capture-only desktop context

private struct ShowcaseDesktopCanvas: View {
    let panel: AnyView
    let modeLabel: String
    let detail: String
    let annotation: String?
    let disclosure: String

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.018, green: 0.026, blue: 0.047),
                    Color(red: 0.035, green: 0.075, blue: 0.125),
                    Color(red: 0.025, green: 0.035, blue: 0.070),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color(red: 0.20, green: 0.62, blue: 1.0).opacity(0.12))
                .frame(width: 640, height: 640)
                .blur(radius: 85)
                .offset(x: 410, y: -290)
            Circle()
                .fill(Color(red: 0.55, green: 0.31, blue: 0.95).opacity(0.10))
                .frame(width: 520, height: 520)
                .blur(radius: 100)
                .offset(x: -470, y: 300)

            desktopFixture

            VStack(spacing: 0) {
                HStack {
                    HStack(spacing: 10) {
                        Image(systemName: "square.stack.3d.up.fill")
                            .foregroundStyle(Color(red: 0.45, green: 0.78, blue: 1.0))
                        Text("CmdTab showcase")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Text("Controlled fixture windows")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.48))
                }
                .padding(.horizontal, 24)
                .frame(height: 48)
                .background(Color.black.opacity(0.22))

                Spacer(minLength: 20)
                panel
                Spacer(minLength: 18)

                HStack(alignment: .center, spacing: 18) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(modeLabel)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(detail)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.56))
                    }
                    Spacer()
                    Text(disclosure)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.38))
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 430, alignment: .trailing)
                }
                .padding(.horizontal, 28)
                .frame(height: 70)
                .background(Color.black.opacity(0.28))
            }

            if let annotation {
                VStack {
                    HStack {
                        Spacer()
                        HStack(spacing: 10) {
                            Image(systemName: "keyboard.fill")
                            Text(annotation)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .background(
                            Color(red: 0.12, green: 0.28, blue: 0.58).opacity(0.92),
                            in: Capsule()
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color(red: 0.42, green: 0.72, blue: 1.0).opacity(0.65), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.36), radius: 18, y: 8)
                    }
                    Spacer()
                }
                .padding(.top, 66)
                .padding(.trailing, 26)
            }
        }
    }

    private var desktopFixture: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.028))
                .frame(width: 500, height: 300)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.045), lineWidth: 1)
                )
                .offset(x: -420, y: -165)
                .rotationEffect(.degrees(-4))

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.025))
                .frame(width: 440, height: 280)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.04), lineWidth: 1)
                )
                .offset(x: 430, y: -110)
                .rotationEffect(.degrees(4))

            HStack(spacing: 12) {
                ForEach(0..<7, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Color.white.opacity(index == 2 ? 0.12 : 0.065))
                        .frame(width: 46, height: 46)
                }
            }
            .padding(12)
            .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .offset(y: 320)
        }
        .allowsHitTesting(false)
    }
}

private struct ShowcaseContactSheet: View {
    struct Entry {
        let title: String
        let image: NSImage
    }

    let entries: [Entry]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.018, green: 0.026, blue: 0.047),
                    Color(red: 0.035, green: 0.075, blue: 0.125),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("CmdTab production UI showcase")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Real SwiftUI/AppKit renders with controlled fixture windows")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.56))
                }

                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 20), GridItem(.flexible(), spacing: 20)],
                    spacing: 20
                ) {
                    ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                        VStack(alignment: .leading, spacing: 10) {
                            Image(nsImage: entry.image)
                                .resizable()
                                .interpolation(.high)
                                .aspectRatio(contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            Text(entry.title)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.78))
                                .lineLimit(1)
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                    }
                }

                Text("Fixture media is privacy-safe and reproducible. Real signed-app permissions, Spaces, display, and exact-focus acceptance remain a separate test boundary.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.42))
            }
            .padding(42)
        }
    }
}

// MARK: - H.264 writer

private final class ShowcaseH264Writer {
    private let outputURL: URL
    private let size: CGSize
    private let frameRate: Int32
    private let writer: AVAssetWriter
    private let input: AVAssetWriterInput
    private let adaptor: AVAssetWriterInputPixelBufferAdaptor
    private let colorSpace = CGColorSpaceCreateDeviceRGB()

    init(outputURL: URL, size: CGSize, frameRate: Int32) throws {
        self.outputURL = outputURL
        self.size = size
        self.frameRate = frameRate

        do {
            writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        } catch {
            throw ShowcaseRendererError.videoEncodingFailed("Could not create writer: \(error)")
        }

        let compression: [String: Any] = [
            AVVideoAverageBitRateKey: 1_800_000,
            AVVideoMaxKeyFrameIntervalKey: Int(frameRate * 2),
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
        ]
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
            AVVideoCompressionPropertiesKey: compression,
        ]

        input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        guard writer.canAdd(input) else {
            throw ShowcaseRendererError.videoEncodingFailed("Writer rejected video input")
        }
        writer.add(input)

        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height),
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
        ]
        adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: attributes
        )

        guard writer.startWriting() else {
            throw ShowcaseRendererError.videoEncodingFailed(
                writer.error?.localizedDescription ?? "Writer did not start"
            )
        }
        writer.startSession(atSourceTime: .zero)
    }

    func append(_ image: CGImage, frameIndex: Int) throws {
        while !input.isReadyForMoreMediaData {
            if writer.status == .failed || writer.status == .cancelled {
                throw ShowcaseRendererError.videoEncodingFailed(
                    writer.error?.localizedDescription ?? "Writer stopped before frame \(frameIndex)"
                )
            }
            usleep(1_000)
        }

        guard let pool = adaptor.pixelBufferPool else {
            throw ShowcaseRendererError.videoEncodingFailed("Pixel buffer pool is unavailable")
        }
        var optionalBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &optionalBuffer)
        guard status == kCVReturnSuccess, let pixelBuffer = optionalBuffer else {
            throw ShowcaseRendererError.videoEncodingFailed("Could not allocate pixel buffer: \(status)")
        }

        try draw(image, into: pixelBuffer)
        let time = CMTime(value: CMTimeValue(frameIndex), timescale: frameRate)
        guard adaptor.append(pixelBuffer, withPresentationTime: time) else {
            throw ShowcaseRendererError.videoEncodingFailed(
                writer.error?.localizedDescription ?? "Could not append frame \(frameIndex)"
            )
        }
    }

    func finish() throws {
        input.markAsFinished()
        let semaphore = DispatchSemaphore(value: 0)
        writer.finishWriting {
            semaphore.signal()
        }
        semaphore.wait()

        guard writer.status == .completed else {
            throw ShowcaseRendererError.videoEncodingFailed(
                writer.error?.localizedDescription ?? "Writer did not complete \(outputURL.lastPathComponent)"
            )
        }
    }

    private func draw(_ image: CGImage, into pixelBuffer: CVPixelBuffer) throws {
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            throw ShowcaseRendererError.videoEncodingFailed("Pixel buffer has no base address")
        }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue |
            CGImageAlphaInfo.premultipliedFirst.rawValue

        guard let context = CGContext(
            data: baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            throw ShowcaseRendererError.videoEncodingFailed("Could not create pixel-buffer context")
        }

        context.setFillColor(NSColor.black.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    }
}