import Foundation

struct RuntimeQARecord: Codable, Equatable {
    let schemaVersion: Int
    let event: String
    let recordedAtUptime: TimeInterval
    let sessionID: String?
    let operationID: String?
    let eventUptime: TimeInterval?
    let revealDeadlineUptime: TimeInterval?
    let durationMilliseconds: Double?
    let totalItems: Int?
    let cachedPreviewCount: Int?
    let requestedPreviewCount: Int?
    let successfulPreviewCount: Int?
    let duplicateCount: Int?
    let maximumWindowsPerApplication: Int?
    let fromIndex: Int?
    let toIndex: Int?
    let expectedIndex: Int?
    let direction: String?
    let cold: Bool?
    let success: Bool?
    let verification: String?
    let tapDisableCount: Int?
    let strictMRUOrderValid: Bool?

    init(
        event: String,
        recordedAtUptime: TimeInterval = ProcessInfo.processInfo.systemUptime,
        sessionID: String? = nil,
        operationID: String? = nil,
        eventUptime: TimeInterval? = nil,
        revealDeadlineUptime: TimeInterval? = nil,
        durationMilliseconds: Double? = nil,
        totalItems: Int? = nil,
        cachedPreviewCount: Int? = nil,
        requestedPreviewCount: Int? = nil,
        successfulPreviewCount: Int? = nil,
        duplicateCount: Int? = nil,
        maximumWindowsPerApplication: Int? = nil,
        fromIndex: Int? = nil,
        toIndex: Int? = nil,
        expectedIndex: Int? = nil,
        direction: String? = nil,
        cold: Bool? = nil,
        success: Bool? = nil,
        verification: String? = nil,
        tapDisableCount: Int? = nil,
        strictMRUOrderValid: Bool? = nil
    ) {
        self.schemaVersion = 1
        self.event = event
        self.recordedAtUptime = recordedAtUptime
        self.sessionID = sessionID
        self.operationID = operationID
        self.eventUptime = eventUptime
        self.revealDeadlineUptime = revealDeadlineUptime
        self.durationMilliseconds = durationMilliseconds
        self.totalItems = totalItems
        self.cachedPreviewCount = cachedPreviewCount
        self.requestedPreviewCount = requestedPreviewCount
        self.successfulPreviewCount = successfulPreviewCount
        self.duplicateCount = duplicateCount
        self.maximumWindowsPerApplication = maximumWindowsPerApplication
        self.fromIndex = fromIndex
        self.toIndex = toIndex
        self.expectedIndex = expectedIndex
        self.direction = direction
        self.cold = cold
        self.success = success
        self.verification = verification
        self.tapDisableCount = tapDisableCount
        self.strictMRUOrderValid = strictMRUOrderValid
    }
}

final class RuntimeQAEvidenceRecorder {
    final class PendingCallbackSample {
        private let condition = NSCondition()
        private var durationMilliseconds: Double?

        func complete(startUptimeNanoseconds: UInt64) {
            condition.lock()
            let elapsedNanoseconds = DispatchTime.now().uptimeNanoseconds - startUptimeNanoseconds
            durationMilliseconds = Double(elapsedNanoseconds) / 1_000_000
            condition.signal()
            condition.unlock()
        }

        fileprivate func waitForDuration() -> Double {
            condition.lock()
            while durationMilliseconds == nil {
                condition.wait()
            }
            let duration = durationMilliseconds ?? 0
            condition.unlock()
            return duration
        }
    }

    static let shared = RuntimeQAEvidenceRecorder(
        outputPath: ProcessInfo.processInfo.environment["CMDTAB_RUNTIME_QA_OUTPUT"]
    )

    private let outputURL: URL?
    private let writeQueue = DispatchQueue(label: "CmdTab.RuntimeQAEvidence")
    private let stateLock = NSLock()
    private var fileHandle: FileHandle?
    private var activeSessionID: String?
    private var tapDisableCount = 0
    private var captureSessionIDs: [String: String] = [:]
    private var coldStartArmed = false

