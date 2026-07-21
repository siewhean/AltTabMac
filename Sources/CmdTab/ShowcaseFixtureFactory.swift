import AppKit
import SwiftUI

/// Deterministic, privacy-safe data used only by the website showcase renderer.
///
/// The switcher views themselves are the production views. These fixture windows
/// provide reproducible previews and titles without recording a developer's real
/// desktop or requiring third-party applications to be launched in CI.
@MainActor
enum ShowcaseFixtureFactory {
    enum PreviewStyle {
        case browser
        case code
        case mail
        case notes
        case calendar
        case terminal
        case music
        case document
    }

    struct FixtureDefinition {
        let title: String
        let appName: String
        let bundleIdentifiers: [String]
        let fallbackSymbol: String
        let accent: Color
        let previewStyle: PreviewStyle
    }

    static let definitions: [FixtureDefinition] = [
        FixtureDefinition(
            title: "Release notes",
            appName: "Safari",
            bundleIdentifiers: ["com.apple.Safari"],
            fallbackSymbol: "safari.fill",
            accent: Color(red: 0.17, green: 0.62, blue: 0.98),
            previewStyle: .browser
        ),
        FixtureDefinition(
            title: "SwitcherView.swift",
            appName: "Xcode",
            bundleIdentifiers: ["com.apple.dt.Xcode"],
            fallbackSymbol: "hammer.fill",
            accent: Color(red: 0.31, green: 0.67, blue: 1.0),
            previewStyle: .code
        ),
        FixtureDefinition(
            title: "Beta feedback",
            appName: "Mail",
            bundleIdentifiers: ["com.apple.mail"],
            fallbackSymbol: "envelope.fill",
            accent: Color(red: 0.20, green: 0.55, blue: 0.98),
            previewStyle: .mail
        ),
        FixtureDefinition(
            title: "Launch checklist",
            appName: "Notes",
            bundleIdentifiers: ["com.apple.Notes"],
            fallbackSymbol: "note.text",
            accent: Color(red: 0.98, green: 0.77, blue: 0.24),
            previewStyle: .notes
        ),
        FixtureDefinition(
            title: "Release week",
            appName: "Calendar",
            bundleIdentifiers: ["com.apple.iCal"],
            fallbackSymbol: "calendar",
            accent: Color(red: 0.96, green: 0.30, blue: 0.28),
            previewStyle: .calendar
        ),
        FixtureDefinition(
            title: "swift test",
            appName: "Terminal",
            bundleIdentifiers: ["com.apple.Terminal"],
            fallbackSymbol: "terminal.fill",
            accent: Color(red: 0.36, green: 0.83, blue: 0.52),
            previewStyle: .terminal
        ),
        FixtureDefinition(
            title: "Focus mix",
            appName: "Music",
            bundleIdentifiers: ["com.apple.Music"],
            fallbackSymbol: "music.note",
            accent: Color(red: 0.92, green: 0.24, blue: 0.46),
            previewStyle: .music
        ),
        FixtureDefinition(
            title: "QA matrix.pdf",
            appName: "Preview",
            bundleIdentifiers: ["com.apple.Preview"],
            fallbackSymbol: "doc.text.image.fill",
            accent: Color(red: 0.44, green: 0.61, blue: 0.96),
            previewStyle: .document
        ),
    ]

    static func makeItems() throws -> [SwitcherItem] {
        try definitions.enumerated().map { index, definition in
            let identity = SwitcherHistoryIdentity.appWindow(
                pid: Int32(1000 + index),
                windowID: UInt32(5000 + index)
            )

            return SwitcherItem(
                title: definition.title,
                subtitle: definition.appName,
                icon: try applicationIcon(for: definition),
                previewImage: try previewImage(for: definition),
                previewCacheKey: "showcase-\(index)",
                historyIdentity: identity,
                sourceAppIdentifier: definition.bundleIdentifiers.first,
                kind: .appWindow,
                dedupeKey: identity.stableKey,
                activate: {}
            )
        }
    }

    private static func applicationIcon(for definition: FixtureDefinition) throws -> NSImage {
        for bundleIdentifier in definition.bundleIdentifiers {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
                let icon = NSWorkspace.shared.icon(forFile: url.path)
                icon.size = NSSize(width: 96, height: 96)
                return icon
            }
        }

