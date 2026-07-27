import Foundation

/// Production Hot Swap supports two deliberate gesture families:
///
/// - a same-side Command double tap completed within 250 ms; and
/// - a same-side Command+Option chord whose key-downs arrive within 160 ms.
///
/// Modifier-only single taps remain legacy decode-only values and normalize to
/// `.disabled`, so pressing Option once can never switch windows.
extension AlternateTriggerMode {
    static let productionHotSwapModes: [AlternateTriggerMode] = [
        .disabled,
        .leftCommandDoubleTap,
        .rightCommandDoubleTap,
        .leftOptionDoubleTap,
        .rightOptionDoubleTap,
    ]

    var productionSafeMode: AlternateTriggerMode {
        switch self {
        case .disabled,
             .leftCommandDoubleTap,
             .rightCommandDoubleTap,
             .leftOptionDoubleTap,
             .rightOptionDoubleTap:
            return self
        case .rightCommandTap:
            return .disabled
        case .rightOptionTap:
            return .disabled
        }
    }

    var isProductionImmediateDoubleTap: Bool {
        switch productionSafeMode {
        case .leftCommandDoubleTap, .rightCommandDoubleTap:
            return true
        case .disabled,
             .rightCommandTap,
             .rightOptionTap,
             .leftOptionDoubleTap,
             .rightOptionDoubleTap:
            return false
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
