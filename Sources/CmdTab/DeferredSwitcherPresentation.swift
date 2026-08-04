import Foundation

/// Holds one swallowed profile shortcut while a fail-closed scoped snapshot is
/// still being enriched. The event tap must never wait synchronously for AX or
/// workspace data, but it also must not lose the user's selector request when
/// that exact snapshot arrives moments later.
struct DeferredSwitcherPresentation {
    enum Action: Equatable {
        case show(profileID: UUID, reverse: Bool, requireHeldModifier: HotkeyModifier?)
        case commit(profileID: UUID, reverse: Bool)
    }

    private(set) var action: Action?

    mutating func deferShow(
        profileID: UUID,
        reverse: Bool,
        requireHeldModifier: HotkeyModifier?
    ) {
        action = .show(
            profileID: profileID,
            reverse: reverse,
            requireHeldModifier: requireHeldModifier
        )
    }

    mutating func deferCommit(profileID: UUID, reverse: Bool) {
        action = .commit(profileID: profileID, reverse: reverse)
    }

    mutating func takeReadyAction(
        isModifierHeld: (HotkeyModifier) -> Bool
    ) -> Action? {
        guard let action else { return nil }
        self.action = nil

        if case let .show(_, _, requireHeldModifier: modifier?) = action,
           !isModifierHeld(modifier) {
            return nil
        }
        return action
    }

    mutating func cancel() {
        action = nil
    }
}
