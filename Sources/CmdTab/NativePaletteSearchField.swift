import AppKit
import SwiftUI

/// An AppKit search field is intentionally used here instead of event-tap text
/// reconstruction so input methods, dead keys, paste, Dictation, and VoiceOver
/// retain their normal macOS behavior.
struct NativePaletteSearchField: NSViewRepresentable {
    @Binding var text: String
    let focusToken: UInt
    let command: (PaletteInputCommand) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField(frame: .zero)
        field.placeholderString = "Type to filter…"
        field.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        field.focusRingType = .none
        field.delegate = context.coordinator
        field.target = context.coordinator
        field.action = #selector(Coordinator.didChangeText(_:))
        return field
    }

    func updateNSView(_ field: NSSearchField, context: Context) {
        context.coordinator.parent = self
        if field.stringValue != text { field.stringValue = text }
        guard context.coordinator.lastFocusedToken != focusToken else { return }
        context.coordinator.lastFocusedToken = focusToken
        DispatchQueue.main.async {
            guard let window = field.window else { return }
            window.makeFirstResponder(field)
        }
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var parent: NativePaletteSearchField
        var lastFocusedToken: UInt?

        init(_ parent: NativePaletteSearchField) { self.parent = parent }

        @objc func didChangeText(_ sender: NSSearchField) {
            parent.text = sender.stringValue
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSSearchField else { return }
            parent.text = field.stringValue
        }

        func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            switch commandSelector {
            case #selector(NSResponder.cancelOperation(_:)):
                parent.command(.cancel)
            case #selector(NSResponder.insertNewline(_:)):
                parent.command(.confirm)
            case #selector(NSResponder.moveUp(_:)):
                parent.command(.moveUp)
            case #selector(NSResponder.moveDown(_:)):
                parent.command(.moveDown)
            case #selector(NSResponder.moveLeft(_:)):
                parent.command(.move(-1))
            case #selector(NSResponder.moveRight(_:)):
                parent.command(.move(1))
            default:
                return false
            }
            return true
        }
    }
}
