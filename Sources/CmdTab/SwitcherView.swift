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

private struct SelectedPreviewBackdrop: View {
    let preview: NSImage

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Image(nsImage: preview)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .scaleEffect(1.01)
                    .saturation(1.0)

                LinearGradient(
                    colors: [
                        Color.black.opacity(0.28),
                        Color.black.opacity(0.18),
                        Color.black.opacity(0.34)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .allowsHitTesting(false)
    }
}

struct SwitcherScreenBackdropView: View {
    @ObservedObject var viewModel: SwitcherViewModel
    @ObservedObject private var preferences = SwitcherPreferences.shared

    var body: some View {
        Group {
            if preferences.showSelectedPreviewBackdrop,
               let preview = selectedBackdropImage {
                SelectedPreviewBackdrop(preview: preview)
                    .ignoresSafeArea()
                    .transition(.opacity)
            } else {
                Color.clear
            }
        }
        .animation(.easeInOut(duration: 0.14), value: selectedPreviewIdentity)
        .animation(.easeInOut(duration: 0.14), value: preferences.showSelectedPreviewBackdrop)
    }

    private var selectedItem: SwitcherItem? {
        guard viewModel.selectedIndex >= 0, viewModel.selectedIndex < viewModel.items.count else { return nil }
        return viewModel.items[viewModel.selectedIndex]
    }

    private var selectedBackdropImage: NSImage? {
        selectedItem?.backdropImage ?? selectedItem?.previewImage
    }

    private var selectedPreviewIdentity: String {
        selectedItem?.historyIdentity.stableKey ?? "none"
    }
}
