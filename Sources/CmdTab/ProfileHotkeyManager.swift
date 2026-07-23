import AppKit
import CoreGraphics
import os.log

private let profileHotkeyLog = OSLog(subsystem: "CmdTab", category: "ProfileHotkeyManager")

enum ProfileHotkeyTriggerAction: Equatable {
    case scheduleReveal(atUptime: TimeInterval)
    case showOverlay(ShortcutProfileMatch)
    case quickSwitch(ShortcutProfileMatch)
    case confirmSelection(ShortcutProfileMatch)
}

/// Adapts the proven Phase 1 hidden-trigger state machine to profile-scoped
/// shortcuts without losing the profile identity needed for the eventual show,
/// quick-switch, or commit action.
struct ProfileHotkeyTriggerCoordinator {
    private var state = HotkeyTriggerState()
    private(set) var pendingMatch: ShortcutProfileMatch?

    var hasPendingTrigger: Bool { state.hasPendingTrigger }
    var pendingModifier: HotkeyModifier? { state.pendingModifier }

    mutating func registerHiddenTrigger(
        match: ShortcutProfileMatch,
        startedAtUptime: TimeInterval
    ) -> ProfileHotkeyTriggerAction? {
        guard let modifier = match.primaryModifier else { return nil }

        if let pendingMatch, pendingMatch.profileID != match.profileID {
            cancel()
        }

        let action = state.registerHiddenTabTrigger(
            modifier: modifier,
            reverse: match.reverse,
            startedAtUptime: startedAtUptime
        )
        guard let action else {
            // Command-repeat suppression intentionally keeps the first trigger and
            // its original profile/reverse direction intact.
            return nil
        }

        pendingMatch = match
        return mapped(action, using: match)
    }

    mutating func handleRevealDeadline(
        now: TimeInterval,
        heldModifiers: Set<HotkeyModifier>
    ) -> ProfileHotkeyTriggerAction? {
        guard let match = pendingMatch,
              let action = state.handleRevealDeadline(
                now: now,
                heldModifiers: heldModifiers
              ) else {
            return nil
        }

        let mappedAction = mapped(action, using: match)
        if !state.hasPendingTrigger {
            pendingMatch = nil
        }
        return mappedAction
    }

    mutating func handleModifierRelease(
        _ modifier: HotkeyModifier,
        switcherVisible: Bool
    ) -> ProfileHotkeyTriggerAction? {
        guard let match = pendingMatch,
              let action = state.handleModifierRelease(
                modifier,
                switcherVisible: switcherVisible
              ) else {
            return nil
        }

        let mappedAction = mapped(action, using: match)
        pendingMatch = nil
        return mappedAction
    }

    mutating func cancel() {
        state.cancelPendingTrigger()
        pendingMatch = nil
    }

