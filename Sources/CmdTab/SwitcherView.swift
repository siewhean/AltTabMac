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

extension AnyTransition {
    static var switcherItemMutation: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.94)).combined(with: .offset(y: 8)),
            removal: .opacity.combined(with: .scale(scale: 0.86)).combined(with: .offset(y: -10))
        )
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
    let windowFrame: CGRect?
    let screenFrame: CGRect
    let visibleFrame: CGRect

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(0.16)

                if let windowFrame, screenFrame != .zero {
                    let targetFrame = promotedBackdropFrame(windowFrame: windowFrame, visibleFrame: visibleFrame) ?? windowFrame
                    ActualWindowBackdrop(
                        preview: preview,
                        windowFrame: targetFrame,
                        screenFrame: screenFrame
                    )
                } else {
                    fallbackPreview(in: proxy.size)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .allowsHitTesting(false)
    }

    private func promotedBackdropFrame(windowFrame: CGRect, visibleFrame: CGRect) -> CGRect? {
        guard visibleFrame != .zero, visibleFrame.width > 0, visibleFrame.height > 0 else { return nil }

        let edgeTolerance: CGFloat = 18
        let widthRatio = windowFrame.width / visibleFrame.width
        let heightRatio = windowFrame.height / visibleFrame.height

        let leftGap = abs(windowFrame.minX - visibleFrame.minX)
        let rightGap = abs(windowFrame.maxX - visibleFrame.maxX)
        let bottomGap = abs(windowFrame.minY - visibleFrame.minY)
        let topGap = abs(windowFrame.maxY - visibleFrame.maxY)

        let fillsVisibleDesktop =
            leftGap <= edgeTolerance &&
            rightGap <= edgeTolerance &&
            bottomGap <= edgeTolerance &&
            topGap <= edgeTolerance &&
            widthRatio >= 0.97 &&
            heightRatio >= 0.93

        return fillsVisibleDesktop ? visibleFrame : nil
    }

    @ViewBuilder
    private func fallbackPreview(in size: CGSize) -> some View {
        let imageSize = preview.size
        let width = min(max(imageSize.width, 0), size.width)
        let height = min(max(imageSize.height, 0), size.height)

        Image(nsImage: preview)
            .resizable()
            .interpolation(.high)
            .frame(width: width, height: height)
            .position(x: size.width / 2, y: size.height / 2)
    }
}

private struct ActualWindowBackdrop: NSViewRepresentable {
    let preview: NSImage
    let windowFrame: CGRect
    let screenFrame: CGRect

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.clear.cgColor
        container.layer?.masksToBounds = true

        let imageLayer = CALayer()
        imageLayer.contentsGravity = .resize
        imageLayer.magnificationFilter = .trilinear
        imageLayer.minificationFilter = .trilinear
        imageLayer.backgroundColor = NSColor.black.cgColor
        imageLayer.shadowColor = NSColor.black.withAlphaComponent(0.22).cgColor
        imageLayer.shadowOpacity = 1
        imageLayer.shadowRadius = 24
        imageLayer.shadowOffset = CGSize(width: 0, height: -10)
        imageLayer.masksToBounds = true
        container.layer?.addSublayer(imageLayer)
        context.coordinator.imageLayer = imageLayer
        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let imageLayer = context.coordinator.imageLayer else { return }
        imageLayer.contents = preview.cgImage(forProposedRect: nil, context: nil, hints: nil)
        imageLayer.frame = resolvedBackdropFrame(
            windowFrame: windowFrame,
            screenFrame: screenFrame
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var imageLayer: CALayer?
    }

    private func resolvedBackdropFrame(windowFrame: CGRect, screenFrame: CGRect) -> CGRect {
        guard screenFrame != .zero else { return windowFrame.integral }

        let screenBounds = CGRect(origin: .zero, size: screenFrame.size)
        let localFrame = CGRect(
            x: windowFrame.minX - screenFrame.minX,
            y: windowFrame.minY - screenFrame.minY,
            width: windowFrame.width,
            height: windowFrame.height
        )
        let fittedFrame = localFrame.intersection(screenBounds)

        guard !fittedFrame.isNull, !fittedFrame.isEmpty else { return screenBounds }
        return CGRect(
            x: floor(fittedFrame.minX),
            y: floor(fittedFrame.minY),
            width: ceil(fittedFrame.width),
            height: ceil(fittedFrame.height)
        )
    }
}

struct SwitcherScreenBackdropView: View {
    @ObservedObject var viewModel: SwitcherViewModel
    @ObservedObject private var preferences = SwitcherPreferences.shared

    var body: some View {
        Group {
            if preferences.showSelectedPreviewBackdrop,
               let preview = selectedBackdropImage {
                SelectedPreviewBackdrop(
                    preview: preview,
                    windowFrame: selectedBackdropFrame,
                    screenFrame: viewModel.backdropScreenFrame,
                    visibleFrame: viewModel.backdropVisibleFrame
                )
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

    private var selectedBackdropFrame: CGRect? {
        selectedItem?.backdropFrame
    }

    private var selectedPreviewIdentity: String {
        selectedItem?.historyIdentity.stableKey ?? "none"
    }
}
