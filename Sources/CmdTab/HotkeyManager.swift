import AppKit
import CoreGraphics
import os.log

private let hotkeyLog = OSLog(subsystem: "CmdTab", category: "HotkeyManager")

/// Intercepts ⌘Tab and ⌥Tab globally via CGEventTap.
/// Suppresses the default macOS switcher while the overlay is shown.
///
/// **Critical design constraint:** The CGEvent.tap callback MUST return in
/// under ~20 ms or macOS will temporarily disable the tap, allowing the native
/// switcher to bleed through. ALL work inside the callback is limited to
/// reading lightweight state and returning nil (swallowing the event).
/// Every side-effect (UI updates, window fetching) is dispatched
/// asynchronously to the main queue.
final class HotkeyManager {
    private weak var switcher: SwitcherWindowController?
    private let preferences = SwitcherPreferences.shared
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private var cmdDown = false
    private var optDown = false
    private var leftCommandDown = false
    private var leftOptionDown = false
    private var rightCommandDown = false
    private var rightOptionDown = false
    private var showUIWorkItem: DispatchWorkItem?
    private var triggerState = HotkeyTriggerState()
    private var alternateTriggerState = AlternateModifierTriggerState()
    private let currentUptime: () -> TimeInterval

    init(
        switcher: SwitcherWindowController,
        currentUptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) {
        self.switcher = switcher
        self.currentUptime = currentUptime
        install()
    }

    deinit {
        uninstallTap()
    }

    private func uptime(for eventTimestamp: CGEventTimestamp) -> TimeInterval {
        TimeInterval(eventTimestamp) / 1_000_000_000
    }

    // MARK: - Setup

