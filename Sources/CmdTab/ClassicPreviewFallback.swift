import Foundation

/// User-facing content shown when a window thumbnail cannot be captured.
///
/// This is intentionally an icon-and-label fallback rather than a loading
/// skeleton: capture can be temporarily or permanently unavailable.
enum ClassicPreviewFallback {
    enum IconKind: Equatable {
        case applicationIcon
        case systemSymbol
    }

    static let systemSymbolName = "app.dashed"
    static let label = "Preview unavailable"

    static func iconKind(hasApplicationIcon: Bool) -> IconKind {
        hasApplicationIcon ? .applicationIcon : .systemSymbol
    }

    static func accessibilityLabel(for title: String) -> String {
        "\(label) for \(title)"
    }
}
