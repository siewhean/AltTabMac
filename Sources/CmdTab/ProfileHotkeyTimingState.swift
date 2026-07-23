import Foundation

/// Production timing policy for profile-backed hold-to-release shortcuts.
///
/// CmdTab's accepted interaction contract is a 100 ms hold threshold: a quick
/// release commits without constructing the overlay, while a held modifier
/// reveals the switcher. Command locks the first trigger timestamp so key repeat
/// cannot stretch the deadline; Option preserves the legacy rescheduling path.
struct ProfileHotkeyTimingPolicy: Equatable {
    let revealDelay: TimeInterval
    let ignoresRepeatedTriggerBeforeReveal: Bool
    let earlyReleaseAction: HotkeyEarlyReleaseAction

    static func forModifier(_ modifier: HotkeyModifier) -> Self {
        switch modifier {
        case .command:
            return Self(
                revealDelay: 0.10,
                ignoresRepeatedTriggerBeforeReveal: true,
                earlyReleaseAction: .quickSwitch
            )
        case .option:
            return Self(
                revealDelay: 0.10,
                ignoresRepeatedTriggerBeforeReveal: false,
                earlyReleaseAction: .quickSwitch
            )
        }
    }
}

/// Profile-aware equivalent of the proven Phase 1 hotkey timing state machine.
///
/// The event tap records the original CGEvent timestamp and returns immediately.
/// UI work is represented as an action that the router dispatches to the main
/// queue. A quick modifier release can therefore commit without constructing the
/// overlay, while a held modifier reveals the switcher at the deterministic
/// deadline.
struct PendingProfileHotkeyTrigger: Equatable {
    let match: ShortcutProfileMatch
    let startedAtUptime: TimeInterval
    let policy: ProfileHotkeyTimingPolicy

    init(match: ShortcutProfileMatch, startedAtUptime: TimeInterval) {
        self.match = match
        self.startedAtUptime = startedAtUptime
        if let modifier = match.primaryModifier {
            policy = .forModifier(modifier)
        } else {
            // The profile validator rejects a hold-to-release shortcut without a
            // Command or Option primary modifier. Keep a fail-closed policy here
            // as a second line of defence for corrupt persisted data.
            policy = ProfileHotkeyTimingPolicy(
                revealDelay: 0.10,
                ignoresRepeatedTriggerBeforeReveal: true,
                earlyReleaseAction: .none
            )
        }
    }

    var revealAtUptime: TimeInterval {
        startedAtUptime + policy.revealDelay
    }

    func shouldIgnoreRepeatedTrigger(_ candidate: ShortcutProfileMatch) -> Bool {
        match.profileID == candidate.profileID &&
            match.primaryModifier == candidate.primaryModifier &&
            policy.ignoresRepeatedTriggerBeforeReveal
    }
}

enum ProfileHotkeyTimingAction: Equatable {
    case scheduleReveal(atUptime: TimeInterval)
    case showOverlay(ShortcutProfileMatch)
    case quickSwitch(ShortcutProfileMatch)
    case confirmSelection(ShortcutProfileMatch)
}

struct ProfileHotkeyTimingState {
    private(set) var pendingTrigger: PendingProfileHotkeyTrigger?

    var hasPendingTrigger: Bool { pendingTrigger != nil }
    var pendingMatch: ShortcutProfileMatch? { pendingTrigger?.match }
    var pendingModifier: HotkeyModifier? { pendingTrigger?.match.primaryModifier }

    mutating func registerHiddenTrigger(
        match: ShortcutProfileMatch,
        startedAtUptime: TimeInterval,
        isRepeat: Bool
    ) -> ProfileHotkeyTimingAction? {
        guard match.releaseBehavior == .holdPrimaryModifier,
              match.primaryModifier != nil else {
            return nil
        }

        if isRepeat, pendingTrigger != nil {
            return nil
        }
        if let pendingTrigger,
           pendingTrigger.shouldIgnoreRepeatedTrigger(match) {
            return nil
        }

        let trigger = PendingProfileHotkeyTrigger(
            match: match,
            startedAtUptime: startedAtUptime
        )
        pendingTrigger = trigger
        return .scheduleReveal(atUptime: trigger.revealAtUptime)
    }

