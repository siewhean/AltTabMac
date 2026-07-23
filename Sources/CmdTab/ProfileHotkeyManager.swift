import AppKit
import CoreGraphics
import os.log

private let profileHotkeyLog = OSLog(subsystem: "CmdTab", category: "ProfileHotkeyManager")

/// Global event-tap router for versioned switcher shortcut profiles.
/// The callback performs only lock-protected profile matching and primitive
/// state updates; all UI and Accessibility work is dispatched to the main queue.
final class ProfileHotkeyManager {
    private weak var switcher: ProductionSwitcherWindowController?
    private let profileStore: SwitcherProfileStore
    private let preferences = SwitcherPreferences.shared
    private let configurationFreeze = SwitcherSessionConfigurationFreeze.shared
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var installRetryWorkItem: DispatchWorkItem?
    private let installRetryDelay: TimeInterval = 1.0

    private var activeHoldMatch: ShortcutProfileMatch?
    private var swallowedKeyCodes = Set<Int64>()
    private var alternateTriggerState = AlternateModifierTriggerState()
    private var leftCommandDown = false
    private var leftOptionDown = false
    private var rightCommandDown = false
    private var rightOptionDown = false

    init(
        switcher: ProductionSwitcherWindowController,
        profileStore: SwitcherProfileStore = .shared
    ) {
        self.switcher = switcher
        self.profileStore = profileStore
        installOrScheduleRetry()
    }

    deinit {
        configurationFreeze.end()
        installRetryWorkItem?.cancel()
        uninstallTap()
    }

