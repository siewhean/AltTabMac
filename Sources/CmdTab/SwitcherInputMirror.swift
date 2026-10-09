import Foundation

/// The main-thread facts the keyboard event tap routes on.
struct SwitcherInputState: Equatable {
    var isVisible = false
    var hasPendingPresentation = false
    var activeProfileID: UUID?
    var currentStyle: SwitcherStyle = .classicGrid
    /// A CmdTab text field or text view is first responder in the active app.
    var hasActiveTextInput = false
    var alternateTrigger: AlternateTriggerMode = .disabled
}

/// Lock-protected copy of `SwitcherInputState`, written by the main thread
/// whenever the switcher, its configuration, or CmdTab's key window changes,
/// and read by the event tap thread without touching AppKit.
final class SwitcherInputMirror: @unchecked Sendable {
    private let lock = NSLock()
    private var current = SwitcherInputState()

    var state: SwitcherInputState {
        lock.lock()
        defer { lock.unlock() }
        return current
    }

    func update(_ body: (inout SwitcherInputState) -> Void) {
        lock.lock()
        body(&current)
        lock.unlock()
    }
}
