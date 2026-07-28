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
    @ObservedObject private var featureHints = SwitcherFeatureHintStore.shared

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch preferences.switcherStyle {
                case .classicGrid:
                    ClassicGridView(viewModel: viewModel)
                case .commandPalette:
                    CommandPaletteView(viewModel: viewModel)
                case .radialMenu:
                    RadialMenuView(viewModel: viewModel)
                }
            }
            .id(preferences.switcherStyle)

            if let hint = featureHints.visibleHint {
                SwitcherFeatureHintBanner(hint: hint)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeOut(duration: 0.18), value: featureHints.visibleHint?.id)
        .onAppear {
            featureHints.presentHint(for: preferences.switcherStyle)
        }
        .onChange(of: preferences.switcherStyle) { style in
            featureHints.presentHint(for: style)
        }
        .onDisappear {
            featureHints.dismiss()
        }
        .task(id: featureHints.visibleHint?.id) {
            guard featureHints.visibleHint != nil else { return }
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            featureHints.dismiss()
        }
    }
}

private struct SwitcherFeatureHintBanner: View {
    let hint: SwitcherFeatureHint

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(hint.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(hint.message)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: 520, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.24), radius: 18, y: 8)
        )
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
    let sourceScreenFrame: CGRect?
    let screenFrame: CGRect

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(0.16)

                if let windowFrame, screenFrame != .zero {
                    let remappedFrame = BackdropGeometry.remappedFrame(
                        windowFrame: windowFrame,
                        sourceScreenFrame: sourceScreenFrame,
                        destinationScreenFrame: screenFrame
                    )
                    let targetFrame = BackdropGeometry.promotedFrame(
                        windowFrame: remappedFrame,
                        screenFrame: screenFrame
                    ) ?? remappedFrame
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
        // The backdrop should adopt the switcher display's geometry without
        // distorting the captured window contents. Fill the remapped frame and
        // crop overflow instead of stretching the image.
        imageLayer.contentsGravity = .resizeAspectFill
        imageLayer.magnificationFilter = .trilinear
        imageLayer.minificationFilter = .trilinear
        imageLayer.backgroundColor = NSColor.clear.cgColor
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

enum BackdropGeometry {
    static func remappedFrame(
        windowFrame: CGRect,
        sourceScreenFrame: CGRect?,
        destinationScreenFrame: CGRect
    ) -> CGRect {
        guard let sourceScreenFrame,
              sourceScreenFrame != .zero,
              destinationScreenFrame != .zero,
              sourceScreenFrame.width > 0,
              sourceScreenFrame.height > 0,
              destinationScreenFrame.width > 0,
              destinationScreenFrame.height > 0 else {
            return windowFrame
        }

        let xScale = destinationScreenFrame.width / sourceScreenFrame.width
        let yScale = destinationScreenFrame.height / sourceScreenFrame.height
        let localWindowFrame = CGRect(
            x: windowFrame.minX - sourceScreenFrame.minX,
            y: windowFrame.minY - sourceScreenFrame.minY,
            width: windowFrame.width,
            height: windowFrame.height
        )

        return CGRect(
            x: destinationScreenFrame.minX + localWindowFrame.minX * xScale,
            y: destinationScreenFrame.minY + localWindowFrame.minY * yScale,
            width: localWindowFrame.width * xScale,
            height: localWindowFrame.height * yScale
        )
    }

    static func promotedFrame(windowFrame: CGRect, screenFrame: CGRect) -> CGRect? {
        guard screenFrame != .zero, screenFrame.width > 0, screenFrame.height > 0 else { return nil }

        let edgeTolerance: CGFloat = 18
        let widthRatio = windowFrame.width / screenFrame.width
        let heightRatio = windowFrame.height / screenFrame.height

        let leftGap = abs(windowFrame.minX - screenFrame.minX)
        let rightGap = abs(windowFrame.maxX - screenFrame.maxX)
        let bottomGap = abs(windowFrame.minY - screenFrame.minY)
        let topGap = abs(windowFrame.maxY - screenFrame.maxY)

        let fillsVisibleDesktop =
            leftGap <= edgeTolerance &&
            rightGap <= edgeTolerance &&
            bottomGap <= edgeTolerance &&
            topGap <= edgeTolerance &&
            widthRatio >= 0.97 &&
            heightRatio >= 0.93

        return fillsVisibleDesktop ? screenFrame : nil
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
                    sourceScreenFrame: selectedBackdropSourceScreenFrame,
                    screenFrame: viewModel.backdropScreenFrame
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

    private var selectedBackdropSourceScreenFrame: CGRect? {
        selectedItem?.backdropSourceScreenFrame
    }

    private var selectedPreviewIdentity: String {
        selectedItem?.historyIdentity.stableKey ?? "none"
    }
}
