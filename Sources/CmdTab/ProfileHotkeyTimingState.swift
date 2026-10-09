import CoreGraphics
import Foundation

/// Side-specific modifier state decoded from the device-dependent bits that
/// every keyboard `CGEvent` carries (IOKit `NX_DEVICE*KEYMASK`).
struct PhysicalModifierDeviceFlags: Equatable {
    let leftCommand: Bool
    let rightCommand: Bool
    let leftOption: Bool
    let rightOption: Bool

    init(flags: CGEventFlags) {
        let raw = flags.rawValue
        leftCommand = raw & 0x08 != 0
        rightCommand = raw & 0x10 != 0
        leftOption = raw & 0x20 != 0
        rightOption = raw & 0x40 != 0
    }

    func isDown(_ key: PhysicalModifierTriggerKey) -> Bool {
        switch key {
        case .leftCommand: return leftCommand
        case .rightCommand: return rightCommand
        case .leftOption: return leftOption
        case .rightOption: return rightOption
        }
    }
}

/// Converts a `CGEvent` timestamp into the `systemUptime` clock used for every
/// deadline. The value is documented as nanoseconds since startup, but it may
/// be reported in mach absolute-time ticks, and synthesized events carry 0.
/// The unit that lands closest to `now` (and not in the future) wins; an
/// implausible value falls back to `now` so deadlines never collapse or stretch.
enum EventTimestampClock {
    static let plausibleAge: TimeInterval = 5
    static let futureTolerance: TimeInterval = 0.05

    static func uptime(
        eventTimestamp: UInt64,
        now: TimeInterval,
        timebaseNumerator: UInt32 = machTimebase.numer,
        timebaseDenominator: UInt32 = machTimebase.denom
    ) -> TimeInterval {
        guard eventTimestamp > 0, timebaseDenominator > 0 else { return now }
        let nanoseconds = TimeInterval(eventTimestamp) / 1_000_000_000
        let machTicks = nanoseconds * TimeInterval(timebaseNumerator) /
            TimeInterval(timebaseDenominator)
        let plausible = [nanoseconds, machTicks].filter {
            $0 <= now + futureTolerance && now - $0 <= plausibleAge
        }
        return plausible.min { abs(now - $0) < abs(now - $1) }.map { min($0, now) } ?? now
    }

    static let machTimebase: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()
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
    /// Directions (`true` = reverse) of deliberate extra trigger presses made
    /// before the session started, applied in order once it exists.
    var additionalAdvances: [Bool] = []

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
    case showOverlay(ShortcutProfileMatch, additionalAdvances: [Bool] = [])
    case quickSwitch(ShortcutProfileMatch, additionalAdvances: [Bool] = [])
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

    /// Records a further press of the pending profile's shortcut before the
    /// session exists. Key repeat and other profiles never advance.
    mutating func registerAdditionalAdvance(
        match: ShortcutProfileMatch,
        isRepeat: Bool
    ) {
        guard !isRepeat,
              pendingTrigger?.match.profileID == match.profileID else {
            return
        }
        pendingTrigger?.additionalAdvances.append(match.reverse)
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
        // The trigger keeps release ownership after the reveal; its early
        // advances are handed over exactly once.
        pendingTrigger?.additionalAdvances = []
        return .showOverlay(
            trigger.match,
            additionalAdvances: trigger.additionalAdvances
        )
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
            return .quickSwitch(
                trigger.match,
                additionalAdvances: trigger.additionalAdvances
            )
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
