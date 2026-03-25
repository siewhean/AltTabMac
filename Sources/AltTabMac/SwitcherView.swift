import SwiftUI
import AppKit

// MARK: - Click-through NSHostingView wrapper
//
// NSPanel with .nonactivatingPanel never becomes key window in the traditional
// sense, which means SwiftUI gesture recognisers (.onTapGesture / Button) never
// fire for mouse events. The fix: subclass NSHostingView and override
// mouseDown(with:) at the AppKit layer — this fires unconditionally regardless
// of key-window state. We translate the click position to a card index and
// post it back to the view model via a callback.

final class ClickableHostingView<Content: View>: NSHostingView<Content> {

    // Set by SwitcherWindowController after init.
    var onCardClick: ((NSPoint) -> Void)?

    override func mouseDown(with event: NSEvent) {
        // Convert the window-coordinate click to our view's local coordinates.
        let localPoint = convert(event.locationInWindow, from: nil)
        onCardClick?(localPoint)
        // Do NOT call super — prevents AppKit from doing focus-ring stuff.
    }

    // acceptsFirstMouse so the very first click (before we are key) still fires.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

// MARK: - Style Router
//
// SwitcherView is a pure router: it delegates all rendering to the active
// style's dedicated view. To add a new style:
//   1. Add a case to SwitcherStyle
//   2. Create a new SwiftUI view file
//   3. Add a SwitcherLayoutMetrics factory in SwitcherLayout.swift
//   4. Add a case in SwitcherWindowController.showPanel()
//   5. Add a case below

struct SwitcherView: View {
    @ObservedObject var viewModel: SwitcherViewModel
    @ObservedObject private var preferences = SwitcherPreferences.shared

    var body: some View {
        switch preferences.switcherStyle {
        case .classicGrid:
            ClassicGridView(viewModel: viewModel)
        case .commandPalette:
            CommandPaletteView(viewModel: viewModel)
        case .radialMenu:
            RadialMenuView(viewModel: viewModel)
        }
    }
}

// MARK: - NSVisualEffectView bridge
//
// Shared by all style views that opt into vibrancy.

struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blendingMode
        v.state = .active
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