    /// Establishes release ownership for a profile that replaces an already
    /// visible session. No reveal timer is needed because the controller is
    /// switching visible profile surfaces immediately.
    mutating func beginVisibleTrigger(
        match: ShortcutProfileMatch,
        startedAtUptime: TimeInterval
    ) {
        guard match.releaseBehavior == .holdPrimaryModifier,
              match.primaryModifier != nil else {
            pendingTrigger = nil
            return
        }
        pendingTrigger = PendingProfileHotkeyTrigger(
            match: match,
            startedAtUptime: startedAtUptime
        )
    }

    mutating func handleRevealDeadline(
        now: TimeInterval,
        heldModifiers: Set<HotkeyModifier>
    ) -> ProfileHotkeyTimingAction? {
        guard let trigger = pendingTrigger,
              now >= trigger.revealAtUptime,
              let modifier = trigger.match.primaryModifier else {
            return nil
        }

        guard heldModifiers.contains(modifier) else {
            pendingTrigger = nil
            return hiddenReleaseAction(for: trigger)
        }
        return .showOverlay(trigger.match)
    }

    mutating func handleModifierRelease(
        _ modifier: HotkeyModifier,
        switcherVisible: Bool,
        activeProfileID: UUID?
    ) -> ProfileHotkeyTimingAction? {
        guard let trigger = pendingTrigger,
              trigger.match.primaryModifier == modifier else {
            return nil
        }

        pendingTrigger = nil
        if switcherVisible, activeProfileID == trigger.match.profileID {
            return .confirmSelection(trigger.match)
        }
        return hiddenReleaseAction(for: trigger)
    }

    mutating func cancel() {
        pendingTrigger = nil
    }

    private func hiddenReleaseAction(
        for trigger: PendingProfileHotkeyTrigger
    ) -> ProfileHotkeyTimingAction? {
        switch trigger.policy.earlyReleaseAction {
        case .none:
            return nil
        case .quickSwitch:
            return .quickSwitch(trigger.match)
        }
    }
}

/// Backward-compatible adapter retained for the original focused profile safety
/// tests. Production routing uses `ProfileHotkeyTimingState`, whose explicit
/// 100 ms policy is tested independently below.
struct ProfileHotkeyTriggerCoordinator {
    private var state = HotkeyTriggerState()
    private(set) var pendingMatch: ShortcutProfileMatch?

    var hasPendingTrigger: Bool { state.hasPendingTrigger }
    var pendingModifier: HotkeyModifier? { state.pendingModifier }

    mutating func registerHiddenTrigger(
        match: ShortcutProfileMatch,
        startedAtUptime: TimeInterval
    ) -> ProfileHotkeyTimingAction? {
        guard let modifier = match.primaryModifier else { return nil }
        if let pendingMatch, pendingMatch.profileID != match.profileID {
            cancel()
        }
        guard let action = state.registerHiddenTabTrigger(
            modifier: modifier,
            reverse: match.reverse,
            startedAtUptime: startedAtUptime
        ) else {
            return nil
        }
        pendingMatch = match
        return mapped(action, using: match)
    }

    mutating func handleRevealDeadline(
        now: TimeInterval,
        heldModifiers: Set<HotkeyModifier>
    ) -> ProfileHotkeyTimingAction? {
        guard let match = pendingMatch,
              let action = state.handleRevealDeadline(
                  now: now,
                  heldModifiers: heldModifiers
              ) else {
            return nil
        }
        let mappedAction = mapped(action, using: match)
        if !state.hasPendingTrigger { pendingMatch = nil }
        return mappedAction
    }

    mutating func handleModifierRelease(
        _ modifier: HotkeyModifier,
        switcherVisible: Bool
    ) -> ProfileHotkeyTimingAction? {
        guard let match = pendingMatch,
              let action = state.handleModifierRelease(
                  modifier,
                  switcherVisible: switcherVisible
              ) else {
            return nil
        }
        pendingMatch = nil
        return mapped(action, using: match)
    }

    mutating func cancel() {
        state.cancelPendingTrigger()
        pendingMatch = nil
    }

    private func mapped(
        _ action: HotkeyTriggerAction,
        using match: ShortcutProfileMatch
    ) -> ProfileHotkeyTimingAction {
        switch action {
        case let .scheduleReveal(atUptime):
            return .scheduleReveal(atUptime: atUptime)
        case .showOverlay:
            return .showOverlay(match)
        case .quickSwitch:
            return .quickSwitch(match)
        case .confirmSelection:
            return .confirmSelection(match)
        }
    }
}