    private func install() {
        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue)     |
            (1 << CGEventType.keyUp.rawValue)       |
            (1 << CGEventType.flagsChanged.rawValue)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
                return manager.handle(proxy: proxy, type: type, event: event)
            },
            userInfo: selfPtr
        ) else {
            print("[CmdTab] ⚠️  Failed to create CGEventTap. Grant Accessibility in System Settings > Privacy.")
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        runLoopSource = source
    }

    private func uninstallTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func recoverEventTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    /// Dispatch work to the main queue asynchronously. NEVER executes
    /// synchronously, even when already on the main thread — this ensures
    /// the CGEvent.tap callback returns immediately without blocking.
    private func dispatchToMain(_ work: @escaping () -> Void) {
        DispatchQueue.main.async(execute: work)
    }

    private func keyEquivalent(for event: CGEvent) -> String? {
        var charCount: Int = 0
        var charBuffer = [UniChar](repeating: 0, count: 4)
        event.keyboardGetUnicodeString(
            maxStringLength: charBuffer.count,
            actualStringLength: &charCount,
            unicodeString: &charBuffer
        )

        guard charCount > 0 else { return nil }
        return String(utf16CodeUnits: charBuffer, count: charCount)
    }

    private func cancelScheduledReveal() {
        showUIWorkItem?.cancel()
        showUIWorkItem = nil
    }

    private func clearPendingTrigger() {
        cancelScheduledReveal()
        triggerState.cancelPendingTrigger()
    }

    private func scheduleReveal(for revealAtUptime: TimeInterval) {
        cancelScheduledReveal()

        let delay = max(0, revealAtUptime - currentUptime())
        if delay <= 0 {
            handleScheduledReveal()
            return
        }

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.showUIWorkItem = nil
            self.handleScheduledReveal()
        }

        showUIWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func handleScheduledReveal() {
        guard let action = triggerState.handleRevealDeadline(
            now: currentUptime(),
            heldModifiers: liveHeldModifiers()
        ) else {
            return
        }

        performTriggerAction(action)
    }

    private func liveHeldModifiers() -> Set<HotkeyModifier> {
        let flags = NSEvent.modifierFlags
        var held = Set<HotkeyModifier>()
        if flags.contains(.command) {
            held.insert(.command)
        }
        if flags.contains(.option) {
            held.insert(.option)
        }
        return held
    }

    private func schedulePostShowModifierCheck(for modifier: HotkeyModifier) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self,
                  self.switcher?.isVisible == true,
                  self.triggerState.pendingModifier == modifier else {
                return
            }

            if !modifier.isHeld(in: NSEvent.modifierFlags) {
                self.handleModifierRelease(modifier)
            }
        }
    }

    private func performTriggerAction(_ action: HotkeyTriggerAction) {
        switch action {
        case let .scheduleReveal(atUptime):
            scheduleReveal(for: atUptime)

        case let .showOverlay(reverse, modifier):
            switcher?.showOrAdvance(reverse: reverse)
            schedulePostShowModifierCheck(for: modifier)

        case let .quickSwitch(reverse):
            dispatchToMain { [weak self] in
                self?.switcher?.commitTriggerSession(reverse: reverse)
            }

        case .confirmSelection:
            dispatchToMain { [weak self] in
                self?.switcher?.confirmAndHide()
            }
        }
    }

    private func activateAlternateTrigger() {
        guard let switcher else { return }
        dispatchToMain {
            if switcher.isVisible {
                switcher.confirmAndHide()
            } else {
                switcher.commitTriggerSession(reverse: false)
            }
        }
    }

    private func handleAlternateModifierFlagsChanged(
        keyCode: Int64,
        flags: CGEventFlags,
        eventTimestamp: CGEventTimestamp
    ) {
        guard let physicalKey = PhysicalModifierTriggerKey(flagsChangedKeyCode: keyCode) else { return }
        let isDown = toggleModifierState(for: physicalKey)

        let triggerMode = preferences.alternateTrigger
        let shouldActivate = alternateTriggerState.handleModifierChange(
            physicalKey,
            isDown: isDown,
            mode: triggerMode,
            now: uptime(for: eventTimestamp)
        )
        if shouldActivate {
            activateAlternateTrigger()
        }
    }

    private func toggleModifierState(for physicalKey: PhysicalModifierTriggerKey) -> Bool {
        switch physicalKey {
        case .leftCommand:
            leftCommandDown.toggle()
            return leftCommandDown
        case .rightCommand:
            rightCommandDown.toggle()
            return rightCommandDown
        case .leftOption:
            leftOptionDown.toggle()
            return leftOptionDown
        case .rightOption:
            rightOptionDown.toggle()
            return rightOptionDown
        }
    }

    private func handleTabTrigger(
        modifier: HotkeyModifier,
        reverse: Bool,
        triggeredAtUptime: TimeInterval? = nil
    ) {
        guard let switcher else { return }
        if switcher.isVisible {
            dispatchToMain { [weak self] in
                self?.switcher?.showOrAdvance(reverse: reverse)
            }
            return
        }

        guard let action = triggerState.registerHiddenTabTrigger(
            modifier: modifier,
            reverse: reverse,
            startedAtUptime: triggeredAtUptime ?? currentUptime()
        ) else {
            return
        }

        performTriggerAction(action)
    }

    private func handleModifierRelease(_ modifier: HotkeyModifier) {
        cancelScheduledReveal()
        guard let action = triggerState.handleModifierRelease(
            modifier,
            switcherVisible: switcher?.isVisible == true
        ) else {
            return
        }

        performTriggerAction(action)
    }

    /// Called before click-based commits so the follow-up modifier release
    /// cannot trigger a second activation.
    func clearTriggerStateFromClickCommit() {
        clearPendingTrigger()
    }

    // MARK: - Event handling

    /// The CGEvent.tap callback. This MUST return as fast as possible (< 20 ms).
    /// All heavy work is dispatched asynchronously via `dispatchToMain`.
    private func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let start = DispatchTime.now()

        let result = handleInner(proxy: proxy, type: type, event: event)

        let elapsed = DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds
        let elapsedMs = Double(elapsed) / 1_000_000
        if elapsedMs > 5 {
            os_log(.info, log: hotkeyLog, "Event tap callback took %.2f ms (type=%{public}d) — target < 20 ms", elapsedMs, type.rawValue)
        }

        return result
    }

    /// Inner handler — pure logic, no timing overhead.
    private func handleInner(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            os_log(.info, log: hotkeyLog, "Event tap re-enabled after system disable (type=%{public}d)", type.rawValue)
            leftCommandDown = false
            leftOptionDown = false
            rightCommandDown = false
            rightOptionDown = false
            alternateTriggerState = AlternateModifierTriggerState()
            recoverEventTap()
            return nil

        case .flagsChanged:
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            handleAlternateModifierFlagsChanged(
                keyCode: keyCode,
                flags: event.flags,
                eventTimestamp: event.timestamp
            )

            let flags = event.flags
            let wasCmd = cmdDown
            let wasOpt = optDown
            cmdDown = flags.contains(.maskCommand)
            optDown = flags.contains(.maskAlternate)

            if wasCmd && !cmdDown {
                dispatchToMain { [weak self] in self?.handleModifierRelease(.command) }
            }

            if wasOpt && !optDown {
                dispatchToMain { [weak self] in self?.handleModifierRelease(.option) }
            }

        case .keyDown:
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let shift = event.flags.contains(.maskShift)
            let commandHeld = cmdDown || event.flags.contains(.maskCommand)
            let optionHeld = optDown || event.flags.contains(.maskAlternate)
            let isAutorepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
            alternateTriggerState.noteInterveningKeyDown(now: uptime(for: event.timestamp))

            if keyCode == 53 {
                let wasPendingOrVisible = triggerState.hasPendingTrigger || switcher?.isVisible == true
                clearPendingTrigger()
                if switcher?.isVisible == true {
                    dispatchToMain { [weak self] in
                        self?.switcher?.cancelAndHide()
                    }
                }
                if wasPendingOrVisible { return nil }
            }

            // Tab key — both ⌘Tab and ⌥Tab trigger the same app switcher.
            if keyCode == 48 {
                if commandHeld && !optionHeld {
                    if isAutorepeat && triggerState.hasPendingTrigger && switcher?.isVisible != true {
                        return nil
                    }
                    let triggerUptime = uptime(for: event.timestamp)
                    dispatchToMain { [weak self] in
                        self?.handleTabTrigger(
                            modifier: .command,
                            reverse: shift,
                            triggeredAtUptime: triggerUptime
                        )
                    }
                    return nil
                }

                if optionHeld && !commandHeld {
                    dispatchToMain { [weak self] in
                        self?.handleTabTrigger(modifier: .option, reverse: shift)
                    }
                    return nil
                }
            }

            if let switcher, switcher.isVisible {
                if switcher.currentStyle == .commandPalette {
                    if keyCode == 51 {
                        dispatchToMain { switcher.deleteSearchCharacter() }
                        return nil
                    }

                    if let searchableCharacter = Self.searchablePaletteCharacter(from: event) {
                        dispatchToMain { switcher.appendSearchCharacter(searchableCharacter) }
                        return nil
                    }
                }

                let controlHeld = event.flags.contains(.maskControl)
                let acceptsBareQuickAction = switcher.currentStyle != .commandPalette &&
                    !commandHeld &&
                    !optionHeld &&
                    !controlHeld

                if let action = SwitcherQuickAction.action(
                    forKeyCode: keyCode,
                    keyEquivalent: keyEquivalent(for: event),
                    commandHeld: commandHeld,
                    acceptsBareShortcut: acceptsBareQuickAction
                ) {
                    dispatchToMain { switcher.performQuickAction(action) }
                    return nil
                }

                switch keyCode {
                case 123:
                    dispatchToMain { switcher.moveSelection(by: -1) }
                    return nil
                case 124:
                    dispatchToMain { switcher.moveSelection(by: 1) }
                    return nil
                case 125:
                    dispatchToMain { switcher.moveSelectionDown() }
                    return nil
                case 126:
                    dispatchToMain { switcher.moveSelectionUp() }
                    return nil
                case 36, 76:
                    clearPendingTrigger()
                    dispatchToMain { switcher.confirmAndHide() }
                    return nil
                default:
                    break
                }
            }

        case .keyUp:
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            if keyCode == 48 && (triggerState.hasPendingTrigger || switcher?.isVisible == true) {
                return nil
            }

        default:
            break
        }

        return Unmanaged.passRetained(event)
    }
}

