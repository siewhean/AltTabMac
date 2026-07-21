import AppKit

if CommandLine.arguments.dropFirst().contains("--request-screen-recording") {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    app.activate(ignoringOtherApps: true)
    let granted = PermissionDiagnostics.requestScreenRecordingAccess()
    let result = granted ? "granted\n" : "not-granted\n"
    FileHandle.standardOutput.write(Data(result.utf8))
    exit(granted ? EXIT_SUCCESS : EXIT_FAILURE)
}

if CommandLine.arguments.dropFirst().contains("--diagnostics-json") {
    do {
        var output = try DiagnosticSnapshot.encodedCurrentSnapshot()
        output.append(0x0A)
        FileHandle.standardOutput.write(output)
        exit(EXIT_SUCCESS)
    } catch {
        FileHandle.standardError.write(Data("Failed to encode diagnostics: \(error)\n".utf8))
        exit(EXIT_FAILURE)
    }
}

if let validationFlagIndex = CommandLine.arguments.firstIndex(of: "--validate-runtime-qa") {
    let remainingArguments = Array(CommandLine.arguments.dropFirst(validationFlagIndex + 1))
    guard let inputPath = remainingArguments.first else {
        FileHandle.standardError.write(Data("Missing runtime QA JSONL path.\n".utf8))
        exit(EXIT_FAILURE)
    }

    do {
        let configuration = try RuntimeQAEvidenceValidator.configuration(
            from: Array(remainingArguments.dropFirst())
        )
        let records = try RuntimeQAEvidenceValidator.loadRecords(atPath: inputPath)
        let summary = RuntimeQAEvidenceValidator.validate(
            records: records,
            configuration: configuration
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        var output = try encoder.encode(summary)
        output.append(0x0A)
        FileHandle.standardOutput.write(output)
        exit(summary.passed ? EXIT_SUCCESS : EXIT_FAILURE)
    } catch {
        FileHandle.standardError.write(Data("Runtime QA validation failed: \(error)\n".utf8))
        exit(EXIT_FAILURE)
    }
}

// SPM executable entry point. AppKit owns the process main thread.
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