        let view = ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [definition.accent.opacity(0.95), definition.accent.opacity(0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: definition.fallbackSymbol)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: 96, height: 96)

        return try renderImage(view, size: CGSize(width: 96, height: 96))
    }

    private static func previewImage(for definition: FixtureDefinition) throws -> NSImage {
        try renderImage(
            FixtureWindowPreview(definition: definition),
            size: CGSize(width: 960, height: 600)
        )
    }

    private static func renderImage<Content: View>(
        _ content: Content,
        size: CGSize
    ) throws -> NSImage {
        let renderer = ImageRenderer(
            content: content
                .frame(width: size.width, height: size.height)
                .environment(\.colorScheme, .dark)
        )
        renderer.scale = 1
        renderer.isOpaque = true

        guard let image = renderer.nsImage else {
            throw ShowcaseRendererError.renderFailed("Could not render fixture image")
        }
        return image
    }
}

private struct FixtureWindowPreview: View {
    let definition: ShowcaseFixtureFactory.FixtureDefinition

    var body: some View {
        ZStack {
            Color(red: 0.055, green: 0.064, blue: 0.085)
            VStack(spacing: 0) {
                titleBar
                Divider().overlay(Color.white.opacity(0.08))
                content
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private var titleBar: some View {
        HStack(spacing: 11) {
            HStack(spacing: 8) {
                Circle().fill(Color(red: 1.0, green: 0.36, blue: 0.31))
                Circle().fill(Color(red: 1.0, green: 0.74, blue: 0.25))
                Circle().fill(Color(red: 0.28, green: 0.79, blue: 0.35))
            }
            .frame(width: 62)

            Text(definition.title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.82))
                .lineLimit(1)

            Spacer()

            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.07))
                .frame(width: 132, height: 24)
                .overlay(
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                        Capsule().fill(Color.white.opacity(0.14)).frame(width: 72, height: 6)
                    }
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.36))
                )
        }
        .padding(.horizontal, 18)
        .frame(height: 48)
        .background(Color.white.opacity(0.035))
    }

    @ViewBuilder
    private var content: some View {
        switch definition.previewStyle {
        case .browser:
            browserContent
        case .code:
            codeContent
        case .mail:
            mailContent
        case .notes:
            notesContent
        case .calendar:
            calendarContent
        case .terminal:
            terminalContent
        case .music:
            musicContent
        case .document:
            documentContent
        }
    }

    private var browserContent: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 15) {
                fixtureLabel("Favorites", width: 76)
                fixtureLabel("Reading List", width: 104)
                fixtureLabel("Downloads", width: 90)
                Divider().overlay(Color.white.opacity(0.08))
                fixtureLabel("CmdTab", width: 64, accent: true)
                fixtureLabel("Documentation", width: 118)
                Spacer()
            }
            .padding(22)
            .frame(width: 190, alignment: .topLeading)
            .background(Color.white.opacity(0.025))

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("CmdTab release readiness")
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("21 checks")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(definition.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(definition.accent.opacity(0.12), in: Capsule())
                }

                HStack(spacing: 14) {
                    ForEach(0..<3, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(index == 0 ? definition.accent.opacity(0.18) : Color.white.opacity(0.045))
                            .frame(height: 104)
                            .overlay(alignment: .topLeading) {
                                VStack(alignment: .leading, spacing: 10) {
                                    Circle()
                                        .fill(index == 0 ? definition.accent : Color.white.opacity(0.18))
                                        .frame(width: 24, height: 24)
                                    Capsule().fill(Color.white.opacity(0.50)).frame(width: 90, height: 8)
                                    Capsule().fill(Color.white.opacity(0.18)).frame(width: 130, height: 7)
                                }
                                .padding(16)
                            }
                    }
                }

                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.035))
                    .overlay {
                        VStack(spacing: 0) {
                            ForEach(0..<4, id: \.self) { row in
                                HStack(spacing: 12) {
                                    Image(systemName: row < 3 ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(row < 3 ? definition.accent : Color.white.opacity(0.22))
                                    Capsule().fill(Color.white.opacity(row < 3 ? 0.42 : 0.20)).frame(height: 8)
                                    Spacer()
                                    Capsule().fill(Color.white.opacity(0.12)).frame(width: 56, height: 7)
                                }
                                .padding(.horizontal, 18)
                                .frame(height: 48)
                                if row < 3 { Divider().overlay(Color.white.opacity(0.055)) }
                            }
                        }
                    }
                Spacer()
            }
            .padding(26)
        }
    }

    private var codeContent: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 13) {
                fixtureLabel("CmdTab", width: 66, accent: true)
                fixtureLabel("Sources", width: 76)
                fixtureLabel("SwitcherView.swift", width: 132)
                fixtureLabel("ClassicGridView.swift", width: 148)
                fixtureLabel("Tests", width: 58)
                Spacer()
            }
            .padding(20)
            .frame(width: 210, alignment: .topLeading)
            .background(Color(red: 0.04, green: 0.05, blue: 0.07))

            VStack(spacing: 0) {
                HStack {
                    Text("SwitcherView.swift")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.72))
                    Spacer()
                    Text("Swift")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(definition.accent)
                }
                .padding(.horizontal, 18)
                .frame(height: 38)
                .background(Color.white.opacity(0.025))

                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .trailing, spacing: 12) {
                        ForEach(1..<18, id: \.self) { line in
                            Text("\(line)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(Color.white.opacity(0.20))
                        }
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        codeLine([52, 92, 160], highlighted: true)
                        codeLine([74, 128])
                        codeLine([38, 86, 112])
                        codeLine([92, 54])
                        codeLine([120, 168], highlighted: true)
                        codeLine([56, 132, 64])
                        codeLine([76, 214])
                        codeLine([44, 98, 128])
                        codeLine([152, 74], highlighted: true)
                        codeLine([62, 186])
                        codeLine([118, 96, 52])
                        codeLine([84, 142])
                        codeLine([46, 96, 164])
                        codeLine([136, 88], highlighted: true)
                        codeLine([72, 196])
                        codeLine([108, 66, 92])
                        codeLine([48])
                    }
                    Spacer()
                }
                .padding(18)
                .background(Color(red: 0.045, green: 0.052, blue: 0.072))
            }
        }
    }

    private var mailContent: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                fixtureLabel("Inbox", width: 54, accent: true)
                fixtureLabel("Flagged", width: 62)
                fixtureLabel("Sent", width: 42)
                fixtureLabel("Archive", width: 64)
                Spacer()
            }
            .padding(20)
            .frame(width: 158, alignment: .topLeading)
            .background(Color.white.opacity(0.025))

            VStack(spacing: 0) {
                ForEach(0..<6, id: \.self) { row in
                    HStack(alignment: .top, spacing: 11) {
                        Circle()
                            .fill(row == 1 ? definition.accent : Color.white.opacity(0.12))
                            .frame(width: 28, height: 28)
                        VStack(alignment: .leading, spacing: 7) {
                            HStack {
                                Capsule().fill(Color.white.opacity(row == 1 ? 0.70 : 0.35)).frame(width: 92, height: 8)
                                Spacer()
                                Capsule().fill(Color.white.opacity(0.12)).frame(width: 34, height: 6)
                            }
                            Capsule().fill(Color.white.opacity(row == 1 ? 0.48 : 0.22)).frame(width: row == 1 ? 150 : 118, height: 7)
                            Capsule().fill(Color.white.opacity(0.12)).frame(height: 6)
                        }
                    }
                    .padding(14)
                    .background(row == 1 ? definition.accent.opacity(0.10) : Color.clear)
                    if row < 5 { Divider().overlay(Color.white.opacity(0.055)) }
                }
            }
            .frame(width: 290)

            VStack(alignment: .leading, spacing: 18) {
                Text("Beta feedback")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                HStack {
                    Circle().fill(definition.accent).frame(width: 34, height: 34)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Product tester")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.82))
                        Capsule().fill(Color.white.opacity(0.18)).frame(width: 124, height: 6)
                    }
                }
                fixtureParagraph(widths: [310, 344, 298, 326, 240])
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(definition.accent.opacity(0.11))
                    .frame(height: 116)
                    .overlay {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Exact-window ordering felt predictable")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.86))
                            fixtureParagraph(widths: [260, 304, 210])
                        }
                        .padding(18)
                    }
                Spacer()
            }
            .padding(26)
        }
    }

    private var notesContent: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                fixtureLabel("All iCloud", width: 86)
                fixtureLabel("Notes", width: 52, accent: true)
                fixtureLabel("Recently Deleted", width: 122)
                Spacer()
            }
            .padding(22)
            .frame(width: 185, alignment: .topLeading)
            .background(Color.white.opacity(0.025))

            VStack(alignment: .leading, spacing: 18) {
                Text("Launch checklist")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Today, 10:30")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.35))
                VStack(alignment: .leading, spacing: 15) {
                    checklistRow("Verify exact-window MRU", checked: true)
                    checklistRow("Capture real product showcase", checked: true)
                    checklistRow("Run signed-app acceptance", checked: false)
                    checklistRow("Submit release for notarization", checked: false)
                    checklistRow("Publish trial download", checked: false)
                }
                .padding(.top, 4)
                Spacer()
            }
            .padding(34)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(Color(red: 0.11, green: 0.10, blue: 0.07))
        }
    }

    private var calendarContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text("July 2026")
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                    Image(systemName: "chevron.right")
                    Text("Today")
                }
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.55))
            }
            .padding(22)

            HStack(spacing: 0) {
                ForEach(["Mon", "Tue", "Wed", "Thu", "Fri"], id: \.self) { day in
                    Text(day)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.36))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 10)

            HStack(spacing: 0) {
                ForEach(0..<5, id: \.self) { column in
                    VStack(spacing: 0) {
                        Text("\(20 + column)")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(column == 1 ? definition.accent : Color.white.opacity(0.58))
                            .padding(.top, 12)
                        if column == 1 {
                            eventCard("Release review", color: definition.accent)
                            eventCard("Test matrix", color: Color(red: 0.42, green: 0.63, blue: 0.96))
                        } else if column == 2 {
                            eventCard("Website QA", color: Color(red: 0.48, green: 0.77, blue: 0.54))
                        } else if column == 4 {
                            eventCard("Launch notes", color: Color(red: 0.74, green: 0.52, blue: 0.93))
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .trailing) {
                        if column < 4 { Divider().overlay(Color.white.opacity(0.055)) }
                    }
                }
            }
            .overlay(alignment: .top) { Divider().overlay(Color.white.opacity(0.055)) }
        }
    }

    private var terminalContent: some View {
        VStack(alignment: .leading, spacing: 11) {
            terminalLine("$ swift test --scratch-path /tmp/CmdTab-test", color: Color.white.opacity(0.70))
            terminalLine("Building for debugging…", color: definition.accent)
            terminalLine("[18/18] Linking CmdTabPackageTests", color: Color.white.opacity(0.42))
            terminalLine("Test Suite 'All tests' started", color: Color.white.opacity(0.62))
            terminalLine("✓ StrictMRUAndCompletenessRegressionTests", color: definition.accent)
            terminalLine("✓ PaletteSearchTests", color: definition.accent)
            terminalLine("✓ SwitcherQuickActionShortcutTests", color: definition.accent)
            terminalLine("Executed 123 tests, with 0 failures", color: Color(red: 0.42, green: 0.88, blue: 0.57))
            terminalLine("$ _", color: Color.white.opacity(0.80))
            Spacer()
        }
        .padding(26)
        .background(Color(red: 0.025, green: 0.032, blue: 0.035))
    }

    private var musicContent: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                fixtureLabel("Listen Now", width: 92, accent: true)
                fixtureLabel("Browse", width: 62)
                fixtureLabel("Radio", width: 48)
                Divider().overlay(Color.white.opacity(0.08))
                fixtureLabel("Recently Added", width: 112)
                fixtureLabel("Playlists", width: 66)
                Spacer()
            }
            .padding(22)
            .frame(width: 190, alignment: .topLeading)
            .background(Color.white.opacity(0.025))

            VStack(alignment: .leading, spacing: 22) {
                Text("Focus mix")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                HStack(spacing: 22) {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [definition.accent, Color(red: 0.27, green: 0.15, blue: 0.52)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 190, height: 190)
                        .overlay {
                            Image(systemName: "waveform")
                                .font(.system(size: 72, weight: .medium))
                                .foregroundStyle(.white.opacity(0.84))
                        }
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Deep work")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("A calm instrumental set for focused building and review.")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.48))
                            .frame(maxWidth: 320, alignment: .leading)
                        HStack(spacing: 12) {
                            Circle().fill(definition.accent).frame(width: 46, height: 46)
                                .overlay(Image(systemName: "play.fill").foregroundStyle(.white))
                            Circle().fill(Color.white.opacity(0.08)).frame(width: 40, height: 40)
                                .overlay(Image(systemName: "shuffle").foregroundStyle(Color.white.opacity(0.62)))
                        }
                    }
                }
                HStack(spacing: 10) {
                    Capsule().fill(definition.accent).frame(width: 240, height: 5)
                    Capsule().fill(Color.white.opacity(0.12)).frame(height: 5)
                }
                Spacer()
            }
            .padding(30)
        }
    }

    private var documentContent: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(1...5, id: \.self) { page in
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(page == 2 ? definition.accent.opacity(0.18) : Color.white.opacity(0.055))
                        .frame(width: 92, height: 68)
                        .overlay {
                            VStack(spacing: 6) {
                                Capsule().fill(Color.white.opacity(0.24)).frame(width: 50, height: 5)
                                Capsule().fill(Color.white.opacity(0.12)).frame(width: 64, height: 4)
                                Capsule().fill(Color.white.opacity(0.12)).frame(width: 58, height: 4)
                            }
                        }
                }
                Spacer()
            }
            .padding(18)
            .frame(width: 132)
            .background(Color.white.opacity(0.025))

            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(red: 0.93, green: 0.94, blue: 0.96))
                .frame(width: 560, height: 470)
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("CmdTab QA matrix")
                            .font(.system(size: 27, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 0.11, green: 0.14, blue: 0.20))
                        Text("Membership, exact-window ordering, activation, permissions, Spaces, displays, and release checks")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Color(red: 0.32, green: 0.36, blue: 0.42))
                        VStack(spacing: 0) {
                            ForEach(0..<7, id: \.self) { row in
                                HStack(spacing: 12) {
                                    Text(String(format: "T-%03d", row + 1))
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(Color(red: 0.24, green: 0.30, blue: 0.42))
                                        .frame(width: 50, alignment: .leading)
                                    Capsule().fill(Color.black.opacity(0.16)).frame(height: 6)
                                    Text(row < 5 ? "PASS" : "MANUAL")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundStyle(row < 5 ? Color.green : Color.orange)
                                        .frame(width: 56, alignment: .trailing)
                                }
                                .padding(.horizontal, 12)
                                .frame(height: 34)
                                if row < 6 { Divider().overlay(Color.black.opacity(0.08)) }
                            }
                        }
                        .background(Color.white.opacity(0.74), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .padding(36)
                }
                .shadow(color: .black.opacity(0.24), radius: 26, x: 0, y: 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(red: 0.16, green: 0.17, blue: 0.20))
        }
    }

    private func fixtureLabel(
        _ text: String,
        width: CGFloat,
        accent: Bool = false
    ) -> some View {
        HStack(spacing: 9) {
            Circle()
                .fill(accent ? definition.accent : Color.white.opacity(0.12))
                .frame(width: 9, height: 9)
            Text(text)
                .font(.system(size: 12, weight: accent ? .semibold : .regular, design: .rounded))
                .foregroundStyle(Color.white.opacity(accent ? 0.86 : 0.46))
                .frame(width: width, alignment: .leading)
        }
    }

    private func codeLine(_ widths: [CGFloat], highlighted: Bool = false) -> some View {
        HStack(spacing: 7) {
            ForEach(Array(widths.enumerated()), id: \.offset) { index, width in
                Capsule()
                    .fill(
                        index == 0 && highlighted
                            ? definition.accent.opacity(0.86)
                            : Color.white.opacity(index == 0 ? 0.42 : 0.20)
                    )
                    .frame(width: width, height: 7)
            }
        }
        .frame(height: 8)
    }

    private func fixtureParagraph(widths: [CGFloat]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(widths.enumerated()), id: \.offset) { _, width in
                Capsule().fill(Color.white.opacity(0.16)).frame(width: width, height: 7)
            }
        }
    }

    private func checklistRow(_ title: String, checked: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(checked ? definition.accent : Color.white.opacity(0.24))
            Text(title)
                .font(.system(size: 15, weight: checked ? .semibold : .regular, design: .rounded))
                .foregroundStyle(Color.white.opacity(checked ? 0.82 : 0.56))
        }
    }

    private func eventCard(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(color.opacity(0.58), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .padding(.horizontal, 7)
            .padding(.top, 10)
    }

    private func terminalLine(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 16, weight: .regular, design: .monospaced))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}