private extension HotkeyManager {
    static func searchablePaletteCharacter(from event: CGEvent) -> String? {
        let flags = event.flags
        guard !flags.contains(.maskAlternate),
              !flags.contains(.maskControl) else {
            return nil
        }

        var charCount: Int = 0
        var charBuffer = [UniChar](repeating: 0, count: 4)
        event.keyboardGetUnicodeString(
            maxStringLength: 4,
            actualStringLength: &charCount,
            unicodeString: &charBuffer
        )

        guard charCount > 0,
              let scalar = Unicode.Scalar(charBuffer[0]),
              scalar.value >= 32,
              scalar.value != 127 else {
            return nil
        }

        return String(scalar)
    }
}

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

enum PhysicalModifierTriggerKey: Equatable {
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

enum AlternateTriggerTapStyle: Equatable {
    case singleTap
    case doubleTap
}

private extension AlternateTriggerMode {
    var monitoredKey: PhysicalModifierTriggerKey? {
        switch self {
        case .disabled:
            return nil
        case .leftCommandDoubleTap:
            return .leftCommand
        case .leftOptionDoubleTap:
            return .leftOption
        case .rightCommandTap, .rightCommandDoubleTap:
            return .rightCommand
        case .rightOptionTap, .rightOptionDoubleTap:
            return .rightOption
        }
    }

