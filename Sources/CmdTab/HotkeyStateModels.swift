import AppKit

/// Shared modifier models used by the profile-backed production event router and
/// by the deterministic hotkey state-machine tests.
enum HotkeyModifier: Hashable {
    case command
    case option

    func isHeld(in flags: NSEvent.ModifierFlags) -> Bool {
        switch self {
        case .command:
            return flags.contains(.command)
        case .option:
            return flags.contains(.option)
        }
    }
}

enum PhysicalModifierTriggerKey: Hashable {
    case leftCommand
    case rightCommand
    case leftOption
    case rightOption

    init?(flagsChangedKeyCode: Int64) {
        switch flagsChangedKeyCode {
        case 55:
            self = .leftCommand
        case 54:
            self = .rightCommand
        case 58:
            self = .leftOption
        case 61:
            self = .rightOption
        default:
            return nil
        }
    }
}

enum HotkeyEarlyReleaseAction: Equatable {
    case none
    case quickSwitch
}

private extension AlternateTriggerMode {
    var activationKind: AlternateTriggerActivationKind? {
        switch productionSafeMode {
        case .disabled, .rightCommandTap, .rightOptionTap:
            return nil
        case .rightCommandDoubleTap, .leftCommandDoubleTap:
            return .doubleTap
        case .rightOptionDoubleTap, .leftOptionDoubleTap:
            return .chord
        }
    }

    var monitoredKey: PhysicalModifierTriggerKey? {
        switch productionSafeMode {
        case .leftCommandDoubleTap:
            return .leftCommand
        case .rightCommandDoubleTap:
            return .rightCommand
        case .disabled,
             .rightCommandTap,
             .rightOptionTap,
             .rightOptionDoubleTap,
             .leftOptionDoubleTap:
            return nil
        }
    }

    var monitoredKeys: Set<PhysicalModifierTriggerKey>? {
        switch productionSafeMode {
        case .leftOptionDoubleTap:
            return [.leftCommand, .leftOption]
        case .rightOptionDoubleTap:
            return [.rightCommand, .rightOption]
        case .disabled,
             .rightCommandTap,
             .rightCommandDoubleTap,
             .rightOptionTap,
             .leftCommandDoubleTap:
            return nil
        }
    }
}

enum AlternateTriggerActivationKind: Equatable {
    case doubleTap
    case chord
}

private struct ActiveAlternateModifierPress: Equatable {
    let key: PhysicalModifierTriggerKey
    let pressedAtUptime: TimeInterval
    var wasInterrupted: Bool
}

private struct PendingAlternateModifierTap: Equatable {
    let key: PhysicalModifierTriggerKey
    let releasedAtUptime: TimeInterval
}

private struct ActiveAlternateChordPress: Equatable {
    let keys: Set<PhysicalModifierTriggerKey>
    let pressedAtUptime: TimeInterval
    var wasInterrupted: Bool
}

/// Fail-closed production state for modifier-only Hot Swap gestures.
///
/// A Command double tap is accepted only when both short taps complete within a
/// 250 ms release-to-release window. Side-matched Command+Option chords are tracked
/// from the actual sequence of physical modifier events; the aggregate modifier
/// booleans supplied by the event router are intentionally not trusted for chord
/// membership because a missed flagsChanged event could otherwise make Option alone
/// look like a stale Command+Option pair.
struct AlternateModifierTriggerState {
    static let maximumDoubleTapGap: TimeInterval = 0.25

    private var activePress: ActiveAlternateModifierPress?
    private var activeChordPress: ActiveAlternateChordPress?
    private var pendingDoubleTap: PendingAlternateModifierTap?
    private var triggeredCombination: Set<PhysicalModifierTriggerKey>?
    private var pressedKeys = Set<PhysicalModifierTriggerKey>()
    private var chordWasInterrupted = false
    private let maximumTapDuration: TimeInterval = 0.28

    mutating func handleModifierChange(
        _ key: PhysicalModifierTriggerKey,
        isDown: Bool,
        mode: AlternateTriggerMode,
        leftCommandDown: Bool,
        leftOptionDown: Bool,
        rightCommandDown: Bool,
        rightOptionDown: Bool,
        now: TimeInterval
    ) -> Bool {
        // Preserve the source-compatible signature used by the production router
        // and existing tests, but derive exact chord membership from pressedKeys.
        _ = leftCommandDown
        _ = leftOptionDown
        _ = rightCommandDown
        _ = rightOptionDown

        pruneExpiredState(now: now)
        updatePressedKeys(key, isDown: isDown)

        let safeMode = mode.productionSafeMode
        guard safeMode != .disabled,
              let activationKind = safeMode.activationKind else {
            clearGestureState(keepPressedKeys: true)
            return false
        }

        switch activationKind {
        case .doubleTap:
            triggeredCombination = nil
            chordWasInterrupted = false
            activeChordPress = nil
            return handleDoubleTapChange(
                key,
                isDown: isDown,
                mode: safeMode,
                now: now
            )

        case .chord:
            activePress = nil
            pendingDoubleTap = nil
            return handleChordChange(
                key,
                isDown: isDown,
                mode: safeMode,
                now: now
            )
        }
    }

