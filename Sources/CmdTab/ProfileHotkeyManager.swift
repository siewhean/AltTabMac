import AppKit
import CoreGraphics
import os.log

private let profileHotkeyLog = OSLog(
    subsystem: "CmdTab",
    category: "ProfileHotkeyManager"
)

/// Global event-tap router for versioned switcher shortcut profiles.
///
/// The tap runs on `EventTapRunLoopThread`, never on the main thread, so
/// keystrokes system-wide do not wait for CmdTab's UI or Accessibility work.
/// The callback performs only matching and primitive state transitions; every
/// UI and Accessibility side effect is dispatched asynchronously to the main
/// queue. Main-thread facts are read from thread-safe mirrors
/// (`SwitcherInputMirror`, `EventTapLicensingGate`). All router state is guarded
/// by `stateLock`; main-thread entry points take it only around state changes,
/// never while calling into the switcher, so the tap never waits on main.
final class ProfileHotkeyManager {
    private weak var switcher: ProductionSwitcherWindowController?
    private let inputMirror: SwitcherInputMirror
    private let licensingGate: EventTapLicensingGate
    private let tapThread = EventTapRunLoopThread.shared
    private let stateLock = NSRecursiveLock()
    private let timerQueue = DispatchQueue(label: "CmdTab.ProfileHotkeyTimers", qos: .userInteractive)
    private let profileStore: SwitcherProfileStore
    private let preferences = SwitcherPreferences.shared
    private let configurationFreeze = SwitcherSessionConfigurationFreeze.shared
    private let currentUptime: () -> TimeInterval

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var eventTapWatchdog: EventTapWatchdog?
    private var installRetryWorkItem: DispatchWorkItem?
    private var showUIWorkItem: DispatchWorkItem?
    private let installRetryDelay: TimeInterval = 1.0

