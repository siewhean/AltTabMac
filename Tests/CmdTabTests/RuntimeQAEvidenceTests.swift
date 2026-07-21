import XCTest
@testable import CmdTab

final class RuntimeQAEvidenceTests: XCTestCase {
    func testRecorderIsInertWithoutExplicitOutputPath() {
        let recorder = RuntimeQAEvidenceRecorder(outputPath: nil)
        XCTAssertFalse(recorder.isEnabled)
        XCTAssertNil(recorder.prepareEventTapCallback(sessionID: nil))
        recorder.flushForTesting()
    }

    func testRecorderWritesPrivatePrivacySafeJSONL() throws {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("cmdtab-runtime-qa-\(UUID().uuidString).jsonl")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        let recorder = RuntimeQAEvidenceRecorder(outputPath: outputURL.path)
        recorder.emit(RuntimeQARecord(
            event: "firstFrameCommitted",
            sessionID: "session-1",
            totalItems: 3,
            cachedPreviewCount: 3,
            duplicateCount: 0,
            maximumWindowsPerApplication: 2,
            strictMRUOrderValid: true
        ))
        recorder.flushForTesting()

        let attributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
        XCTAssertEqual(attributes[.posixPermissions] as? NSNumber, NSNumber(value: 0o600))
        let data = try Data(contentsOf: outputURL)
        let decoded = try JSONDecoder().decode(
            RuntimeQARecord.self,
            from: Data(try XCTUnwrap(String(data: data, encoding: .utf8)).trimmingCharacters(in: .whitespacesAndNewlines).utf8)
        )
        XCTAssertEqual(decoded.event, "firstFrameCommitted")

        let text = try XCTUnwrap(String(data: data, encoding: .utf8))
        for forbiddenKey in ["title", "pid", "windowID", "bundleID", "image"] {
            XCTAssertFalse(text.contains("\"\(forbiddenKey)\""))
        }
    }

    func testCallbackSampleIncludesRecorderQueueSubmission() throws {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("cmdtab-runtime-qa-callback-\(UUID().uuidString).jsonl")
        defer { try? FileManager.default.removeItem(at: outputURL) }
        let recorder = RuntimeQAEvidenceRecorder(outputPath: outputURL.path)
        let startedAt = DispatchTime.now().uptimeNanoseconds
        let sample = try XCTUnwrap(recorder.prepareEventTapCallback(sessionID: "session-1"))
        sample.complete(startUptimeNanoseconds: startedAt)
        recorder.flushForTesting()

        let record = try XCTUnwrap(RuntimeQAEvidenceValidator.loadRecords(atPath: outputURL.path).first)
        XCTAssertEqual(record.event, "eventTapCallback")
        XCTAssertEqual(record.sessionID, "session-1")
        XCTAssertGreaterThanOrEqual(record.durationMilliseconds ?? -1, 0)
    }

    func testValidatorAcceptsCompleteWarmColdAndCycleEvidence() {
        let records = completeEvidence()
        var configuration = RuntimeQAValidationConfiguration()
        configuration.requiredWarmSessions = 1
        configuration.requiredColdSessions = 1
        configuration.requiredExactWindowActivations = 1
        configuration.requiredForwardSteps = 1
        configuration.requiredReverseSteps = 1

        let summary = RuntimeQAEvidenceValidator.validate(
            records: records,
            configuration: configuration
        )

        XCTAssertTrue(summary.passed, summary.failures.joined(separator: ", "))
        XCTAssertEqual(summary.warmSessions, 1)
        XCTAssertEqual(summary.coldSessions, 1)
        XCTAssertEqual(summary.multiWindowSessions, 2)
        XCTAssertEqual(summary.callbackSamples, 2)
        XCTAssertEqual(summary.warmPostDeadlineP95Milliseconds ?? -1, 20, accuracy: 0.001)
        XCTAssertEqual(summary.warmTotalP95Milliseconds ?? -1, 120, accuracy: 0.001)
    }

    func testValidatorRejectsDuplicateAndUnfinishedSessionsWithoutCrashing() {
        let duplicatedStart = RuntimeQARecord(
            event: "sessionStarted",
            recordedAtUptime: 1,
            sessionID: "duplicate",
            eventUptime: 1,
            revealDeadlineUptime: 1.1
        )
        var configuration = RuntimeQAValidationConfiguration()
        configuration.requiredWarmSessions = 0
        configuration.requiredColdSessions = 0
        configuration.requiredExactWindowActivations = 0
        configuration.requiredForwardSteps = 0
        configuration.requiredReverseSteps = 0

        let summary = RuntimeQAEvidenceValidator.validate(
            records: [
                duplicatedStart,
                duplicatedStart,
                RuntimeQARecord(event: "eventTapCallback", durationMilliseconds: 1)
            ],
            configuration: configuration
        )

        XCTAssertFalse(summary.passed)
        XCTAssertTrue(summary.failures.contains("duplicate sessionStarted record"))
        XCTAssertTrue(summary.failures.contains("unfinished sessions 1"))
    }