    mutating func noteInterveningKeyDown(now _: TimeInterval) {
        if var activePress {
            activePress.wasInterrupted = true
            self.activePress = activePress
        }
        pendingDoubleTap = nil
        if !pressedKeys.isEmpty {
            chordWasInterrupted = true
            if var activeChordPress {
                activeChordPress.wasInterrupted = true
                self.activeChordPress = activeChordPress
            }
        }
    }

    mutating func noteStandardShortcut(
        using _: PhysicalModifierTriggerKey,
        now _: TimeInterval
    ) {
        reset()
    }

    mutating func noteStandardShortcut(now _: TimeInterval) {
        reset()
    }

    private mutating func handleDoubleTapChange(
        _ key: PhysicalModifierTriggerKey,
        isDown: Bool,
        mode: AlternateTriggerMode,
        now: TimeInterval
    ) -> Bool {
        guard mode.monitoredKey == key else {
            if isDown {
                interruptDoubleTapSequence()
            }
            return false
        }

        if isDown {
            activePress = ActiveAlternateModifierPress(
                key: key,
                pressedAtUptime: now,
                wasInterrupted: false
            )
            return false
        }

        guard let press = activePress, press.key == key else {
            return false
        }
        activePress = nil

        let pressDuration = now - press.pressedAtUptime
        guard !press.wasInterrupted,
              pressDuration >= 0,
              pressDuration <= maximumTapDuration else {
            pendingDoubleTap = nil
            return false
        }

        if let pendingDoubleTap,
           pendingDoubleTap.key == key {
            let gap = now - pendingDoubleTap.releasedAtUptime
            self.pendingDoubleTap = nil
            return gap >= 0 && gap <= Self.maximumDoubleTapGap
        }

        pendingDoubleTap = PendingAlternateModifierTap(
            key: key,
            releasedAtUptime: now
        )
        return false
    }

    private mutating func handleChordChange(
        _ key: PhysicalModifierTriggerKey,
        isDown: Bool,
        mode: AlternateTriggerMode,
        now: TimeInterval
    ) -> Bool {
        guard let monitoredKeys = mode.monitoredKeys,
              monitoredKeys.contains(key) else {
            if isDown {
                chordWasInterrupted = true
                if var activeChordPress {
                    activeChordPress.wasInterrupted = true
                    self.activeChordPress = activeChordPress
                }
            }
            return false
        }

        if isDown {
            // When all monitored keys become pressed simultaneously without interruption,
            // record the active chord press. Hot Swap only fires on key-up within maximumTapDuration.
            if !chordWasInterrupted && pressedKeys == monitoredKeys {
                activeChordPress = ActiveAlternateChordPress(
                    keys: monitoredKeys,
                    pressedAtUptime: now,
                    wasInterrupted: false
                )
            }
            return false
        }

        // On key-up: verify the chord was held cleanly, not interrupted by any character keys
        // (like C or V in Command-Option-C/V), and released within maximumTapDuration.
        guard let chordPress = activeChordPress,
              chordPress.keys == monitoredKeys else {
            if pressedKeys.isEmpty {
                chordWasInterrupted = false
                activeChordPress = nil
                triggeredCombination = nil
            }
            return false
        }
        activeChordPress = nil

        let pressDuration = now - chordPress.pressedAtUptime
        guard !chordPress.wasInterrupted,
              !chordWasInterrupted,
              pressDuration >= 0,
              pressDuration <= maximumTapDuration else {
            return false
        }

        if triggeredCombination == monitoredKeys {
            return false
        }

        triggeredCombination = monitoredKeys
        return true
    }

    private mutating func updatePressedKeys(
        _ key: PhysicalModifierTriggerKey,
        isDown: Bool
    ) {
        if isDown {
            pressedKeys.insert(key)
        } else {
            pressedKeys.remove(key)
            if pressedKeys.isEmpty {
                chordWasInterrupted = false
            }
        }
    }

    private mutating func interruptDoubleTapSequence() {
        if var activePress {
            activePress.wasInterrupted = true
            self.activePress = activePress
        }
        pendingDoubleTap = nil
    }