    init(outputPath: String?) {
        if let outputPath, !outputPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            outputURL = URL(fileURLWithPath: outputPath).standardizedFileURL
        } else {
            outputURL = nil
        }
    }

    var isEnabled: Bool { outputURL != nil }

    func makeSessionID() -> String {
        UUID().uuidString.lowercased()
    }

    func beginSession(
        id: String,
        eventUptime: TimeInterval,
        revealDeadlineUptime: TimeInterval
    ) {
        guard isEnabled else { return }
        stateLock.lock()
        activeSessionID = id
        let cold = coldStartArmed
        coldStartArmed = false
        stateLock.unlock()
        emit(RuntimeQARecord(
            event: "sessionStarted",
            sessionID: id,
            eventUptime: eventUptime,
            revealDeadlineUptime: revealDeadlineUptime,
            cold: cold
        ))
    }

    func recordCacheReset() {
        guard isEnabled else { return }
        stateLock.lock()
        coldStartArmed = true
        stateLock.unlock()
        emit(RuntimeQARecord(event: "cacheReset", success: true))
    }

    func currentSessionID() -> String? {
        guard isEnabled else { return nil }
        stateLock.lock()
        let sessionID = activeSessionID
        stateLock.unlock()
        return sessionID
    }

    func finishSession(id: String?, success: Bool, verification: String) {
        guard isEnabled, let id else { return }
        stateLock.lock()
        guard activeSessionID == id else {
            stateLock.unlock()
            return
        }
        activeSessionID = nil
        stateLock.unlock()
        emit(RuntimeQARecord(
            event: "sessionFinished",
            sessionID: id,
            success: success,
            verification: verification
        ))
    }

    func prepareEventTapCallback(sessionID: String?) -> PendingCallbackSample? {
        guard isEnabled else { return nil }
        let sample = PendingCallbackSample()
        writeQueue.async { [weak self] in
            guard let self else { return }
            let duration = sample.waitForDuration()
            self.write(RuntimeQARecord(
                event: "eventTapCallback",
                sessionID: sessionID,
                durationMilliseconds: duration
            ))
        }
        return sample
    }

    func recordEventTapDisabled() {
        guard isEnabled else { return }
        stateLock.lock()
        tapDisableCount += 1
        let count = tapDisableCount
        stateLock.unlock()
        emit(RuntimeQARecord(
            event: "eventTapDisabled",
            sessionID: currentSessionID(),
            tapDisableCount: count
        ))
    }

    func beginCaptureRefresh(
        totalItems: Int,
        cachedPreviewCount: Int,
        requestedPreviewCount: Int
    ) -> String? {
        guard isEnabled else { return nil }
        let operationID = UUID().uuidString.lowercased()
        let sessionID = currentSessionID()
        if let sessionID {
            stateLock.lock()
            captureSessionIDs[operationID] = sessionID
            stateLock.unlock()
        }
        emit(RuntimeQARecord(
            event: "captureRefreshStarted",
            sessionID: sessionID,
            operationID: operationID,
            totalItems: totalItems,
            cachedPreviewCount: cachedPreviewCount,
            requestedPreviewCount: requestedPreviewCount,
            cold: cachedPreviewCount == 0
        ))
        return operationID
    }

    func finishCaptureRefresh(
        operationID: String?,
        totalItems: Int,
        requestedPreviewCount: Int,
        successfulPreviewCount: Int
    ) {
        guard isEnabled else { return }
        var sessionID: String?
        if let operationID {
            stateLock.lock()
            sessionID = captureSessionIDs.removeValue(forKey: operationID)
            stateLock.unlock()
        }
        emit(RuntimeQARecord(
            event: "captureRefreshFinished",
            sessionID: sessionID,
            operationID: operationID,
            totalItems: totalItems,
            requestedPreviewCount: requestedPreviewCount,
            successfulPreviewCount: successfulPreviewCount,
            success: requestedPreviewCount == 0 || successfulPreviewCount > 0
        ))
    }

    func emit(_ record: RuntimeQARecord) {
        guard outputURL != nil else { return }
        writeQueue.async { [weak self] in
            self?.write(record)
        }
    }

    func flushForTesting() {
        guard outputURL != nil else { return }
        writeQueue.sync {}
    }

    private func write(_ record: RuntimeQARecord) {
        guard let outputURL else { return }
        do {
            if fileHandle == nil {
                let parent = outputURL.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
                if !FileManager.default.fileExists(atPath: outputURL.path) {
                    FileManager.default.createFile(atPath: outputURL.path, contents: nil)
                }
                try FileManager.default.setAttributes(
                    [.posixPermissions: 0o600],
                    ofItemAtPath: outputURL.path
                )
                fileHandle = try FileHandle(forWritingTo: outputURL)
                try fileHandle?.seekToEnd()
            }

            var data = try JSONEncoder().encode(record)
            data.append(0x0A)
            try fileHandle?.write(contentsOf: data)
        } catch {
            // Runtime QA evidence must never disrupt switching behavior.
        }
    }
}

