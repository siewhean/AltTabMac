import AppKit
import CoreGraphics

/// Intercepts ⌘Tab (App mode) and ⌥Tab (Tab mode) globally via CGEventTap.
/// Suppresses the default macOS switcher while the overlay is shown.
final class HotkeyManager {
    private weak var switcher: SwitcherWindowController?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var triggerState = HotkeyTriggerStateMachine()
    private var activeTriggerGeneration = 0
    private let preferences = SwitcherPreferences.shared

    // Track live modifier state
    private var cmdDown = false
    private var optDown = false

    /// How long the user must hold the modifier before the overlay appears.
    private let showUIDelay: TimeInterval = 0.1

    /// Pending work item that reveals the switcher UI after the hold threshold.
    /// Cancelled on release/escape so the UI cannot appear after the trigger is gone.
    private var showUIWorkItem: DispatchWorkItem?

    init(switcher: SwitcherWindowController) {
        self.switcher = switcher

        switcher.onClickCommit = { [weak self] in
            guard let self else { return }
            self.cancelScheduledReveal()
            _ = self.triggerState.markCommittedExternally()
            self.triggerState.reset()
        }

        install()
    }

    deinit {
        uninstallTap()
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
        uninstallTap()
        install()
    }

    private func runOnMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }

    private func cancelScheduledReveal() {
        showUIWorkItem?.cancel()
        showUIWorkItem = nil
    }

    private func scheduleReveal(for invocation: HotkeyPendingInvocation) {
        cancelScheduledReveal()

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard self.triggerState.revealIfArmed(generation: invocation.generation, modifier: invocation.modifier) != nil else {
                return
            }

            self.showUIWorkItem = nil
            self.runOnMain { [weak self] in
                self?.switcher?.revealPreparedTriggerSession()
            }
        }

        showUIWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + showUIDelay, execute: work)
    }

    private func handleTabTrigger(modifier: HotkeyTriggerModifier, mode: SwitcherMode, reverse: Bool) {
        let startsNewTrigger = triggerState.activeModifier != modifier || !triggerState.hasActiveTrigger
        if startsNewTrigger {
            activeTriggerGeneration += 1
        }

        let invocation = HotkeyPendingInvocation(
            generation: activeTriggerGeneration,
            mode: mode,
            reverse: reverse,
            modifier: modifier
        )

        if startsNewTrigger {
            triggerState.arm(invocation)
            runOnMain { [weak self] in
                self?.switcher?.prepareTriggerSession(mode: mode, reverse: reverse)
            }
            scheduleReveal(for: invocation)
            return
        }

        triggerState.updateInvocation(invocation)
        runOnMain { [weak self] in
            self?.switcher?.prepareTriggerSession(mode: mode, reverse: reverse)
        }
    }

    private func handleReleaseAction(_ action: HotkeyTriggerReleaseAction) {
        switch action {
        case .none:
            return
        case .abort:
            cancelScheduledReveal()
            runOnMain { [weak self] in
                self?.switcher?.cancelPreparedOrVisibleSession()
            }
            triggerState.reset()
        case .commit:
            cancelScheduledReveal()
            runOnMain { [weak self] in
                self?.switcher?.confirmAndHide()
            }
            triggerState.reset()
        }
    }

    // MARK: - Event handling

    private func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            recoverEventTap()
            return Unmanaged.passRetained(event)

        case .flagsChanged:
            let flags = event.flags
            let wasCmd = cmdDown
            let wasOpt = optDown
            cmdDown = flags.contains(.maskCommand)
            optDown = flags.contains(.maskAlternate)

            if wasCmd && !cmdDown {
                handleReleaseAction(triggerState.handleModifierRelease(.command))
            }

            if wasOpt && !optDown {
                handleReleaseAction(triggerState.handleModifierRelease(.option))
            }

        case .keyDown:
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let shift = event.flags.contains(.maskShift)

            if keyCode == 53, triggerState.hasActiveTrigger {
                cancelScheduledReveal()
                if triggerState.cancel() != nil {
                    runOnMain { [weak self] in
                        self?.switcher?.cancelPreparedOrVisibleSession()
                    }
                }
                triggerState.reset()
                return nil
            }

            if keyCode == 48 {
                if cmdDown && !optDown {
                    handleTabTrigger(modifier: .command, mode: preferences.primaryMode, reverse: shift)
                    return nil
                }

                if optDown && !cmdDown {
                    handleTabTrigger(modifier: .option, mode: preferences.alternateMode(), reverse: shift)
                    return nil
                }
            }

            if let switcher, switcher.isVisible {
                switch keyCode {
                case 123:
                    runOnMain { switcher.moveSelection(by: -1) }
                    return nil
                case 124:
                    runOnMain { switcher.moveSelection(by: 1) }
                    return nil
                case 125:
                    runOnMain { switcher.moveSelectionDown() }
                    return nil
                case 126:
                    runOnMain { switcher.moveSelectionUp() }
                    return nil
                case 36, 76:
                    cancelScheduledReveal()
                    _ = triggerState.markCommittedExternally()
                    triggerState.reset()
                    runOnMain { switcher.confirmAndHide() }
                    return nil
                default:
                    break
                }

                if switcher.currentStyle == .commandPalette {
                    if keyCode == 51 {
                        runOnMain { switcher.deleteSearchCharacter() }
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
                        runOnMain { switcher.appendSearchCharacter(safeChar) }
                        return nil
                    }
                }
            }

        default:
            break
        }

        return Unmanaged.passRetained(event)
    }
}