    private mutating func pruneExpiredState(now: TimeInterval) {
        if let pendingDoubleTap,
           now - pendingDoubleTap.releasedAtUptime > Self.maximumDoubleTapGap {
            self.pendingDoubleTap = nil
        }
    }

    private mutating func clearGestureState(keepPressedKeys: Bool) {
        activePress = nil
        activeChordPress = nil
        pendingDoubleTap = nil
        triggeredCombination = nil
        chordWasInterrupted = false
        if !keepPressedKeys {
            pressedKeys.removeAll()
        }
    }

    private mutating func reset() {
        clearGestureState(keepPressedKeys: false)
    }
}

struct HotkeyTriggerPolicy: Equatable {
    let revealDelay: TimeInterval
    let ignoresRepeatedTabBeforeReveal: Bool
    let earlyReleaseAction: HotkeyEarlyReleaseAction

    static func forModifier(_ modifier: HotkeyModifier) -> HotkeyTriggerPolicy {
        switch modifier {
        case .command:
            return HotkeyTriggerPolicy(
                revealDelay: 0,
                ignoresRepeatedTabBeforeReveal: true,
                earlyReleaseAction: .quickSwitch
            )
        case .option:
            return HotkeyTriggerPolicy(
                revealDelay: 0,
                ignoresRepeatedTabBeforeReveal: false,
                earlyReleaseAction: .quickSwitch
            )
        }
    }
}

struct PendingHotkeyTrigger: Equatable {
    let modifier: HotkeyModifier
    let reverse: Bool
    let startedAtUptime: TimeInterval
    let policy: HotkeyTriggerPolicy

    init(
        modifier: HotkeyModifier,
        reverse: Bool,
        startedAtUptime: TimeInterval
    ) {
        self.modifier = modifier
        self.reverse = reverse
        self.startedAtUptime = startedAtUptime
        self.policy = .forModifier(modifier)
    }

    var revealAtUptime: TimeInterval {
        startedAtUptime + policy.revealDelay
    }

    func shouldIgnoreRepeatedTab(for modifier: HotkeyModifier) -> Bool {
        self.modifier == modifier && policy.ignoresRepeatedTabBeforeReveal
    }
}

enum HotkeyTriggerAction: Equatable {
    case scheduleReveal(atUptime: TimeInterval)
    case showOverlay(reverse: Bool, modifier: HotkeyModifier)
    case quickSwitch(reverse: Bool)
    case confirmSelection
}

struct HotkeyTriggerState {
    private(set) var pendingTrigger: PendingHotkeyTrigger?

    var hasPendingTrigger: Bool {
        pendingTrigger != nil
    }

    var pendingModifier: HotkeyModifier? {
        pendingTrigger?.modifier
    }

    mutating func registerHiddenTabTrigger(
        modifier: HotkeyModifier,
        reverse: Bool,
        startedAtUptime: TimeInterval
    ) -> HotkeyTriggerAction? {
        if let pendingTrigger,
           pendingTrigger.shouldIgnoreRepeatedTab(for: modifier) {
            return nil
        }

        let trigger = PendingHotkeyTrigger(
            modifier: modifier,
            reverse: reverse,
            startedAtUptime: startedAtUptime
        )
        pendingTrigger = trigger
        return .scheduleReveal(atUptime: trigger.revealAtUptime)
    }

    mutating func handleRevealDeadline(
        now: TimeInterval,
        heldModifiers: Set<HotkeyModifier>
    ) -> HotkeyTriggerAction? {
        guard let trigger = pendingTrigger,
              now >= trigger.revealAtUptime else {
            return nil
        }

        guard heldModifiers.contains(trigger.modifier) else {
            pendingTrigger = nil
            return actionForHiddenRelease(of: trigger)
        }

        return .showOverlay(
            reverse: trigger.reverse,
            modifier: trigger.modifier
        )
    }

    mutating func handleModifierRelease(
        _ modifier: HotkeyModifier,
        switcherVisible: Bool
    ) -> HotkeyTriggerAction? {
        guard let trigger = pendingTrigger,
              trigger.modifier == modifier else {
            return nil
        }

        pendingTrigger = nil
        if switcherVisible {
            return .confirmSelection
        }

        return actionForHiddenRelease(of: trigger)
    }

    mutating func cancelPendingTrigger() {
        pendingTrigger = nil
    }

    private func actionForHiddenRelease(
        of trigger: PendingHotkeyTrigger
    ) -> HotkeyTriggerAction? {
        switch trigger.policy.earlyReleaseAction {
        case .none:
            return nil
        case .quickSwitch:
            return .quickSwitch(reverse: trigger.reverse)
        }
    }
}
