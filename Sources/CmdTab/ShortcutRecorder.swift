import AppKit
import SwiftUI

/// Crosses the AppKit recorder and global event-tap boundary without exposing
/// editable SwiftUI state to the tap callback.
final class ShortcutRecordingState {
    static let shared = ShortcutRecordingState()

    private let lock = NSLock()
    private var recordingCount = 0

    var isRecording: Bool {
        lock.lock()
        let value = recordingCount > 0
        lock.unlock()
        return value
    }

    func begin() {
        lock.lock()
        recordingCount += 1
        lock.unlock()
    }

    func end() {
        lock.lock()
        recordingCount = max(0, recordingCount - 1)
        lock.unlock()
    }
}

private final class ShortcutCaptureNSView: NSView {
    var shortcut: RecordedShortcut?
    var onRecord: ((RecordedShortcut?) -> Void)?
    var onCancel: (() -> Void)?

    var isRecording = false {
        didSet {
            guard isRecording != oldValue else { return }
            if isRecording {
                ShortcutRecordingState.shared.begin()
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.window?.makeFirstResponder(self)
                    self.needsDisplay = true
                    NSAccessibility.post(
                        element: self,
                        notification: .valueChanged
                    )
                }
            } else {
                ShortcutRecordingState.shared.end()
                needsDisplay = true
                NSAccessibility.post(
                    element: self,
                    notification: .valueChanged
                )
            }
        }
    }

    override var acceptsFirstResponder: Bool { true }
    override var isAccessibilityElement: Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .button }
    override func accessibilityLabel() -> String? { "Record shortcut" }
    override func accessibilityValue() -> Any? {
        isRecording
            ? "Recording. Press a shortcut, Escape to cancel, or Delete to clear."
            : (shortcut?.displayLabel ?? "Not set")
    }

    override func accessibilityPerformPress() -> Bool {
        window?.makeFirstResponder(self)
        if !isRecording { isRecording = true }
        return true
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        if !isRecording { isRecording = true }
    }

    override func resignFirstResponder() -> Bool {
        if isRecording {
            isRecording = false
            onCancel?()
        }
        return super.resignFirstResponder()
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        switch event.keyCode {
        case 53:
            isRecording = false
            onCancel?()
            return
        case 51, 117:
            isRecording = false
            shortcut = nil
            onRecord?(nil)
            return
        default:
            break
        }

        let recorded = RecordedShortcut(
            keyCode: Int64(event.keyCode),
            modifiers: ShortcutModifierMask(eventFlags: event.modifierFlags),
            keyLabel: Self.label(for: event)
        )
        shortcut = recorded
        isRecording = false
        onRecord?(recorded)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let rect = bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
        (isRecording
            ? NSColor.controlAccentColor.withAlphaComponent(0.24)
            : NSColor.controlBackgroundColor.withAlphaComponent(0.85)
        ).setFill()
        path.fill()
        (isRecording ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        path.lineWidth = isRecording ? 2 : 1
        path.stroke()

        let text = isRecording
            ? "Press shortcut · Esc cancels · Delete clears"
            : (shortcut?.displayLabel ?? "Not Set")
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: NSColor.labelColor,
        ]
        let size = text.size(withAttributes: attributes)
        text.draw(
            at: NSPoint(
                x: max(10, bounds.midX - size.width / 2),
                y: bounds.midY - size.height / 2
            ),
            withAttributes: attributes
        )
    }

    deinit {
        if isRecording {
            ShortcutRecordingState.shared.end()
        }
    }

    private static func label(for event: NSEvent) -> String {
        switch event.keyCode {
        case 48: return "Tab"
        case 49: return "Space"
        case 36, 76: return "Return"
        case 51: return "Delete"
        case 117: return "Forward Delete"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        case 122: return "F1"
        case 120: return "F2"
        case 99: return "F3"
        case 118: return "F4"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 103: return "F11"
        case 111: return "F12"
        default:
            let value = event.charactersIgnoringModifiers?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased() ?? ""
            return value.isEmpty ? "Key \(event.keyCode)" : value
        }
    }
}

struct ShortcutRecorder: NSViewRepresentable {
    @Binding var shortcut: RecordedShortcut?
    @Binding var isRecording: Bool

    func makeNSView(context: Context) -> ShortcutCaptureNSView {
        let view = ShortcutCaptureNSView(
            frame: NSRect(x: 0, y: 0, width: 280, height: 40)
        )
        view.shortcut = shortcut
        view.isRecording = isRecording
        view.onRecord = { value in
            shortcut = value
            isRecording = false
        }
        view.onCancel = {
            isRecording = false
        }
        return view
    }

    func updateNSView(
        _ nsView: ShortcutCaptureNSView,
        context: Context
    ) {
        nsView.shortcut = shortcut
        nsView.isRecording = isRecording
        nsView.needsDisplay = true
    }
}