struct RuntimeQAValidationConfiguration: Equatable {
    var requiredWarmSessions = 100
    var requiredColdSessions = 20
    var requiredExactWindowActivations = 100
    var requiredForwardSteps = 200
    var requiredReverseSteps = 200
    var warmPostDeadlineP95Milliseconds = 50.0
    var warmPostDeadlineMaximumMilliseconds = 100.0
    var coldTotalP95Milliseconds = 250.0
    var callbackP95Milliseconds = 5.0
    var callbackMaximumExclusiveMilliseconds = 20.0
}

struct RuntimeQAValidationSummary: Codable, Equatable {
    let passed: Bool
    let failures: [String]
    let warmSessions: Int
    let coldSessions: Int
    let exactWindowActivations: Int
    let multiWindowSessions: Int
    let forwardSteps: Int
    let reverseSteps: Int
    let callbackSamples: Int
    let warmPostDeadlineP95Milliseconds: Double?
    let warmPostDeadlineMaximumMilliseconds: Double?
    let warmTotalP95Milliseconds: Double?
    let coldTotalP95Milliseconds: Double?
    let callbackP95Milliseconds: Double?
    let callbackMaximumMilliseconds: Double?
}

enum RuntimeQAEvidenceValidator {
    static func validate(
        records: [RuntimeQARecord],
        configuration: RuntimeQAValidationConfiguration = RuntimeQAValidationConfiguration()
    ) -> RuntimeQAValidationSummary {
        var starts: [String: RuntimeQARecord] = [:]
        var structuralFailures: [String] = []
        for record in records where record.event == "sessionStarted" {
            guard let sessionID = record.sessionID else {
                structuralFailures.append("sessionStarted is missing a session ID")
                continue
            }
            if starts.updateValue(record, forKey: sessionID) != nil {
                structuralFailures.append("duplicate sessionStarted record")
            }
        }
        let lifecycleEvents = [
            "panelOrdered",
            "firstFrameCommitted",
            "firstPopulatedFrame",
            "activationResult",
            "sessionFinished"
        ]
        var lifecycleCounts: [String: [String: Int]] = [:]
        for event in lifecycleEvents {
            for record in records where record.event == event {
                guard let sessionID = record.sessionID else {
                    structuralFailures.append("\(event) is missing a session ID")
                    continue
                }
                lifecycleCounts[event, default: [:]][sessionID, default: 0] += 1
            }
        }
        for sessionID in starts.keys {
            for event in ["panelOrdered", "firstFrameCommitted", "activationResult", "sessionFinished"] {
                let count = lifecycleCounts[event]?[sessionID] ?? 0
                if count != 1 {
                    structuralFailures.append("session has \(count) \(event) records; expected 1")
                }
            }
            let populatedFrameCount = lifecycleCounts["firstPopulatedFrame"]?[sessionID] ?? 0
            if populatedFrameCount > 1 {
                structuralFailures.append("session has duplicate firstPopulatedFrame records")
            }
        }
        for event in lifecycleEvents {
            let unknownSessionCount = lifecycleCounts[event]?.keys.filter { starts[$0] == nil }.count ?? 0
            if unknownSessionCount > 0 {
                structuralFailures.append("\(event) references \(unknownSessionCount) unknown sessions")
            }
        }
        let firstFrames = records.filter { $0.event == "firstFrameCommitted" }
        let firstPopulatedFrames = records.filter { $0.event == "firstPopulatedFrame" }

        var warmPostDeadline: [Double] = []
        var warmTotal: [Double] = []
        var coldSessionIDs = Set<String>()
        var coldTotal: [Double]

        for frame in firstFrames {
            guard let sessionID = frame.sessionID,
                  let start = starts[sessionID],
                  let eventUptime = start.eventUptime,
                  let revealDeadline = start.revealDeadlineUptime else { continue }

            if (frame.cachedPreviewCount ?? 0) > 0 {
                warmPostDeadline.append(max(0, frame.recordedAtUptime - revealDeadline) * 1_000)
                warmTotal.append(max(0, frame.recordedAtUptime - eventUptime) * 1_000)
            } else if start.cold == true {
                coldSessionIDs.insert(sessionID)
            }
        }

        let successfulCaptureSessionIDs = Set(records.compactMap { record -> String? in
            guard record.event == "captureRefreshFinished",
                  record.success == true,
                  (record.successfulPreviewCount ?? 0) > 0 else { return nil }
            return record.sessionID
        })
        coldTotal = firstPopulatedFrames.compactMap { frame -> Double? in
            guard let sessionID = frame.sessionID,
                  coldSessionIDs.contains(sessionID),
                  successfulCaptureSessionIDs.contains(sessionID),
                  (frame.successfulPreviewCount ?? 0) > 0,
                  let eventUptime = starts[sessionID]?.eventUptime else { return nil }
            return max(0, frame.recordedAtUptime - eventUptime) * 1_000
        }

        let callbackDurations = records.compactMap { record in
            record.event == "eventTapCallback" && record.sessionID != nil
                ? record.durationMilliseconds
                : nil
        }
        let multiWindowSessionCount = firstFrames.filter {
            ($0.maximumWindowsPerApplication ?? 0) >= 2
        }.count
        let multiWindowSessionIDs = Set(firstFrames.compactMap { record -> String? in
            guard (record.maximumWindowsPerApplication ?? 0) >= 2 else { return nil }
            return record.sessionID
        })
        let exactActivationSessionIDs = Set(records.compactMap { record -> String? in
            guard record.event == "activationResult",
                  record.success == true,
                  record.verification == "exactWindow",
                  let sessionID = record.sessionID,
                  multiWindowSessionIDs.contains(sessionID) else { return nil }
            return sessionID
        })
        let activationCount = exactActivationSessionIDs.count
        var stepsBySession: [String: [RuntimeQARecord]] = [:]
        for record in records where record.event == "selectionStep" {
            guard let sessionID = record.sessionID, starts[sessionID] != nil else {
                structuralFailures.append("selectionStep references a missing or unknown session")
                continue
            }
            stepsBySession[sessionID, default: []].append(record)
        }
        let completedSuccessfulSessionIDs = Set(records.compactMap { record -> String? in
            guard record.event == "sessionFinished", record.success == true else { return nil }
            return record.sessionID
        })
        let cycleCandidates = stepsBySession.compactMap { sessionID, steps -> (Int, Int)? in
            guard completedSuccessfulSessionIDs.contains(sessionID),
                  multiWindowSessionIDs.contains(sessionID),
                  steps.allSatisfy({ $0.success == true }) else { return nil }
            let forward = steps.filter { $0.direction == "forward" }.count
            let reverse = steps.filter { $0.direction == "reverse" }.count
            return (forward, reverse)
        }
        let qualifyingCycle = cycleCandidates
            .filter {
                $0.0 >= configuration.requiredForwardSteps &&
                    $0.1 >= configuration.requiredReverseSteps
            }
            .max { ($0.0 + $0.1) < ($1.0 + $1.1) }
        let validForwardSteps = qualifyingCycle?.0 ?? 0
        let validReverseSteps = qualifyingCycle?.1 ?? 0

        var failures = structuralFailures
        let finishedSessionIDs = Set(records.compactMap { record in
            record.event == "sessionFinished" ? record.sessionID : nil
        })
        let unfinishedSessionCount = Set(starts.keys).subtracting(finishedSessionIDs).count
        require(unfinishedSessionCount == 0,
                "unfinished sessions \(unfinishedSessionCount)", into: &failures)
        require(warmPostDeadline.count >= configuration.requiredWarmSessions,
                "warm sessions \(warmPostDeadline.count)/\(configuration.requiredWarmSessions)", into: &failures)
        require(coldTotal.count >= configuration.requiredColdSessions,
                "cold sessions \(coldTotal.count)/\(configuration.requiredColdSessions)", into: &failures)
        require(activationCount >= configuration.requiredExactWindowActivations,
                "exact-window activations \(activationCount)/\(configuration.requiredExactWindowActivations)", into: &failures)
        require(multiWindowSessionCount >= configuration.requiredExactWindowActivations,
                "multi-window sessions \(multiWindowSessionCount)/\(configuration.requiredExactWindowActivations)", into: &failures)
        require(validForwardSteps >= configuration.requiredForwardSteps,
                "forward steps \(validForwardSteps)/\(configuration.requiredForwardSteps)", into: &failures)
        require(validReverseSteps >= configuration.requiredReverseSteps,
                "reverse steps \(validReverseSteps)/\(configuration.requiredReverseSteps)", into: &failures)
        require(!callbackDurations.isEmpty, "no event-tap callback samples", into: &failures)
        require(!records.contains(where: { $0.event == "eventTapDisabled" }),
                "event tap was disabled during the run", into: &failures)
        require(!records.contains(where: {
            $0.event == "captureRefreshFinished" &&
                $0.sessionID != nil &&
                ($0.requestedPreviewCount ?? 0) > 0 &&
                ($0.successfulPreviewCount ?? 0) == 0
        }), "a session capture refresh produced no previews", into: &failures)
        require(!records.contains(where: { ($0.duplicateCount ?? 0) > 0 }),
                "duplicate switcher items were observed", into: &failures)
        require(!records.contains(where: {
            $0.event == "firstFrameCommitted" && $0.strictMRUOrderValid != true
        }), "a switcher frame violated strict window MRU order", into: &failures)
        require(!records.contains(where: { $0.event == "selectionStep" && $0.success != true }),
                "an invalid selection step was observed", into: &failures)
        require(!records.contains(where: {
            $0.event == "activationResult" && ($0.success != true || $0.verification != "exactWindow")
        }), "an activation was not verified against the exact window", into: &failures)
        require(!records.contains(where: { $0.event == "sessionFinished" && $0.success != true }),
                "a runtime QA session did not finish successfully", into: &failures)

        let warmP95 = percentile95(warmPostDeadline)
        let warmMaximum = warmPostDeadline.max()
        let coldP95 = percentile95(coldTotal)
        let callbackP95 = percentile95(callbackDurations)
        let callbackMaximum = callbackDurations.max()
        require(warmP95.map { $0 <= configuration.warmPostDeadlineP95Milliseconds } ?? false,
                "warm post-deadline p95 exceeds \(configuration.warmPostDeadlineP95Milliseconds) ms", into: &failures)
        require(warmMaximum.map { $0 <= configuration.warmPostDeadlineMaximumMilliseconds } ?? false,
                "warm post-deadline maximum exceeds \(configuration.warmPostDeadlineMaximumMilliseconds) ms", into: &failures)
        require(coldP95.map { $0 <= configuration.coldTotalP95Milliseconds } ?? false,
                "cold total p95 exceeds \(configuration.coldTotalP95Milliseconds) ms", into: &failures)
        require(callbackP95.map { $0 <= configuration.callbackP95Milliseconds } ?? false,
                "event-tap callback p95 exceeds \(configuration.callbackP95Milliseconds) ms", into: &failures)
        require(callbackMaximum.map { $0 < configuration.callbackMaximumExclusiveMilliseconds } ?? false,
                "event-tap callback maximum must stay below \(configuration.callbackMaximumExclusiveMilliseconds) ms", into: &failures)

        return RuntimeQAValidationSummary(
            passed: failures.isEmpty,
            failures: failures,
            warmSessions: warmPostDeadline.count,
            coldSessions: coldTotal.count,
            exactWindowActivations: activationCount,
            multiWindowSessions: multiWindowSessionCount,
            forwardSteps: validForwardSteps,
            reverseSteps: validReverseSteps,
            callbackSamples: callbackDurations.count,
            warmPostDeadlineP95Milliseconds: warmP95,
            warmPostDeadlineMaximumMilliseconds: warmMaximum,
            warmTotalP95Milliseconds: percentile95(warmTotal),
            coldTotalP95Milliseconds: coldP95,
            callbackP95Milliseconds: callbackP95,
            callbackMaximumMilliseconds: callbackMaximum
        )
    }

