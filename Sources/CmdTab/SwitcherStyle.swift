import Foundation

/// Interchangeable UI presentation styles for the switcher overlay.
/// Adding a new style requires:
///   1. A case here
///   2. A SwiftUI view conforming to the style's layout
///   3. A SwitcherLayoutMetrics factory in SwitcherLayout.swift
///   4. A case in SwitcherWindowController.showPanel() for positioning
enum SwitcherStyle: String, CaseIterable, Codable, Sendable {
    /// Horizontal grid of window thumbnail cards (the original macOS Exposé look).
    case classicGrid     = "classicGrid"

    /// Compact vertical list with live keyboard search filtering.
    /// Printable keystrokes typed while the overlay is open are forwarded to
    /// the search query and filter the item list in real time.
    case commandPalette  = "commandPalette"

    /// Circular arrangement of app icons around the cursor position.
    /// Up to 8 items are shown; selection wraps around the circle.
    case radialMenu      = "radialMenu"

    var title: String {
        switch self {
        case .classicGrid:    return "Classic Grid"
        case .commandPalette: return "Command Palette"
        case .radialMenu:     return "Radial Menu"
        }
    }

    var systemImage: String {
        switch self {
        case .classicGrid:    return "square.grid.3x2"
        case .commandPalette: return "list.bullet"
        case .radialMenu:     return "circle.grid.cross"
        }
    }
}
