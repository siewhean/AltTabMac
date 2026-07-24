import Foundation

/// Production Hot Swap accepts only a side-matched Command+Option chord.
///
/// Earlier builds exposed modifier-only single- and double-tap modes. Those modes
/// are retained in `AlternateTriggerMode` solely so existing preferences continue
/// to decode, but they are normalized to `.disabled` and can never activate a
/// switch. This fail-closed policy prevents two Command taps separated by any
/// amount of time from unexpectedly changing windows.
extension AlternateTriggerMode {
    static let productionHotSwapModes: [AlternateTriggerMode] = [
        .disabled,
        .leftOptionDoubleTap,
        .rightOptionDoubleTap,
    ]

    var productionSafeMode: AlternateTriggerMode {
        switch self {
        case .disabled, .leftOptionDoubleTap, .rightOptionDoubleTap:
            return self
        case .rightCommandTap,
             .rightCommandDoubleTap,
             .rightOptionTap,
             .leftCommandDoubleTap:
            return .disabled
        }
    }

    var isProductionSimultaneousChord: Bool {
        switch productionSafeMode {
        case .leftOptionDoubleTap, .rightOptionDoubleTap:
            return true
        case .disabled,
             .rightCommandTap,
             .rightCommandDoubleTap,
             .rightOptionTap,
             .leftCommandDoubleTap:
            return false
        }
    }
}
