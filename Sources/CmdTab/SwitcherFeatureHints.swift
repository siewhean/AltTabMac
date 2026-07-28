import Foundation

struct SwitcherFeatureHint: Equatable, Identifiable {
    let id: String
    let title: String
    let message: String
}

@MainActor
final class SwitcherFeatureHintStore: ObservableObject {
    static let shared = SwitcherFeatureHintStore()

    @Published private(set) var visibleHint: SwitcherFeatureHint?

    private let defaults: UserDefaults
    private let keyPrefix: String
    private let maximumPresentations: Int

    init(
        defaults: UserDefaults = .standard,
        keyPrefix: String = "switcherFeatureHintPresentations",
        maximumPresentations: Int = 2
    ) {
        self.defaults = defaults
        self.keyPrefix = keyPrefix
        self.maximumPresentations = maximumPresentations
    }

    func presentHint(for style: SwitcherStyle) {
        let key = presentationKey(for: style)
        let presentations = defaults.integer(forKey: key)
        guard presentations < maximumPresentations else {
            visibleHint = nil
            return
        }
        defaults.set(presentations + 1, forKey: key)
        visibleHint = Self.hint(for: style)
    }

    func dismiss() {
        visibleHint = nil
    }

    func resetForTesting() {
        for style in SwitcherStyle.allCases {
            defaults.removeObject(forKey: presentationKey(for: style))
        }
        visibleHint = nil
    }

    private func presentationKey(for style: SwitcherStyle) -> String {
        "\(keyPrefix).\(style.rawValue)"
    }

    static func hint(for style: SwitcherStyle) -> SwitcherFeatureHint {
        switch style {
        case .classicGrid:
            return SwitcherFeatureHint(
                id: "classic-grid-quick-actions",
                title: "Quick Actions",
                message: "While CmdTab is open, press ⌘H to hide, ⌘M to minimise, ⌘W to close, or ⌘Q to quit the selected app."
            )
        case .commandPalette:
            return SwitcherFeatureHint(
                id: "command-palette-search",
                title: "Type to search",
                message: "Start typing an app or window title. CmdTab remembers repeated choices and ranks them sooner next time."
            )
        case .radialMenu:
            return SwitcherFeatureHint(
                id: "radial-menu-navigation",
                title: "Switch by direction",
                message: "Move around the ring with the shortcut, or point at a target and release to switch."
            )
        }
    }
}
