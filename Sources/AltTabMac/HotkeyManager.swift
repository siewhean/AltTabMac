import AppKit
import CoreGraphics
import os.log

private let hotkeyLog = OSLog(subsystem: "AltTabMac", category: "HotkeyManager")

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
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private var cmdDown = false
    private var optDown = false
    private var showUIWorkItem: DispatchWorkItem?
    private var triggerState = HotkeyTriggerState()
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
            print("[AltTabMac] ⚠️  Failed to create CGEventTap. Grant Accessibility in System Settings > Privacy.")
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
            recoverEventTap()
            return nil

        case .flagsChanged:
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
            let isAutorepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0

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
                if cmdDown && !optDown {
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

                if optDown && !cmdDown {
                    dispatchToMain { [weak self] in
                        self?.handleTabTrigger(modifier: .option, reverse: shift)
                    }
                    return nil
                }
            }

            if let switcher, switcher.isVisible {
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

                if switcher.currentStyle == .commandPalette {
                    if keyCode == 51 {
                        dispatchToMain { switcher.deleteSearchCharacter() }
                        return nil
                    }

                    var charCount: Int = 0
                    var charBuffer = [UniChar](repeating: 0, count: 4)
                    event.keyboardGetUnicodeString(
                        maxStringLength: 4,
                        actualStringLength: &charCount,
                        unicodeString: &charBuffer
                    )
                    if charCount > 0,
                       let scalar = Unicode.Scalar(charBuffer[0]),
                       scalar.value >= 32,
                       scalar.value != 127 {
                        let safeChar = String(scalar)
                        dispatchToMain { switcher.appendSearchCharacter(safeChar) }
                        return nil
                    }
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

enum HotkeyEarlyReleaseAction: Equatable {
    case none
    case quickSwitch
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