    static func loadRecords(atPath path: String) throws -> [RuntimeQARecord] {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        guard let text = String(data: data, encoding: .utf8) else {
            throw ValidationError.invalidUTF8
        }
        return try text.split(whereSeparator: \.isNewline).enumerated().map { offset, line in
            do {
                return try JSONDecoder().decode(RuntimeQARecord.self, from: Data(line.utf8))
            } catch {
                throw ValidationError.invalidRecord(line: offset + 1)
            }
        }
    }

    static func configuration(from arguments: [String]) throws -> RuntimeQAValidationConfiguration {
        var configuration = RuntimeQAValidationConfiguration()
        var index = 0
        while index < arguments.count {
            let flag = arguments[index]
            guard index + 1 < arguments.count else { throw ValidationError.missingValue(flag) }
            let value = arguments[index + 1]
            switch flag {
            case "--warm-count": configuration.requiredWarmSessions = try integer(value, flag: flag)
            case "--cold-count": configuration.requiredColdSessions = try integer(value, flag: flag)
            case "--mru-cycles": configuration.requiredExactWindowActivations = try integer(value, flag: flag)
            case "--forward-steps": configuration.requiredForwardSteps = try integer(value, flag: flag)
            case "--reverse-steps": configuration.requiredReverseSteps = try integer(value, flag: flag)
            case "--warm-p95-ms": configuration.warmPostDeadlineP95Milliseconds = try number(value, flag: flag)
            case "--warm-max-ms": configuration.warmPostDeadlineMaximumMilliseconds = try number(value, flag: flag)
            case "--cold-p95-ms": configuration.coldTotalP95Milliseconds = try number(value, flag: flag)
            case "--callback-p95-ms": configuration.callbackP95Milliseconds = try number(value, flag: flag)
            case "--callback-max-ms": configuration.callbackMaximumExclusiveMilliseconds = try number(value, flag: flag)
            default: throw ValidationError.unknownFlag(flag)
            }
            index += 2
        }
        return configuration
    }

    enum ValidationError: Error, Equatable {
        case invalidUTF8
        case invalidRecord(line: Int)
        case missingValue(String)
        case invalidValue(flag: String, value: String)
        case unknownFlag(String)
    }

    private static func require(_ condition: Bool, _ message: String, into failures: inout [String]) {
        if !condition { failures.append(message) }
    }

    private static func percentile95(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let index = max(0, Int(ceil(Double(sorted.count) * 0.95)) - 1)
        return sorted[index]
    }

    private static func integer(_ value: String, flag: String) throws -> Int {
        guard let parsed = Int(value), parsed >= 0 else {
            throw ValidationError.invalidValue(flag: flag, value: value)
        }
        return parsed
    }

    private static func number(_ value: String, flag: String) throws -> Double {
        guard let parsed = Double(value), parsed >= 0 else {
            throw ValidationError.invalidValue(flag: flag, value: value)
        }
        return parsed
    }
}