    var tapStyle: AlternateTriggerTapStyle? {
        switch self {
        case .disabled:
            return nil
        case .rightCommandTap, .rightOptionTap:
            return .singleTap
        case .rightCommandDoubleTap, .rightOptionDoubleTap, .leftCommandDoubleTap, .leftOptionDoubleTap:
            return .doubleTap
        }
    }
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

struct AlternateModifierTriggerState {
    private var activePress: ActiveAlternateModifierPress?
    private var pendingDoubleTap: PendingAlternateModifierTap?
    private let maximumTapDuration: TimeInterval = 0.28
    private let maximumDoubleTapGap: TimeInterval = 0.40

    mutating func handleModifierChange(
        _ key: PhysicalModifierTriggerKey,
        isDown: Bool,
        mode: AlternateTriggerMode,
        now: TimeInterval
    ) -> Bool {
        pruneExpiredState(now: now)

        guard mode != .disabled,
              mode.monitoredKey == key,
              let tapStyle = mode.tapStyle else {
            if !isDown, activePress?.key == key {
                activePress = nil
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

        guard !press.wasInterrupted,
              now - press.pressedAtUptime <= maximumTapDuration else {
            pendingDoubleTap = nil
            return false
        }

        switch tapStyle {
        case .singleTap:
            pendingDoubleTap = nil
            return true

        case .doubleTap:
            if let pendingDoubleTap,
               pendingDoubleTap.key == key,
               now - pendingDoubleTap.releasedAtUptime <= maximumDoubleTapGap {
                self.pendingDoubleTap = nil
                return true
            }

            pendingDoubleTap = PendingAlternateModifierTap(
                key: key,
                releasedAtUptime: now
            )
            return false
        }
    }

    mutating func noteInterveningKeyDown(now: TimeInterval) {
        pruneExpiredState(now: now)
        guard var activePress else { return }
        activePress.wasInterrupted = true
        self.activePress = activePress
        pendingDoubleTap = nil
    }

    private mutating func pruneExpiredState(now: TimeInterval) {
        if let pendingDoubleTap,
           now - pendingDoubleTap.releasedAtUptime > maximumDoubleTapGap {
            self.pendingDoubleTap = nil
        }
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

    init(modifier: HotkeyModifier, reverse: Bool, startedAtUptime: TimeInterval) {
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
        if let pendingTrigger, pendingTrigger.shouldIgnoreRepeatedTab(for: modifier) {
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
        guard let trigger = pendingTrigger, now >= trigger.revealAtUptime else {
            return nil
        }

        guard heldModifiers.contains(trigger.modifier) else {
            pendingTrigger = nil
            return actionForHiddenRelease(of: trigger)
        }

        return .showOverlay(reverse: trigger.reverse, modifier: trigger.modifier)
    }

    mutating func handleModifierRelease(
        _ modifier: HotkeyModifier,
        switcherVisible: Bool
    ) -> HotkeyTriggerAction? {
        guard let trigger = pendingTrigger, trigger.modifier == modifier else {
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

    private func actionForHiddenRelease(of trigger: PendingHotkeyTrigger) -> HotkeyTriggerAction? {
        switch trigger.policy.earlyReleaseAction {
        case .none:
            return nil
        case .quickSwitch:
            return .quickSwitch(reverse: trigger.reverse)
        }
    }
}