    func clearTriggerStateFromClickCommit() {
        configurationFreeze.end()
        resetInteractionState(cancelVisibleSession: false)
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
            self.installRetryWorkItem = nil
            self.installOrScheduleRetry()
        }
        installRetryWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + installRetryDelay, execute: item)
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

    private func handle(
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        let start = DispatchTime.now().uptimeNanoseconds
        let result = handleInner(type: type, event: event)
        let elapsed = DispatchTime.now().uptimeNanoseconds - start
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
            // Never intercept, inspect, or retain keystrokes while Secure Event
            // Input is active. Cancel any visible session so a stale overlay
            // cannot remain above a password or protected-entry surface.
            resetInteractionState(cancelVisibleSession: true)
            return Unmanaged.passRetained(event)
        }

        if ShortcutRecordingState.shared.isRecording, isKeyboardEvent(type) {
            // The AppKit recorder must see the original event. Do not mutate
            // profile trigger state or swallow an existing shortcut while the
            // user is recording a replacement.
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
            if shouldBypassForActiveTextInput() {
                return Unmanaged.passRetained(event)
            }
            alternateTriggerState.noteInterveningKeyDown(
                now: TimeInterval(event.timestamp) / 1_000_000_000
            )
            return handleKeyDown(event)

        case .keyUp:
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            if swallowedKeyCodes.remove(keyCode) != nil {
                return nil
            }
            if profileStore.match(keyCode: keyCode, flags: event.flags) != nil {
                return nil
            }
            return Unmanaged.passRetained(event)

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

        if switcher?.isVisible == true {
            switch keyCode {
            case 53:
                activeHoldMatch = nil
                configurationFreeze.end()
                dispatchToMain { [weak self] in self?.switcher?.cancelAndHide() }
                return nil
            case 36, 76:
                activeHoldMatch = nil
                configurationFreeze.end()
                dispatchToMain { [weak self] in self?.switcher?.confirmAndHide() }
                return nil
            case 123:
                dispatchToMain { [weak self] in self?.switcher?.moveSelection(by: -1) }
                return nil
            case 124:
                dispatchToMain { [weak self] in self?.switcher?.moveSelection(by: 1) }
                return nil
            case 125:
                dispatchToMain { [weak self] in self?.switcher?.moveSelectionDown() }
                return nil
            case 126:
                dispatchToMain { [weak self] in self?.switcher?.moveSelectionUp() }
                return nil
            default:
                break
            }

            if switcher?.currentStyle == .commandPalette {
                if keyCode == 51 {
                    dispatchToMain { [weak self] in
                        self?.switcher?.deleteSearchCharacter()
                    }
                    return nil
                }
                if let character = searchableCharacter(from: event) {
                    dispatchToMain { [weak self] in
                        self?.switcher?.appendSearchCharacter(character)
                    }
                    return nil
                }
            } else if let action = SwitcherQuickAction.action(
                forKeyCode: keyCode,
                keyEquivalent: keyEquivalent(for: event),
                commandHeld: event.flags.contains(.maskCommand),
                acceptsBareShortcut: !event.flags.contains(.maskCommand) &&
                    !event.flags.contains(.maskAlternate) &&
                    !event.flags.contains(.maskControl)
            ) {
                dispatchToMain { [weak self] in
                    self?.switcher?.performQuickAction(action)
                }
                return nil
            }
        }

        guard let match = profileStore.match(keyCode: keyCode, flags: event.flags) else {
            return Unmanaged.passRetained(event)
        }

        let shouldHandleShortcut = MainActor.assumeIsolated {
            LicensingController.shared.shouldHandleCustomSwitcherShortcut()
        }
        guard shouldHandleShortcut else {
            // Preserve the native/system shortcut when CmdTab is not currently
            // allowed to handle switching. Swallowing here would strand users.
            return Unmanaged.passRetained(event)
        }

        let preserveExisting = switcher?.isVisible == true &&
            switcher?.activeProfileID == match.profileID
        configurationFreeze.begin(
            profileID: match.profileID,
            preserveExisting: preserveExisting
        )
        swallowedKeyCodes.insert(keyCode)

        if isRepeat, match.releaseBehavior == .pressToToggle {
            return nil
        }

        switch match.releaseBehavior {
        case .pressToToggle:
            dispatchToMain { [weak self] in
                self?.switcher?.showOrAdvance(
                    reverse: match.reverse,
                    profileID: match.profileID
                )
            }

        case .holdPrimaryModifier:
            activeHoldMatch = match
            dispatchToMain { [weak self] in
                self?.switcher?.showOrAdvance(
                    reverse: match.reverse,
                    profileID: match.profileID
                )
            }
            schedulePostShowReleaseCheck(match)
        }
        return nil
    }

    private func handleHoldModifierRelease(flags: CGEventFlags) {
        guard let match = activeHoldMatch,
              let primary = match.primaryModifier else { return }
        let held: Bool
        switch primary {
        case .command:
            held = flags.contains(.maskCommand)
        case .option:
            held = flags.contains(.maskAlternate)
        }
        guard !held else { return }
        activeHoldMatch = nil
        configurationFreeze.end()
        dispatchToMain { [weak self] in
            guard self?.switcher?.activeProfileID == match.profileID,
                  self?.switcher?.activeReleaseBehavior == .holdPrimaryModifier else {
                return
            }
            self?.switcher?.confirmAndHide()
        }
    }

    private func schedulePostShowReleaseCheck(_ match: ShortcutProfileMatch) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self,
                  self.activeHoldMatch == match,
                  let primary = match.primaryModifier else { return }
            if !primary.isHeld(in: NSEvent.modifierFlags) {
                self.activeHoldMatch = nil
                self.configurationFreeze.end()
                self.switcher?.confirmAndHide()
            }
        }
    }

    private func handleAlternateModifierChange(_ event: CGEvent) {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard let key = PhysicalModifierTriggerKey(flagsChangedKeyCode: keyCode) else {
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
            now: TimeInterval(event.timestamp) / 1_000_000_000
        )
        guard shouldActivate else { return }

        let shouldHandleShortcut = MainActor.assumeIsolated {
            LicensingController.shared.shouldHandleCustomSwitcherShortcut()
        }
        guard shouldHandleShortcut else { return }

        dispatchToMain { [weak self] in
            guard let self else { return }
            if self.switcher?.isVisible == true {
                self.configurationFreeze.end()
                self.switcher?.confirmAndHide()
            } else if let profileID = self.profileStore
                .profilesSnapshot()
                .first(where: \.isEnabled)?
                .id {
                self.configurationFreeze.begin(
                    profileID: profileID,
                    preserveExisting: false
                )
                self.switcher?.commitTriggerSession(
                    reverse: false,
                    profileID: profileID
                )
            }
        }
    }

    private func toggleModifierState(for key: PhysicalModifierTriggerKey) -> Bool {
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

    private func resetInteractionState(cancelVisibleSession: Bool) {
        configurationFreeze.end()
        activeHoldMatch = nil
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
              !flags.contains(.maskCommand) else {
            return nil
        }
        guard let value = keyEquivalent(for: event),
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