import AppKit
import CoreGraphics
import os.log

private let profileHotkeyLog = OSLog(
    subsystem: "CmdTab",
    category: "ProfileHotkeyManager"
)

/// Global event-tap router for versioned switcher shortcut profiles.
///
/// The callback performs only matching and primitive state transitions. Every
/// UI, Accessibility, and timer side effect is dispatched asynchronously to the
/// main queue so the event tap remains below the system timeout threshold.
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

    private var timingState = ProfileHotkeyTimingState()
    private var shortcutChordTimingState = ShortcutChordTimingState()
    private var physicalChordTimingState = PhysicalModifierChordTimingState()
    private var commandModifierDown = false
    private var optionModifierDown = false

    /// Contains only key-downs CmdTab actually swallowed. A passed-through
    /// shortcut must receive its original key-up or the native/system shortcut
    /// can become stuck.
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

    /// Called before click-based commits so the follow-up modifier release cannot
    /// trigger a second activation.
    func clearTriggerStateFromClickCommit() {
        resetInteractionState(
            cancelVisibleSession: false,
            preserveSwallowedKeyUps: true
        )
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
                guard let refcon else {
                    return Unmanaged.passRetained(event)
                }
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

        let source = CFMachPortCreateRunLoopSource(
            kCFAllocatorDefault,
            tap,
            0
        )
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
            CFRunLoopRemoveSource(
                CFRunLoopGetMain(),
                runLoopSource,
                .commonModes
            )
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
        // Preserve event-pair integrity before entering a protected/recording
        // surface. A key-down swallowed by CmdTab must never leak an unmatched
        // key-up to the native shortcut owner.
        if type == .keyUp {
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            if swallowedKeyCodes.remove(keyCode) != nil {
                if SecureInputMonitor.isEnabled ||
                    ShortcutRecordingState.shared.isRecording {
                    resetInteractionState(
                        cancelVisibleSession: true,
                        preserveSwallowedKeyUps: true
                    )
                }
                return nil
            }
        }

        if isKeyboardEvent(type), SecureInputMonitor.isEnabled {
            resetInteractionState(
                cancelVisibleSession: true,
                preserveSwallowedKeyUps: true
            )
            return Unmanaged.passRetained(event)
        }

        if isKeyboardEvent(type), ShortcutRecordingState.shared.isRecording {
            // The AppKit recorder owns new key pairs. Cancel stale global state,
            // while retaining only key-ups for key-downs already swallowed.
            resetInteractionState(
                cancelVisibleSession: true,
                preserveSwallowedKeyUps: true
            )
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
            let now = eventUptime(event)
            updateShortcutModifierTiming(flags: event.flags, now: now)
            handleAlternateModifierChange(event, now: now)
            handleProfileModifierRelease(flags: event.flags)
            return Unmanaged.passRetained(event)

        case .keyDown:
            guard !shouldBypassForActiveTextInput() else {
                resetInteractionState(
                    cancelVisibleSession: false,
                    preserveSwallowedKeyUps: true
                )
                return Unmanaged.passRetained(event)
            }
            alternateTriggerState.noteInterveningKeyDown(
                now: eventUptime(event)
            )
            return handleKeyDown(event)

        case .keyUp:
            return Unmanaged.passRetained(event)

        case .scrollWheel:
            guard switcher?.isVisible == true else {
                return Unmanaged.passRetained(event)
            }
            let delta = event.getDoubleValueField(
                .scrollWheelEventPointDeltaAxis1
            )
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

        // Standard application commands must always win over custom profiles and
        // over any stale release owner. This explicitly protects Paste (Command-V)
        // and the other Command/Shift-Command character commands from switching.
        if Self.isProtectedApplicationCommand(
            keyCode: keyCode,
            flags: event.flags
        ) {
            handlePassThroughKeyDown(
                keyCode: keyCode,
                cancelVisibleSession: true
            )
            return Unmanaged.passRetained(event)
        }

        guard let match = profileStore.match(
            keyCode: keyCode,
            flags: event.flags
        ) else {
            handlePassThroughKeyDown(
                keyCode: keyCode,
                cancelVisibleSession: false
            )
            return Unmanaged.passRetained(event)
        }

        let shouldHandleShortcut = MainActor.assumeIsolated {
            LicensingController.shared.shouldHandleCustomSwitcherShortcut()
        }
        guard shouldHandleShortcut else {
            handlePassThroughKeyDown(
                keyCode: keyCode,
                cancelVisibleSession: false
            )
            return Unmanaged.passRetained(event)
        }

        let triggerUptime = eventUptime(event)
        let isVisible = switcher?.isVisible == true

        // A hidden session is started by one deliberate chord. Key repeat or an
        // additional delayed Tab while the original trigger is pending is consumed
        // without replacing the original direction or reveal deadline.
        if !isVisible, timingState.hasPendingTrigger {
            swallowedKeyCodes.insert(keyCode)
            return nil
        }

        if !isVisible,
           !shortcutChordTimingState.accepts(
               primaryModifier: match.primaryModifier,
               keyDownAt: triggerUptime
           ) {
            swallowedKeyCodes.insert(keyCode)
            shortcutChordTimingState.noteInterveningKeyDown()
            timingState.cancel()
            configurationFreeze.end()
            os_log(
                .info,
                log: profileHotkeyLog,
                "Ignored delayed or interrupted shortcut chord for profile %{public}@",
                match.profileID.uuidString
            )
            return nil
        }

        let sameVisibleProfile = isVisible &&
            switcher?.activeProfileID == match.profileID
        configurationFreeze.begin(
            profileID: match.profileID,
            preserveExisting: sameVisibleProfile
        )
        swallowedKeyCodes.insert(keyCode)

        if isVisible {
            cancelScheduledReveal()
            if match.releaseBehavior == .holdPrimaryModifier {
                if timingState.pendingMatch?.profileID != match.profileID {
                    timingState.beginVisibleTrigger(
                        match: match,
                        startedAtUptime: triggerUptime
                    )
                }
            } else {
                timingState.cancel()
            }
            dispatchToMain { [weak self] in
                self?.switcher?.showOrAdvance(
                    reverse: match.reverse,
                    profileID: match.profileID
                )
            }
            return nil
        }

        switch match.releaseBehavior {
        case .pressToToggle:
            if !isRepeat {
                dispatchToMain { [weak self] in
                    self?.switcher?.showOrAdvance(
                        reverse: match.reverse,
                        profileID: match.profileID
                    )
                }
            }

        case .holdPrimaryModifier:
            guard let action = timingState.registerHiddenTrigger(
                match: match,
                startedAtUptime: triggerUptime,
                isRepeat: isRepeat
            ) else {
                return nil
            }
            performTimingAction(action)
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
            resetInteractionState(
                cancelVisibleSession: false,
                preserveSwallowedKeyUps: true
            )
            dispatchToMain { switcher.cancelAndHide() }
            return true
        case 36, 76:
            resetInteractionState(
                cancelVisibleSession: false,
                preserveSwallowedKeyUps: true
            )
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

    // MARK: Deterministic hold/release timing

    private func performTimingAction(_ action: ProfileHotkeyTimingAction) {
        switch action {
        case let .scheduleReveal(atUptime):
            dispatchToMain { [weak self] in
                self?.scheduleReveal(atUptime: atUptime)
            }

        case let .showOverlay(match):
            dispatchToMain { [weak self] in
                guard let self else { return }
                self.switcher?.showOrAdvance(
                    reverse: match.reverse,
                    profileID: match.profileID
                )
                self.schedulePostShowReleaseCheck(match)
            }

        case let .quickSwitch(match):
            dispatchToMain { [weak self] in
                guard let self else { return }
                self.clearCompletedProfileTriggerState()
                self.switcher?.commitTriggerSession(
                    reverse: match.reverse,
                    profileID: match.profileID
                )
                self.configurationFreeze.end()
            }

        case let .confirmSelection(match):
            dispatchToMain { [weak self] in
                guard let self else { return }
                guard self.switcher?.activeProfileID == match.profileID else {
                    self.clearCompletedProfileTriggerState()
                    self.configurationFreeze.end()
                    return
                }
                self.clearCompletedProfileTriggerState()
                self.switcher?.confirmAndHide()
                self.configurationFreeze.end()
            }
        }
    }

    private func scheduleReveal(atUptime: TimeInterval) {
        cancelScheduledReveal()
        let delay = max(0, atUptime - currentUptime())
        if delay <= 0 {
            handleScheduledReveal()
            return
        }

        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.showUIWorkItem = nil
            self.handleScheduledReveal()
        }
        showUIWorkItem = item
        DispatchQueue.main.asyncAfter(
            deadline: .now() + delay,
            execute: item
        )
    }

    private func handleScheduledReveal() {
        guard let action = timingState.handleRevealDeadline(
            now: currentUptime(),
            heldModifiers: liveHeldModifiers()
        ) else {
            return
        }
        performTimingAction(action)
    }

    private func handleProfileModifierRelease(flags: CGEventFlags) {
        guard let modifier = timingState.pendingModifier,
              !modifier.isHeld(in: flags) else {
            return
        }
        cancelScheduledReveal()
        guard let action = timingState.handleModifierRelease(
            modifier,
            switcherVisible: switcher?.isVisible == true,
            activeProfileID: switcher?.activeProfileID
        ) else {
            configurationFreeze.end()
            return
        }
        performTimingAction(action)
    }

    private func schedulePostShowReleaseCheck(_ match: ShortcutProfileMatch) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self,
                  self.timingState.pendingMatch == match,
                  let modifier = match.primaryModifier,
                  !modifier.isHeld(in: NSEvent.modifierFlags) else {
                return
            }
            self.cancelScheduledReveal()
            if let action = self.timingState.handleModifierRelease(
                modifier,
                switcherVisible: self.switcher?.isVisible == true,
                activeProfileID: self.switcher?.activeProfileID
            ) {
                self.performTimingAction(action)
            }
        }
    }

    private func cancelScheduledReveal() {
        showUIWorkItem?.cancel()
        showUIWorkItem = nil
    }

    private func liveHeldModifiers() -> Set<HotkeyModifier> {
        let flags = NSEvent.modifierFlags
        var held = Set<HotkeyModifier>()
        if flags.contains(.command) { held.insert(.command) }
        if flags.contains(.option) { held.insert(.option) }
        return held
    }

    // MARK: Compatibility alternate trigger

    private func handleAlternateModifierChange(
        _ event: CGEvent,
        now: TimeInterval
    ) {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard let key = PhysicalModifierTriggerKey(
            flagsChangedKeyCode: keyCode
        ) else {
            return
        }

        let isDown = toggleModifierState(for: key)
        physicalChordTimingState.noteModifierChange(
            key,
            isDown: isDown,
            at: now
        )
        let mode = preferences.alternateTrigger
        let shouldActivate = alternateTriggerState.handleModifierChange(
            key,
            isDown: isDown,
            mode: mode,
            leftCommandDown: leftCommandDown,
            leftOptionDown: leftOptionDown,
            rightCommandDown: rightCommandDown,
            rightOptionDown: rightOptionDown,
            now: now
        )
        guard shouldActivate else { return }

        if let requiredKeys = mode.simultaneousChordKeys,
           !physicalChordTimingState.accepts(keys: requiredKeys) {
            os_log(
                .info,
                log: profileHotkeyLog,
                "Ignored delayed Hot Swap modifier chord"
            )
            return
        }

        let shouldHandleShortcut = MainActor.assumeIsolated {
            LicensingController.shared.shouldHandleCustomSwitcherShortcut()
        }
        guard shouldHandleShortcut else { return }

        dispatchToMain { [weak self] in
            guard let self else { return }
            if self.switcher?.isVisible == true {
                self.resetInteractionState(cancelVisibleSession: false)
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

    private func updateShortcutModifierTiming(
        flags: CGEventFlags,
        now: TimeInterval
    ) {
        let commandDown = flags.contains(.maskCommand)
        if commandDown != commandModifierDown {
            commandModifierDown = commandDown
            shortcutChordTimingState.noteModifierChange(
                .command,
                isDown: commandDown,
                at: now
            )
        }

        let optionDown = flags.contains(.maskAlternate)
        if optionDown != optionModifierDown {
            optionModifierDown = optionDown
            shortcutChordTimingState.noteModifierChange(
                .option,
                isDown: optionDown,
                at: now
            )
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

    /// A key that is not being consumed by a valid switcher action disarms any
    /// pending profile trigger before the key is passed back to macOS. Without
    /// this boundary, a missed Command release could leave stale release ownership,
    /// and releasing Command after Command-V could switch back to the prior window.
    private func handlePassThroughKeyDown(
        keyCode: Int64,
        cancelVisibleSession: Bool
    ) {
        shortcutChordTimingState.noteInterveningKeyDown()
        let hadPendingTrigger = timingState.hasPendingTrigger || showUIWorkItem != nil
        cancelScheduledReveal()
        timingState.cancel()
        configurationFreeze.end()

        if hadPendingTrigger {
            os_log(
                .info,
                log: profileHotkeyLog,
                "Cancelled stale switcher trigger before passing key %{public}lld through",
                keyCode
            )
        }

        guard cancelVisibleSession, switcher?.isVisible == true else { return }
        dispatchToMain { [weak self] in
            self?.switcher?.cancelAndHide()
        }
    }

    /// Clears only the completed profile gesture. The immutable configuration
    /// remains frozen until the controller has consumed the commit action.
    private func clearCompletedProfileTriggerState() {
        cancelScheduledReveal()
        timingState.cancel()
        shortcutChordTimingState.reset()
        physicalChordTimingState.reset()
        commandModifierDown = false
        optionModifierDown = false
        alternateTriggerState.noteStandardShortcut(now: currentUptime())
    }

    /// Command and Shift-Command character shortcuts are application commands,
    /// not global switcher triggers. Command-Tab and Shift-Command-Tab remain the
    /// only character-key exceptions; function-key profiles remain available.
    private static func isProtectedApplicationCommand(
        keyCode: Int64,
        flags: CGEventFlags
    ) -> Bool {
        let modifiers = ShortcutModifierMask(eventFlags: flags)
        guard modifiers.contains(.command),
              modifiers.subtracting([.command, .shift]).isEmpty,
              keyCode != RecordedShortcut.commandTab.keyCode else {
            return false
        }
        return !functionKeyCodes.contains(keyCode)
    }

    private static let functionKeyCodes: Set<Int64> = [
        122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111,
        105, 107, 113, 106, 64, 79, 80, 90,
    ]

    private func resetInteractionState(
        cancelVisibleSession: Bool,
        preserveSwallowedKeyUps: Bool = false
    ) {
        cancelScheduledReveal()
        configurationFreeze.end()
        timingState.cancel()
        shortcutChordTimingState.reset()
        physicalChordTimingState.reset()
        commandModifierDown = false
        optionModifierDown = false
        if !preserveSwallowedKeyUps {
            swallowedKeyCodes.removeAll()
        }
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
