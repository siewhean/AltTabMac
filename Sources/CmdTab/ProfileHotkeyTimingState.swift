import Foundation

/// A hidden shortcut is accepted only when its primary modifier and key arrive as
/// one deliberate chord. Holding Command or Option first and pressing the key
/// later is swallowed without switching, which prevents accidental activations
/// and native-switcher bleed-through.
struct ShortcutChordTimingState {
    static let defaultMaximumLeadInterval: TimeInterval = 0.16

    private let maximumLeadInterval: TimeInterval
    private var commandDownAt: TimeInterval?
    private var optionDownAt: TimeInterval?
    private var commandWasInterrupted = false
    private var optionWasInterrupted = false

    init(
        maximumLeadInterval: TimeInterval = Self.defaultMaximumLeadInterval
    ) {
        self.maximumLeadInterval = maximumLeadInterval
    }

    mutating func noteModifierChange(
        _ modifier: HotkeyModifier,
        isDown: Bool,
        at uptime: TimeInterval
    ) {
        switch modifier {
        case .command:
            commandDownAt = isDown ? uptime : nil
            commandWasInterrupted = false
        case .option:
            optionDownAt = isDown ? uptime : nil
            optionWasInterrupted = false
        }
    }

    /// Any ordinary key pressed while Command or Option is held contaminates that
    /// modifier gesture. This is the critical pass-through rule for sequences such
    /// as Command-Tab followed by Command-V: Paste must never complete a stale
    /// switcher trigger when the modifier is released.
    mutating func noteInterveningKeyDown() {
        if commandDownAt != nil {
            commandWasInterrupted = true
        }
        if optionDownAt != nil {
            optionWasInterrupted = true
        }
    }

    func accepts(
        primaryModifier: HotkeyModifier?,
        keyDownAt uptime: TimeInterval
    ) -> Bool {
        guard let primaryModifier else { return true }
        let modifierDownAt: TimeInterval?
        let wasInterrupted: Bool
        switch primaryModifier {
        case .command:
            modifierDownAt = commandDownAt
            wasInterrupted = commandWasInterrupted
        case .option:
            modifierDownAt = optionDownAt
            wasInterrupted = optionWasInterrupted
        }
        guard let modifierDownAt, !wasInterrupted else { return false }
        let lead = uptime - modifierDownAt
        return lead >= 0 && lead <= maximumLeadInterval
    }

    mutating func reset() {
        commandDownAt = nil
        optionDownAt = nil
        commandWasInterrupted = false
        optionWasInterrupted = false
    }
}

/// Physical modifier chords used by Hot Swap must also be pressed together. The
/// state records real key-down timestamps rather than merely checking whether both
/// modifiers happen to be held at the same time.
struct PhysicalModifierChordTimingState {
    static let defaultMaximumSeparation: TimeInterval = 0.16

    private let maximumSeparation: TimeInterval
    private var leftCommandDownAt: TimeInterval?
    private var rightCommandDownAt: TimeInterval?
    private var leftOptionDownAt: TimeInterval?
    private var rightOptionDownAt: TimeInterval?
    private var leftCommandRecentDownAt: TimeInterval?
    private var rightCommandRecentDownAt: TimeInterval?
    private var leftOptionRecentDownAt: TimeInterval?
    private var rightOptionRecentDownAt: TimeInterval?

    init(
        maximumSeparation: TimeInterval = Self.defaultMaximumSeparation
    ) {
        self.maximumSeparation = maximumSeparation
    }

    mutating func noteModifierChange(
        _ key: PhysicalModifierTriggerKey,
        isDown: Bool,
        at uptime: TimeInterval
    ) {
        switch key {
        case .leftCommand:
            leftCommandDownAt = isDown ? uptime : nil
            if isDown { leftCommandRecentDownAt = uptime }
        case .rightCommand:
            rightCommandDownAt = isDown ? uptime : nil
            if isDown { rightCommandRecentDownAt = uptime }
        case .leftOption:
            leftOptionDownAt = isDown ? uptime : nil
            if isDown { leftOptionRecentDownAt = uptime }
        case .rightOption:
            rightOptionDownAt = isDown ? uptime : nil
            if isDown { rightOptionRecentDownAt = uptime }
        }

        if leftCommandDownAt == nil && rightCommandDownAt == nil && leftOptionDownAt == nil && rightOptionDownAt == nil {
            leftCommandRecentDownAt = nil
            rightCommandRecentDownAt = nil
            leftOptionRecentDownAt = nil
            rightOptionRecentDownAt = nil
        }
    }

    func accepts(keys: [PhysicalModifierTriggerKey]) -> Bool {
        let times = keys.compactMap { downAt(for: $0) ?? recentDownAt(for: $0) }
        guard times.count == keys.count,
              let earliest = times.min(),
              let latest = times.max() else {
            return false
        }
        return latest - earliest <= maximumSeparation
    }

    mutating func reset() {
        leftCommandDownAt = nil
        rightCommandDownAt = nil
        leftOptionDownAt = nil
        rightOptionDownAt = nil
        leftCommandRecentDownAt = nil
        rightCommandRecentDownAt = nil
        leftOptionRecentDownAt = nil
        rightOptionRecentDownAt = nil
    }

    private func downAt(
        for key: PhysicalModifierTriggerKey
    ) -> TimeInterval? {
        switch key {
        case .leftCommand:
            return leftCommandDownAt
        case .rightCommand:
            return rightCommandDownAt
        case .leftOption:
            return leftOptionDownAt
        case .rightOption:
            return rightOptionDownAt
        }
    }

    private func recentDownAt(
        for key: PhysicalModifierTriggerKey
    ) -> TimeInterval? {
        switch key {
        case .leftCommand:
            return leftCommandRecentDownAt
        case .rightCommand:
            return rightCommandRecentDownAt
        case .leftOption:
            return leftOptionRecentDownAt
        case .rightOption:
            return rightOptionRecentDownAt
        }
    }
}

extension AlternateTriggerMode {
    var simultaneousChordKeys: [PhysicalModifierTriggerKey]? {
        switch self {
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

/// Production timing policy for profile-backed hold-to-release shortcuts.
///
/// CmdTab waits 200 ms before showing the overlay. A deliberate quick chord can
/// therefore switch without flashing UI, while a held modifier still reveals the
/// switcher. Command locks the first trigger timestamp so key repeat cannot stretch
/// the deadline; Option preserves the legacy rescheduling path.
struct ProfileHotkeyTimingPolicy: Equatable {
    let revealDelay: TimeInterval
    let ignoresRepeatedTriggerBeforeReveal: Bool
    let earlyReleaseAction: HotkeyEarlyReleaseAction

    static func forModifier(_ modifier: HotkeyModifier) -> Self {
        switch modifier {
        case .command:
            return Self(
                revealDelay: 0.20,
                ignoresRepeatedTriggerBeforeReveal: true,
                earlyReleaseAction: .quickSwitch
            )
        case .option:
            return Self(
                revealDelay: 0.20,
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
                revealDelay: 0.20,
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
/// hold policy is tested independently above.
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