    private var timingState = ProfileHotkeyTimingState()
    private var physicalChordTimingState = PhysicalModifierChordTimingState()

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
        self.inputMirror = switcher.inputMirror
        // Created on the main thread by the app delegate.
        self.licensingGate = MainActor.assumeIsolated {
            LicensingController.shared.eventTapGate
        }
        locked { installOrScheduleRetry() }
        startEventTapWatchdog()
    }

    deinit {
        configurationFreeze.end()
        locked {
            installRetryWorkItem?.cancel()
            showUIWorkItem?.cancel()
            uninstallTap()
        }
    }

    /// Called before click-based commits so the follow-up modifier release cannot
    /// trigger a second activation.
    func clearTriggerStateFromClickCommit() {
        locked {
            resetInteractionState(
                cancelVisibleSession: false,
                preserveSwallowedKeyUps: true
            )
        }
    }

    private func locked<T>(_ body: () -> T) -> T {
        stateLock.lock()
        defer { stateLock.unlock() }
        return body()
    }

    // MARK: Event-tap lifecycle

    private func startEventTapWatchdog() {
        let watchdog = EventTapWatchdog(
            isTrusted: { AXIsProcessTrusted() },
            hasValidTap: { [weak self] in
                guard let tap = self?.locked({ self?.eventTap }) ?? nil else { return false }
                return CFMachPortIsValid(tap)
            },
            isEnabled: { [weak self] in
                guard let tap = self?.locked({ self?.eventTap }) ?? nil else { return false }
                return CGEvent.tapIsEnabled(tap: tap)
            },
            reinstall: { [weak self] in
                guard let self else { return }
                self.locked {
                    self.resetInteractionState(cancelVisibleSession: true)
                    self.uninstallTap()
                    self.installOrScheduleRetry()
                }
            },
            reenable: { [weak self] in
                guard let self else { return }
                self.locked { self.recoverDisabledTap() }
            },
            suspend: { [weak self] in
                guard let self else { return }
                self.locked {
                    self.resetInteractionState(cancelVisibleSession: true)
                    self.uninstallTap()
                    self.scheduleInstallRetry()
                }
            }
        )
        eventTapWatchdog = watchdog
        watchdog.start()
    }

    private func recoverDisabledTap() {
        resetInteractionState(cancelVisibleSession: true)
        guard let eventTap, CFMachPortIsValid(eventTap), AXIsProcessTrusted() else {
            uninstallTap()
            scheduleInstallRetry()
            return
        }
        CGEvent.tapEnable(tap: eventTap, enable: true)
        os_log(.info, log: profileHotkeyLog, "Recovered disabled profile event tap")
    }

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
            self.locked {
                self.installRetryWorkItem = nil
                self.installOrScheduleRetry()
            }
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
                // Pass-through returns the callback's own +0 event. Retaining it
                // here would leak every keystroke and scroll packet system-wide.
                guard let refcon else {
                    return Unmanaged.passUnretained(event)
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
        CFRunLoopAddSource(tapThread.runLoop, source, .commonModes)
        CFRunLoopWakeUp(tapThread.runLoop)
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
            CFMachPortInvalidate(eventTap)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(
                tapThread.runLoop,
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
        let result = locked { handleInner(type: type, event: event) }
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
            return Unmanaged.passUnretained(event)
        }

        if isKeyboardEvent(type), ShortcutRecordingState.shared.isRecording {
            // The AppKit recorder owns new key pairs. Cancel stale global state,
            // while retaining only key-ups for key-downs already swallowed.
            resetInteractionState(
                cancelVisibleSession: true,
                preserveSwallowedKeyUps: true
            )
            return Unmanaged.passUnretained(event)
        }

        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            os_log(.error, log: profileHotkeyLog, "Profile event tap disabled: %{public}@", type == .tapDisabledByTimeout ? "timeout" : "user input")
            recoverDisabledTap()
            return nil

        case .flagsChanged:
            handleAlternateModifierChange(event, now: eventUptime(event))
            handleProfileModifierRelease(flags: event.flags)
            return Unmanaged.passUnretained(event)

        case .keyDown:
            guard !shouldBypassForActiveTextInput(event) else {
                resetInteractionState(
                    cancelVisibleSession: false,
                    preserveSwallowedKeyUps: true
                )
                return Unmanaged.passUnretained(event)
            }
            alternateTriggerState.noteInterveningKeyDown(
                now: eventUptime(event)
            )
            return handleKeyDown(event)

        case .keyUp:
            return Unmanaged.passUnretained(event)

        case .scrollWheel:
            guard inputMirror.state.isVisible else {
                return Unmanaged.passUnretained(event)
            }
            let receivedAt = currentUptime()
            dispatchToMain { [weak self] in
                guard let scrollEvent = NSEvent(cgEvent: event) else { return }
                self?.switcher?.handleScrollSelection(scrollEvent, receivedAt: receivedAt)
            }
            return nil

        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func handleKeyDown(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0

        if handleVisibleSwitcherKey(event, keyCode: keyCode) {
            // The key-up of a consumed key-down must not reach the frontmost app.
            swallowedKeyCodes.insert(keyCode)
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
            return Unmanaged.passUnretained(event)
        }

        guard let match = profileStore.match(
            keyCode: keyCode,
            flags: event.flags
        ) else {
            handlePassThroughKeyDown(
                keyCode: keyCode,
                cancelVisibleSession: false
            )
            return Unmanaged.passUnretained(event)
        }

        guard licensingGate.allowsShortcut() else {
            handlePassThroughKeyDown(
                keyCode: keyCode,
                cancelVisibleSession: false
            )
            return Unmanaged.passUnretained(event)
        }

        let triggerUptime = eventUptime(event)
        let mirrored = inputMirror.state
        let isVisible = mirrored.isVisible

        // Like native Command-Tab, any matching key-down starts a session no
        // matter how long the modifier was held or which keys preceded it.
        // While a hidden trigger is pending, a further deliberate Tab advances
        // the selection once the session starts; key repeat never does, so it
        // cannot stretch or skip the original reveal deadline.
        if !isVisible, timingState.hasPendingTrigger {
            swallowedKeyCodes.insert(keyCode)
            timingState.registerAdditionalAdvance(match: match, isRepeat: isRepeat)
            return nil
        }

        let sameVisibleProfile = isVisible &&
            mirrored.activeProfileID == match.profileID
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
        guard let switcher else { return false }
        let mirrored = inputMirror.state
        if mirrored.hasPendingPresentation, keyCode == 53 {
            resetInteractionState(cancelVisibleSession: false, preserveSwallowedKeyUps: true)
            dispatchToMain { switcher.cancelAndHide() }
            return true
        }
        guard mirrored.isVisible else { return false }

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

        // Command Palette owns a native NSSearchField. Leave text events to
        // AppKit so composition, paste, and accessibility stay native.
        if mirrored.currentStyle == .commandPalette { return false }

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
            // The reveal deadline is decided off the main thread; only showing
            // the overlay needs main.
            scheduleReveal(atUptime: atUptime)

        case let .showOverlay(match, additionalAdvances):
            dispatchToMain { [weak self] in
                guard let self else { return }
                self.switcher?.showOrAdvance(
                    reverse: match.reverse,
                    profileID: match.profileID,
                    additionalAdvances: additionalAdvances
                )
                self.schedulePostShowReleaseCheck(match)
            }

        case let .quickSwitch(match, additionalAdvances):
            dispatchToMain { [weak self] in
                guard let self else { return }
                self.locked { self.clearCompletedProfileTriggerState() }
                self.switcher?.commitTriggerSession(
                    reverse: match.reverse,
                    profileID: match.profileID,
                    additionalAdvances: additionalAdvances
                )
                self.configurationFreeze.end()
            }

        case let .confirmSelection(match):
            dispatchToMain { [weak self] in
                guard let self else { return }
                guard self.switcher?.activeProfileID == match.profileID else {
                    self.locked { self.clearCompletedProfileTriggerState() }
                    self.configurationFreeze.end()
                    return
                }
                self.locked { self.clearCompletedProfileTriggerState() }
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
            self.locked {
                self.showUIWorkItem = nil
                self.handleScheduledReveal()
            }
        }
        showUIWorkItem = item
        timerQueue.asyncAfter(
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
        let mirrored = inputMirror.state
        if mirrored.hasPendingPresentation {
            timingState.cancel()
            configurationFreeze.end()
            dispatchToMain { [weak self] in self?.switcher?.cancelAndHide() }
            return
        }
        guard let action = timingState.handleModifierRelease(
            modifier,
            switcherVisible: mirrored.isVisible,
            activeProfileID: mirrored.activeProfileID
        ) else {
            configurationFreeze.end()
            return
        }
        performTimingAction(action)
    }

    private func schedulePostShowReleaseCheck(_ match: ShortcutProfileMatch) {
        timerQueue.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self else { return }
            self.locked {
                guard self.timingState.pendingMatch == match,
                      let modifier = match.primaryModifier,
                      !modifier.isHeld(in: Self.liveModifierFlags()) else {
                    return
                }
                self.cancelScheduledReveal()
                let mirrored = self.inputMirror.state
                if mirrored.hasPendingPresentation {
                    self.timingState.cancel()
                    self.configurationFreeze.end()
                    self.dispatchToMain { [weak self] in self?.switcher?.cancelAndHide() }
                    return
                }
                if let action = self.timingState.handleModifierRelease(
                    modifier,
                    switcherVisible: mirrored.isVisible,
                    activeProfileID: mirrored.activeProfileID
                ) {
                    self.performTimingAction(action)
                }
            }
        }
    }

    private func cancelScheduledReveal() {
        showUIWorkItem?.cancel()
        showUIWorkItem = nil
    }

    private func liveHeldModifiers() -> Set<HotkeyModifier> {
        let flags = Self.liveModifierFlags()
        var held = Set<HotkeyModifier>()
        if flags.contains(.maskCommand) { held.insert(.command) }
        if flags.contains(.maskAlternate) { held.insert(.option) }
        return held
    }

    /// Hardware modifier state, readable from any thread (unlike
    /// `NSEvent.modifierFlags`, which belongs to the main thread).
    private static func liveModifierFlags() -> CGEventFlags {
        CGEventSource.flagsState(.combinedSessionState)
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

        let isDown = updatePhysicalModifierState(for: key, flags: event.flags)
        physicalChordTimingState.noteModifierChange(
            key,
            isDown: isDown,
            at: now
        )
        let mode = inputMirror.state.alternateTrigger
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

        guard licensingGate.allowsShortcut() else { return }

        dispatchToMain { [weak self] in
            guard let self else { return }
            if self.switcher?.isVisible == true {
                self.locked { self.resetInteractionState(cancelVisibleSession: false) }
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

    /// Reads side-specific modifier state from the event's device flag bits
    /// instead of toggling. A toggle inverts permanently after any reset or
    /// missed event while a key is held; the device bits are always current.
    private func updatePhysicalModifierState(
        for key: PhysicalModifierTriggerKey,
        flags: CGEventFlags
    ) -> Bool {
        let device = PhysicalModifierDeviceFlags(flags: flags)
        leftCommandDown = device.leftCommand
        rightCommandDown = device.rightCommand
        leftOptionDown = device.leftOption
        rightOptionDown = device.rightOption
        return device.isDown(key)
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
        let ownedRelease = timingState.hasPendingTrigger
        let hadPendingTrigger = ownedRelease || showUIWorkItem != nil
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

        // A visible hold-to-release session whose release owner was just
        // cancelled could no longer be committed by releasing the modifier,
        // leaving the overlay stuck on screen. Close it instead.
        let mirrored = inputMirror.state
        let strandsVisibleSession = ownedRelease && mirrored.isVisible
        guard mirrored.hasPendingPresentation ||
              ((cancelVisibleSession || strandsVisibleSession) && mirrored.isVisible) else { return }
        dispatchToMain { [weak self] in
            self?.switcher?.cancelAndHide()
        }
    }

    /// Clears only the completed profile gesture. The immutable configuration
    /// remains frozen until the controller has consumed the commit action.
    private func clearCompletedProfileTriggerState() {
        cancelScheduledReveal()
        timingState.cancel()
        physicalChordTimingState.reset()
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
        physicalChordTimingState.reset()
        if !preserveSwallowedKeyUps {
            swallowedKeyCodes.removeAll()
        }
        alternateTriggerState = AlternateModifierTriggerState()
        // Side-specific modifier state is not cleared: it mirrors the device
        // flag bits and is overwritten by the next flags-changed event.

        let mirrored = inputMirror.state
        guard mirrored.hasPendingPresentation || (cancelVisibleSession && mirrored.isVisible) else { return }
        dispatchToMain { [weak self] in
            self?.switcher?.cancelAndHide()
        }
    }

    private func isKeyboardEvent(_ type: CGEventType) -> Bool {
        type == .keyDown || type == .keyUp || type == .flagsChanged
    }

    static func shouldBypassForActiveTextInput(
        keyCode: Int64,
        flags: CGEventFlags,
        hasActiveTextInput: Bool
    ) -> Bool {
        // Command-Tab remains a global switch command even while editing text.
        // Shortcut recording and Secure Input are checked before this policy.
        let modifiers = ShortcutModifierMask(eventFlags: flags)
        if keyCode == RecordedShortcut.commandTab.keyCode,
           modifiers.contains(.command),
           modifiers.subtracting([.command, .shift]).isEmpty {
            return false
        }
        return hasActiveTextInput
    }

    private func shouldBypassForActiveTextInput(_ event: CGEvent) -> Bool {
        Self.shouldBypassForActiveTextInput(
            keyCode: event.getIntegerValueField(.keyboardEventKeycode),
            flags: event.flags,
            hasActiveTextInput: inputMirror.state.hasActiveTextInput
        )
    }

    private func eventUptime(_ event: CGEvent) -> TimeInterval {
        EventTimestampClock.uptime(
            eventTimestamp: event.timestamp,
            now: currentUptime()
        )
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