    private func mapped(
        _ action: HotkeyTriggerAction,
        using match: ShortcutProfileMatch
    ) -> ProfileHotkeyTriggerAction {
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

/// Global event-tap router for versioned switcher shortcut profiles.
/// The callback performs only lock-protected matching and primitive state work;
/// all UI and Accessibility side effects are dispatched to the main queue.
final class ProfileHotkeyManager {
    private weak var switcher: ProductionSwitcherWindowController?
    private let profileStore: SwitcherProfileStore
    private let preferences = SwitcherPreferences.shared
    private let configurationFreeze = SwitcherSessionConfigurationFreeze.shared
    private let currentUptime: () -> TimeInterval

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var installRetryWorkItem: DispatchWorkItem?
    private var showUIWorkItem: DispatchWorkItem?
    private let installRetryDelay: TimeInterval = 1.0

    private var holdTriggerCoordinator = ProfileHotkeyTriggerCoordinator()
    /// Contains only key-downs CmdTab actually swallowed. A passed-through
    /// shortcut (for example while licensing is unavailable) must also receive
    /// its original key-up or the native/system shortcut can become stuck.
    private var swallowedKeyCodes = Set<Int64>()
    private var alternateTriggerState = AlternateModifierTriggerState()
    private var leftCommandDown = false
    private var leftOptionDown = false
    private var rightCommandDown = false
    private var rightOptionDown = false

    init(
        switcher: ProductionSwitcherWindowController,
        profileStore: SwitcherProfileStore = .shared,
        currentUptime: @escaping () -> TimeInterval = {
            ProcessInfo.processInfo.systemUptime
        }
    ) {
        self.switcher = switcher
        self.profileStore = profileStore
        self.currentUptime = currentUptime
        installOrScheduleRetry()
    }

    deinit {
        configurationFreeze.end()
        installRetryWorkItem?.cancel()
        showUIWorkItem?.cancel()
        uninstallTap()
    }

    func clearTriggerStateFromClickCommit() {
        configurationFreeze.end()
        resetInteractionState(cancelVisibleSession: false)
    }

    // MARK: Event-tap lifecycle

    private func installOrScheduleRetry() {
        guard eventTap == nil else { return }
        guard AXIsProcessTrusted() else {
            scheduleInstallRetry()
            return
        }
        install()
        if eventTap == nil {
            scheduleInstallRetry()
        }
    }

    private func scheduleInstallRetry() {
        guard installRetryWorkItem == nil else { return }
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.installRetryWorkItem = nil
            self.installOrScheduleRetry()
        }
        installRetryWorkItem = item
        DispatchQueue.main.asyncAfter(
            deadline: .now() + installRetryDelay,
            execute: item
        )
    }

    private func install() {
        guard eventTap == nil else { return }
        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.scrollWheel.rawValue)
        let pointer = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passRetained(event) }
                let manager = Unmanaged<ProfileHotkeyManager>
                    .fromOpaque(refcon)
                    .takeUnretainedValue()
                return manager.handle(type: type, event: event)
            },
            userInfo: pointer
        ) else {
            os_log(
                .error,
                log: profileHotkeyLog,
                "Could not create event tap; Accessibility may be unavailable"
            )
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        eventTap = tap
        runLoopSource = source
        installRetryWorkItem?.cancel()
        installRetryWorkItem = nil
        os_log(.info, log: profileHotkeyLog, "Profile event tap installed")
    }

    private func uninstallTap() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    // MARK: Event routing

    private func handle(
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        let started = DispatchTime.now().uptimeNanoseconds
        let result = handleInner(type: type, event: event)
        let elapsed = DispatchTime.now().uptimeNanoseconds - started
        if elapsed > 5_000_000 {
            os_log(
                .info,
                log: profileHotkeyLog,
                "Profile event-tap callback took %.2f ms (target < 20 ms)",
                Double(elapsed) / 1_000_000
            )
        }
        return result
    }

    private func handleInner(
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        if isKeyboardEvent(type), SecureInputMonitor.isEnabled {
            // Do not inspect or retain protected keystrokes. A stale switcher
            // must not remain above a password or other secure-entry surface.
            resetInteractionState(cancelVisibleSession: true)
            return Unmanaged.passRetained(event)
        }

        if isKeyboardEvent(type), ShortcutRecordingState.shared.isRecording {
            // The AppKit recorder owns the original key-down and key-up pair.
            return Unmanaged.passRetained(event)
        }

        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            resetInteractionState(cancelVisibleSession: true)
            if let eventTap, AXIsProcessTrusted() {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            } else {
                dispatchToMain { [weak self] in
                    self?.uninstallTap()
                    self?.scheduleInstallRetry()
                }
            }
            return nil

        case .flagsChanged:
            handleAlternateModifierChange(event)
            handleHoldModifierRelease(flags: event.flags)
            return Unmanaged.passRetained(event)

        case .keyDown:
            guard !shouldBypassForActiveTextInput() else {
                return Unmanaged.passRetained(event)
            }
            alternateTriggerState.noteInterveningKeyDown(
                now: eventUptime(event)
            )
            return handleKeyDown(event)

        case .keyUp:
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            return swallowedKeyCodes.remove(keyCode) != nil
                ? nil
                : Unmanaged.passRetained(event)

        case .scrollWheel:
            guard switcher?.isVisible == true else {
                return Unmanaged.passRetained(event)
            }
            let delta = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1)
            if abs(delta) >= 1 {
                dispatchToMain { [weak self] in
                    self?.switcher?.moveSelection(by: delta > 0 ? -1 : 1)
                }
            }
            return nil

        default:
            return Unmanaged.passRetained(event)
        }
    }

    private func handleKeyDown(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0

        if handleVisibleSwitcherKey(event, keyCode: keyCode) {
            return nil
        }

        guard let match = profileStore.match(
            keyCode: keyCode,
            flags: event.flags
        ) else {
            return Unmanaged.passRetained(event)
        }

        let shouldHandleShortcut = MainActor.assumeIsolated {
            LicensingController.shared.shouldHandleCustomSwitcherShortcut()
        }
        guard shouldHandleShortcut else {
            // The native/system shortcut receives both event halves because this
            // key code is never inserted into `swallowedKeyCodes`.
            return Unmanaged.passRetained(event)
        }

        swallowedKeyCodes.insert(keyCode)

        switch match.releaseBehavior {
        case .pressToToggle:
            guard !isRepeat else { return nil }
            let preserveExisting = switcher?.isVisible == true &&
                switcher?.activeProfileID == match.profileID
            configurationFreeze.begin(
                profileID: match.profileID,
                preserveExisting: preserveExisting
            )
            dispatchToMain { [weak self] in
                self?.switcher?.showOrAdvance(
                    reverse: match.reverse,
                    profileID: match.profileID
                )
            }

        case .holdPrimaryModifier:
            guard let primary = match.primaryModifier else { return nil }

            if switcher?.isVisible == true,
               switcher?.activeProfileID == match.profileID {
                configurationFreeze.begin(
                    profileID: match.profileID,
                    preserveExisting: true
                )
                ensureVisibleHoldTrigger(
                    match,
                    primary: primary,
                    startedAtUptime: eventUptime(event)
                )
                dispatchToMain { [weak self] in
                    self?.switcher?.showOrAdvance(
                        reverse: match.reverse,
                        profileID: match.profileID
                    )
                }
                schedulePostShowReleaseCheck(match)
                return nil
            }

            let preserveExisting = holdTriggerCoordinator.pendingMatch?.profileID == match.profileID
            guard let action = holdTriggerCoordinator.registerHiddenTrigger(
                match: match,
                startedAtUptime: eventUptime(event)
            ) else {
                return nil
            }
            configurationFreeze.begin(
                profileID: match.profileID,
                preserveExisting: preserveExisting
            )
            performHoldTriggerAction(action)
        }
        return nil
    }

    private func handleVisibleSwitcherKey(
        _ event: CGEvent,
        keyCode: Int64
    ) -> Bool {
        guard let switcher, switcher.isVisible else { return false }

        switch keyCode {
        case 53:
            cancelPendingHoldTrigger()
            configurationFreeze.end()
            dispatchToMain { switcher.cancelAndHide() }
            return true
        case 36, 76:
            cancelPendingHoldTrigger()
            configurationFreeze.end()
            dispatchToMain { switcher.confirmAndHide() }
            return true
        case 123:
            dispatchToMain { switcher.moveSelection(by: -1) }
            return true
        case 124:
            dispatchToMain { switcher.moveSelection(by: 1) }
            return true
        case 125:
            dispatchToMain { switcher.moveSelectionDown() }
            return true
        case 126:
            dispatchToMain { switcher.moveSelectionUp() }
            return true
        default:
            break
        }

        if switcher.currentStyle == .commandPalette {
            if keyCode == 51 {
                dispatchToMain { switcher.deleteSearchCharacter() }
                return true
            }
            if let character = searchableCharacter(from: event) {
                dispatchToMain { switcher.appendSearchCharacter(character) }
                return true
            }
            return false
        }

        let commandHeld = event.flags.contains(.maskCommand)
        let acceptsBare = !commandHeld &&
            !event.flags.contains(.maskAlternate) &&
            !event.flags.contains(.maskControl)
        guard let action = SwitcherQuickAction.action(
            forKeyCode: keyCode,
            keyEquivalent: keyEquivalent(for: event),
            commandHeld: commandHeld,
            acceptsBareShortcut: acceptsBare
        ) else {
            return false
        }
        dispatchToMain { switcher.performQuickAction(action) }
        return true
    }

    // MARK: Proven hold/quick-switch routing

    private func cancelScheduledReveal() {
        showUIWorkItem?.cancel()
        showUIWorkItem = nil
    }

    private func cancelPendingHoldTrigger() {
        cancelScheduledReveal()
        holdTriggerCoordinator.cancel()
    }

    private func scheduleReveal(for revealAtUptime: TimeInterval) {
        cancelScheduledReveal()
        let delay = max(0, revealAtUptime - currentUptime())
        if delay <= 0 {
            dispatchToMain { [weak self] in
                self?.handleScheduledReveal()
            }
            return
        }

        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.showUIWorkItem = nil
            self.handleScheduledReveal()
        }
        showUIWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private func handleScheduledReveal() {
        guard let action = holdTriggerCoordinator.handleRevealDeadline(
            now: currentUptime(),
            heldModifiers: liveHeldModifiers()
        ) else {
            return
        }
        performHoldTriggerAction(action)
    }

    private func liveHeldModifiers() -> Set<HotkeyModifier> {
        let flags = NSEvent.modifierFlags
        var held = Set<HotkeyModifier>()
        if flags.contains(.command) { held.insert(.command) }
        if flags.contains(.option) { held.insert(.option) }
        return held
    }

    private func ensureVisibleHoldTrigger(
        _ match: ShortcutProfileMatch,
        primary: HotkeyModifier,
        startedAtUptime: TimeInterval
    ) {
        guard holdTriggerCoordinator.pendingMatch?.profileID != match.profileID else {
            return
        }
        cancelPendingHoldTrigger()
        guard let action = holdTriggerCoordinator.registerHiddenTrigger(
            match: match,
            startedAtUptime: startedAtUptime
        ) else {
            return
        }
        switch action {
        case .scheduleReveal:
            _ = holdTriggerCoordinator.handleRevealDeadline(
                now: startedAtUptime,
                heldModifiers: [primary]
            )
        case .showOverlay, .quickSwitch, .confirmSelection:
            break
        }
    }

    private func performHoldTriggerAction(_ action: ProfileHotkeyTriggerAction) {
        switch action {
        case let .scheduleReveal(atUptime):
            scheduleReveal(for: atUptime)

        case let .showOverlay(match):
            dispatchToMain { [weak self] in
                self?.switcher?.showOrAdvance(
                    reverse: match.reverse,
                    profileID: match.profileID
                )
                self?.schedulePostShowReleaseCheck(match)
            }

        case let .quickSwitch(match):
            cancelScheduledReveal()
            dispatchToMain { [weak self] in
                guard let self else { return }
                defer { self.configurationFreeze.end() }
                self.switcher?.commitTriggerSession(
                    reverse: match.reverse,
                    profileID: match.profileID
                )
            }

        case let .confirmSelection(match):
            cancelScheduledReveal()
            configurationFreeze.end()
            dispatchToMain { [weak self] in
                guard self?.switcher?.activeProfileID == match.profileID,
                      self?.switcher?.activeReleaseBehavior == .holdPrimaryModifier else {
                    return
                }
                self?.switcher?.confirmAndHide()
            }
        }
    }

    private func handleHoldModifierRelease(flags: CGEventFlags) {
        guard let modifier = holdTriggerCoordinator.pendingModifier,
              !modifier.isHeld(in: flags),
              let action = holdTriggerCoordinator.handleModifierRelease(
                modifier,
                switcherVisible: switcher?.isVisible == true
              ) else {
            return
        }
        performHoldTriggerAction(action)
    }

    private func schedulePostShowReleaseCheck(_ match: ShortcutProfileMatch) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self,
                  self.holdTriggerCoordinator.pendingMatch == match,
                  let primary = match.primaryModifier,
                  !primary.isHeld(in: NSEvent.modifierFlags),
                  let action = self.holdTriggerCoordinator.handleModifierRelease(
                    primary,
                    switcherVisible: self.switcher?.isVisible == true
                  ) else {
                return
            }
            self.performHoldTriggerAction(action)
        }
    }

    // MARK: Compatibility trigger

    private func handleAlternateModifierChange(_ event: CGEvent) {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard let key = PhysicalModifierTriggerKey(
            flagsChangedKeyCode: keyCode
        ) else {
            return
        }

        let isDown = toggleModifierState(for: key)
        let shouldActivate = alternateTriggerState.handleModifierChange(
            key,
            isDown: isDown,
            mode: preferences.alternateTrigger,
            leftCommandDown: leftCommandDown,
            leftOptionDown: leftOptionDown,
            rightCommandDown: rightCommandDown,
            rightOptionDown: rightOptionDown,
            now: eventUptime(event)
        )
        guard shouldActivate else { return }

        let shouldHandleShortcut = MainActor.assumeIsolated {
            LicensingController.shared.shouldHandleCustomSwitcherShortcut()
        }
        guard shouldHandleShortcut else { return }

        dispatchToMain { [weak self] in
            guard let self else { return }
            if self.switcher?.isVisible == true {
                self.cancelPendingHoldTrigger()
                self.configurationFreeze.end()
                self.switcher?.confirmAndHide()
                return
            }

            guard let profileID = self.profileStore
                .profilesSnapshot()
                .first(where: \.isEnabled)?
                .id else {
                return
            }
            self.configurationFreeze.begin(
                profileID: profileID,
                preserveExisting: false
            )
            self.switcher?.commitTriggerSession(
                reverse: false,
                profileID: profileID
            )
            self.configurationFreeze.end()
        }
    }

    private func toggleModifierState(
        for key: PhysicalModifierTriggerKey
    ) -> Bool {
        switch key {
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

    // MARK: Safety helpers

    private func resetInteractionState(cancelVisibleSession: Bool) {
        configurationFreeze.end()
        cancelPendingHoldTrigger()
        swallowedKeyCodes.removeAll()
        alternateTriggerState = AlternateModifierTriggerState()
        leftCommandDown = false
        leftOptionDown = false
        rightCommandDown = false
        rightOptionDown = false

        guard cancelVisibleSession, switcher?.isVisible == true else { return }
        dispatchToMain { [weak self] in
            self?.switcher?.cancelAndHide()
        }
    }

    private func isKeyboardEvent(_ type: CGEventType) -> Bool {
        type == .keyDown || type == .keyUp || type == .flagsChanged
    }

    private func shouldBypassForActiveTextInput() -> Bool {
        MainActor.assumeIsolated {
            guard NSApp.isActive else { return false }
            return NSApp.windows.contains { window in
                guard window.isVisible else { return false }
                return window.firstResponder is NSTextView ||
                    window.firstResponder is NSTextField
            }
        }
    }

    private func eventUptime(_ event: CGEvent) -> TimeInterval {
        TimeInterval(event.timestamp) / 1_000_000_000
    }

    private func keyEquivalent(for event: CGEvent) -> String? {
        var count = 0
        var buffer = [UniChar](repeating: 0, count: 4)
        event.keyboardGetUnicodeString(
            maxStringLength: buffer.count,
            actualStringLength: &count,
            unicodeString: &buffer
        )
        guard count > 0 else { return nil }
        return String(utf16CodeUnits: buffer, count: count)
    }

    private func searchableCharacter(from event: CGEvent) -> String? {
        let flags = event.flags
        guard !flags.contains(.maskAlternate),
              !flags.contains(.maskControl),
              !flags.contains(.maskCommand),
              let value = keyEquivalent(for: event),
              value.count == 1,
              let scalar = value.unicodeScalars.first,
              scalar.value >= 32,
              scalar.value != 127 else {
            return nil
        }
        return value
    }

    private func dispatchToMain(_ work: @escaping () -> Void) {
        DispatchQueue.main.async(execute: work)
    }
}

private extension HotkeyModifier {
    func isHeld(in flags: CGEventFlags) -> Bool {
        switch self {
        case .command: return flags.contains(.maskCommand)
        case .option: return flags.contains(.maskAlternate)
        }
    }
}