    func testValidatorRejectsZeroPreviewFrameAsWarmEvidence() {
        var configuration = RuntimeQAValidationConfiguration()
        configuration.requiredWarmSessions = 1
        configuration.requiredColdSessions = 0
        configuration.requiredExactWindowActivations = 0
        configuration.requiredForwardSteps = 0
        configuration.requiredReverseSteps = 0
        let records = [
            RuntimeQARecord(
                event: "sessionStarted",
                recordedAtUptime: 1,
                sessionID: "cold",
                eventUptime: 1,
                revealDeadlineUptime: 1.1
            ),
            RuntimeQARecord(
                event: "firstFrameCommitted",
                recordedAtUptime: 1.12,
                sessionID: "cold",
                totalItems: 2,
                cachedPreviewCount: 0,
                duplicateCount: 0,
                maximumWindowsPerApplication: 2
            ),
            RuntimeQARecord(event: "sessionFinished", sessionID: "cold", success: false, verification: "cancelled"),
            RuntimeQARecord(event: "eventTapCallback", durationMilliseconds: 1)
        ]

        let summary = RuntimeQAEvidenceValidator.validate(records: records, configuration: configuration)
        XCTAssertFalse(summary.passed)
        XCTAssertEqual(summary.warmSessions, 0)
        XCTAssertTrue(summary.failures.contains("warm sessions 0/1"))
    }

    func testValidatorRejectsDuplicateLifecycleEvidenceInsteadOfInflatingCounts() {
        var records = completeEvidence()
        records.append(records[2])
        records.append(records[5])
        var configuration = RuntimeQAValidationConfiguration()
        configuration.requiredWarmSessions = 1
        configuration.requiredColdSessions = 1
        configuration.requiredExactWindowActivations = 1
        configuration.requiredForwardSteps = 1
        configuration.requiredReverseSteps = 1

        let summary = RuntimeQAEvidenceValidator.validate(records: records, configuration: configuration)

        XCTAssertFalse(summary.passed)
        XCTAssertTrue(summary.failures.contains("session has 2 firstFrameCommitted records; expected 1"))
        XCTAssertTrue(summary.failures.contains("session has 2 activationResult records; expected 1"))
        XCTAssertEqual(summary.exactWindowActivations, 2)
    }

    func testLoaderRejectsMalformedJSONLWithLineNumber() throws {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("cmdtab-runtime-qa-invalid-\(UUID().uuidString).jsonl")
        defer { try? FileManager.default.removeItem(at: outputURL) }
        try "{}\nnot-json\n".write(to: outputURL, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try RuntimeQAEvidenceValidator.loadRecords(atPath: outputURL.path)) { error in
            XCTAssertEqual(error as? RuntimeQAEvidenceValidator.ValidationError, .invalidRecord(line: 1))
        }
    }

    private func completeEvidence() -> [RuntimeQARecord] {
        [
            RuntimeQARecord(event: "sessionStarted", recordedAtUptime: 10, sessionID: "warm", eventUptime: 10, revealDeadlineUptime: 10.1),
            RuntimeQARecord(event: "panelOrdered", recordedAtUptime: 10.11, sessionID: "warm", totalItems: 3, cachedPreviewCount: 3, duplicateCount: 0, maximumWindowsPerApplication: 2),
            RuntimeQARecord(event: "firstFrameCommitted", recordedAtUptime: 10.12, sessionID: "warm", totalItems: 3, cachedPreviewCount: 3, duplicateCount: 0, maximumWindowsPerApplication: 2, strictMRUOrderValid: true),
            RuntimeQARecord(event: "selectionStep", sessionID: "warm", totalItems: 3, fromIndex: 0, toIndex: 1, expectedIndex: 1, direction: "forward", success: true),
            RuntimeQARecord(event: "selectionStep", sessionID: "warm", totalItems: 3, fromIndex: 1, toIndex: 0, expectedIndex: 0, direction: "reverse", success: true),
            RuntimeQARecord(event: "activationResult", sessionID: "warm", success: true, verification: "exactWindow"),
            RuntimeQARecord(event: "sessionFinished", sessionID: "warm", success: true, verification: "exactWindow"),
            RuntimeQARecord(event: "sessionStarted", recordedAtUptime: 20, sessionID: "cold", eventUptime: 20, revealDeadlineUptime: 20.1, cold: true),
            RuntimeQARecord(event: "panelOrdered", recordedAtUptime: 20.11, sessionID: "cold", totalItems: 3, cachedPreviewCount: 0, duplicateCount: 0, maximumWindowsPerApplication: 2),
            RuntimeQARecord(event: "firstFrameCommitted", recordedAtUptime: 20.12, sessionID: "cold", totalItems: 3, cachedPreviewCount: 0, duplicateCount: 0, maximumWindowsPerApplication: 2, strictMRUOrderValid: true),
            RuntimeQARecord(event: "firstPopulatedFrame", recordedAtUptime: 20.2, sessionID: "cold", totalItems: 3, successfulPreviewCount: 3, success: true),
            RuntimeQARecord(event: "captureRefreshFinished", recordedAtUptime: 20.19, sessionID: "cold", operationID: "capture-cold", totalItems: 3, requestedPreviewCount: 3, successfulPreviewCount: 3, success: true),
            RuntimeQARecord(event: "activationResult", sessionID: "cold", success: true, verification: "exactWindow"),
            RuntimeQARecord(event: "sessionFinished", sessionID: "cold", success: true, verification: "exactWindow"),
            RuntimeQARecord(event: "eventTapCallback", sessionID: "warm", durationMilliseconds: 1),
            RuntimeQARecord(event: "eventTapCallback", sessionID: "cold", durationMilliseconds: 2)
        ]
    }
}
