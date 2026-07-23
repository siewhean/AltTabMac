import CoreFoundation
import Foundation

enum StageManagerCapabilityPolicy {
    static let inferenceReason = "Stage Manager active/hidden-set state is inferred because macOS exposes no supported stable set identifier."

    static func isEnabled() -> Bool {
        guard #available(macOS 13.0, *) else { return false }
        let value = CFPreferencesCopyAppValue(
            "GloballyEnabled" as CFString,
            "com.apple.WindowManager" as CFString
        )
        return (value as? NSNumber)?.boolValue ?? false
    }

    static func truthfulStatus(
        _ base: CapabilityStatus,
        stageManagerEnabled: Bool = isEnabled()
    ) -> CapabilityStatus {
        guard stageManagerEnabled else { return base }
        return base.addingLimitation(inferenceReason)
    }

    static func visibleLabel(for state: StageManagerWindowState) -> String? {
        switch state {
        case .activeSet: return "Inferred Active Set"
        case .hiddenSet: return "Inferred Hidden Set"
        case .disabled, .offCurrentSpace, .unknown: return nil
        }
    }
}

extension CapabilityStatus {
    func addingLimitation(_ limitation: String) -> CapabilityStatus {
        let normalized = limitation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return self }

        let combinedReason: String
        if let reason, !reason.isEmpty {
            combinedReason = reason.contains(normalized)
                ? reason
                : "\(reason) \(normalized)"
        } else {
            combinedReason = normalized
        }

        switch level {
        case .available, .degraded:
            return .degraded(combinedReason)
        case .unavailable:
            return .unavailable(combinedReason)
        case .failed:
            return .failed(combinedReason)
        }
    }
}
