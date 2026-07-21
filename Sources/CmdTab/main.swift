import AppKit

let arguments = CommandLine.arguments

if let showcaseFlagIndex = arguments.firstIndex(of: "--render-showcase") {
    guard showcaseFlagIndex + 1 < arguments.count else {
        fputs("Usage: CmdTab --render-showcase <output-directory>\n", stderr)
        exit(EXIT_FAILURE)
    }

    let outputURL = URL(fileURLWithPath: arguments[showcaseFlagIndex + 1], isDirectory: true)
    let app = NSApplication.shared
    app.setActivationPolicy(.prohibited)

    do {
        try MainActor.assumeIsolated {
            try ShowcaseRenderer.render(to: outputURL)
        }
        exit(EXIT_SUCCESS)
    } catch {
        fputs("\(error)\n", stderr)
        exit(EXIT_FAILURE)
    }
}

// SPM executable entry point
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
