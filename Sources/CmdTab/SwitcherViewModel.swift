import Foundation
import AppKit

/// Central observable state for the switcher overlay.
final class SwitcherViewModel: ObservableObject {
    @Published var items: [SwitcherItem] = []
    @Published var selectedIndex: Int = 0
    @Published var mode: SwitcherMode = .app
    @Published var isVisible: Bool = false
    @Published var layout: SwitcherLayoutMetrics = .empty
    @Published var backdropScreenFrame: CGRect = .zero
    @Published var backdropVisibleFrame: CGRect = .zero

    /// Index of the card currently under the mouse cursor.
    /// Updated by SwiftUI `.onHover` on each card, used by `handleCardClick`
    /// to determine which card was clicked — eliminates fragile coordinate math.
    @Published var hoveredIndex: Int?

    /// Live search query for the Command Palette style.
    /// Printable characters typed while the palette is visible are forwarded
    /// here by HotkeyManager; SwitcherWindowController filters `items` accordingly.
    /// Cleared automatically when the overlay is dismissed.
    @Published var searchQuery: String = ""

    // Move selection left/right, wrapping around
    func move(by delta: Int) {
        guard !items.isEmpty else { return }
        selectedIndex = (selectedIndex + delta + items.count) % items.count
    }

    func moveUp() {
        guard !items.isEmpty else { return }
        let cols = max(1, min(layout.columns, items.count))
        if selectedIndex >= cols {
            selectedIndex -= cols
        } else {
            var bottom = selectedIndex
            while bottom + cols < items.count { bottom += cols }
            selectedIndex = bottom
        }
    }

    func moveDown() {
        guard !items.isEmpty else { return }
        let cols = max(1, min(layout.columns, items.count))
        if selectedIndex + cols < items.count {
            selectedIndex += cols
        } else {
            selectedIndex = selectedIndex % cols
        }
    }
}
