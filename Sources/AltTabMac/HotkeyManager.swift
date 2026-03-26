import AppKit
import CoreGraphics

/// Intercepts ⌘Tab (App mode) and ⌥Tab (Tab mode) globally via CGEventTap.
/// Suppresses the default macOS switcher while the overlay is shown.
final class HotkeyManager {
    private weak var switcher: SwitcherWindowController?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let preferences = SwitcherPreferences.shared

    private var cmdDown = false
    private var optDown = false
    private let showUIDelay: TimeInterval = 0.1
    private var showUIWorkItem: DispatchWorkItem?
    private var pendingMode: SwitcherMode?
    private var pendingReverse = false
    private var pendingModifier: HotkeyModifier?

    init(switcher: SwitcherWindowController) {
        self.switcher = switcher
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
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
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

    private func scheduleReveal() {
        cancelScheduledReveal()

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.showUIWorkItem = nil

            // Re-read both fields inside the closure — if handleModifierRelease
            // cleared them before this item was dequeued, we abort here.
            guard let mode     = self.pendingMode,
                  let modifier = self.pendingModifier else { return }

            // Last-gate: consult the live hardware modifier state.
            // DispatchWorkItem.cancel() only prevents execution if the item
            // hasn't started yet. In the tight race where the modifier is
            // released at the exact millisecond the deadline fires, the item
            // is already running and cancel() has no effect. NSEvent.modifierFlags
            // bypasses our cached cmdDown/optDown booleans (which may not have
            // been updated yet by the pending flagsChanged event) and reads
            // the physical key state directly.
            let live = NSEvent.modifierFlags
            switch modifier {
            case .command where !live.contains(.command):
                self.pendingMode = nil; self.pendingModifier = nil; self.pendingReverse = false
                return
            case .option where !live.contains(.option):
                self.pendingMode = nil; self.pendingModifier = nil; self.pendingReverse = false
                return
            default:
                break
            }

            self.runOnMain { [weak self] in
                guard let self else { return }
                self.switcher?.showOrAdvance(mode: mode, reverse: self.pendingReverse)

                // Post-show safety net: if CGEventTap was disabled during
                // the reveal delay, the flagsChanged for modifier-release
                // was lost. A one-shot hardware check 50ms later catches
                // the stuck-panel ("ghost window") case.
                let postShowModifier = self.pendingModifier
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                    guard let self,
                          self.switcher?.isVisible == true,
                          let mod = postShowModifier else { return }
                    let live = NSEvent.modifierFlags
                    let stillHeld: Bool
                    switch mod {
                    case .command: stillHeld = live.contains(.command)
                    case .option:  stillHeld = live.contains(.option)
                    }
                    if !stillHeld {
                        self.handleModifierRelease(mod)
                    }
                }
            }
        }

        showUIWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + showUIDelay, execute: work)
    }

    private func handleTabTrigger(modifier: HotkeyModifier, mode: SwitcherMode, reverse: Bool) {
        guard let switcher else { return }
        if switcher.isVisible {
            runOnMain { [weak self] in
                self?.switcher?.showOrAdvance(mode: mode, reverse: reverse)
            }
            return
        }

        pendingMode = mode
        pendingReverse = reverse
        pendingModifier = modifier
        scheduleReveal()
    }

    private func handleModifierRelease(_ modifier: HotkeyModifier) {
        guard pendingModifier == modifier || switcher?.isVisible == true else { return }

        cancelScheduledReveal()

        if switcher?.isVisible == true {
            // Panel is showing — commit the current selection and hide.
            runOnMain { [weak self] in
                self?.switcher?.confirmAndHide()
            }
        } else if let mode = pendingMode {
            // Fast path: modifier released before the UI appearance delay
            // fired. Instantly activate the next MRU window without ever
            // showing the overlay.
            let reverse = pendingReverse
            runOnMain { [weak self] in
                self?.switcher?.commitTriggerSession(mode: mode, reverse: reverse)
            }
        }

        pendingMode = nil
        pendingModifier = nil
        pendingReverse = false
    }

    // MARK: - Event handling

    private func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // Re-enable the tap and drop the synthetic "disabled" pseudo-event.
            // Passing it downstream could let a ⌘Tab that fired during the gap
            // reach the system and trigger the default macOS switcher.
            recoverEventTap()
            return nil

        case .flagsChanged:
            let flags = event.flags
            let wasCmd = cmdDown
            let wasOpt = optDown
            cmdDown = flags.contains(.maskCommand)
            optDown = flags.contains(.maskAlternate)

            if wasCmd && !cmdDown {
                handleModifierRelease(.command)
            }

            if wasOpt && !optDown {
                handleModifierRelease(.option)
            }

        case .keyDown:
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let shift = event.flags.contains(.maskShift)

            if keyCode == 53 {
                // Capture state BEFORE clearing it so we know whether to suppress.
                let wasPendingOrVisible = pendingMode != nil || switcher?.isVisible == true
                cancelScheduledReveal()
                pendingMode = nil
                pendingModifier = nil
                pendingReverse = false
                if switcher?.isVisible == true {
                    runOnMain { [weak self] in
                        self?.switcher?.cancelAndHide()
                    }
                }
                // Suppress Escape whenever we were in any switcher state (panel
                // visible OR pending reveal). This closes the "double Escape" window
                // caused by the gap between the first Escape arriving at the tap
                // and the panel's isVisible flag updating on the main thread.
                if wasPendingOrVisible { return nil }
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
                    pendingMode = nil
                    pendingModifier = nil
                    pendingReverse = false
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

        case .keyUp:
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            // Suppress Tab key-up when we consumed the matching key-down.
            // Without this the WindowServer sees an orphaned Tab-up while
            // Cmd is held and may trigger the native macOS app switcher.
            if keyCode == 48 && (pendingMode != nil || switcher?.isVisible == true) {
                return nil
            }

        default:
            break
        }

        return Unmanaged.passRetained(event)
    }
}

private enum HotkeyModifier {
    case command
    case option
}
