import AppKit
import SwiftUI

final class StyleChangeHUDController {
    private var panel: NSPanel?
    private var hostingView: NSHostingView<StyleChangeHUDView>?
    private var dismissWorkItem: DispatchWorkItem?

    func show(style: SwitcherStyle, on screen: NSScreen?) {
        let targetScreen = screen ?? NSScreen.main ?? NSScreen.screens.first

        if panel == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 188, height: 152),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: true
            )
            panel.level = .statusBar
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.ignoresMouseEvents = true
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]

            let rootView = StyleChangeHUDView(
                style: style,
                enableVibrancy: SwitcherPreferences.shared.enableVibrancy
            )
            let hostingView = NSHostingView(rootView: rootView)
            hostingView.translatesAutoresizingMaskIntoConstraints = false
            panel.contentView = hostingView
            self.panel = panel
            self.hostingView = hostingView
        }

        hostingView?.rootView = StyleChangeHUDView(
            style: style,
            enableVibrancy: SwitcherPreferences.shared.enableVibrancy
        )

        let size = NSSize(width: 188, height: 152)
        panel?.setContentSize(size)

        if let targetScreen {
            let frame = targetScreen.visibleFrame
            panel?.setFrameOrigin(
                NSPoint(
                    x: frame.midX - size.width / 2,
                    y: frame.midY - size.height / 2 + 30
                )
            )
        }

        dismissWorkItem?.cancel()
        panel?.alphaValue = 0
        panel?.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel?.animator().alphaValue = 1
        }

        let dismissWorkItem = DispatchWorkItem { [weak self] in
            guard let self, let panel = self.panel else { return }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.16
                panel.animator().alphaValue = 0
            }, completionHandler: {
                panel.orderOut(nil)
            })
        }

        self.dismissWorkItem = dismissWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9, execute: dismissWorkItem)
    }
}

private struct StyleChangeHUDView: View {
    let style: SwitcherStyle
    let enableVibrancy: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.black.opacity(enableVibrancy ? 0.22 : 0.88))
                .background(
                    Group {
                        if enableVibrancy {
                            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                        } else {
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .fill(Color(red: 0.10, green: 0.10, blue: 0.12))
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(enableVibrancy ? 0.14 : 0.08), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.22), radius: 28, x: 0, y: 12)

            VStack(spacing: 12) {
                Image(systemName: style.systemImage)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.white.opacity(0.92))
                    .frame(width: 54, height: 54)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(enableVibrancy ? 0.10 : 0.07))
                    )

                VStack(spacing: 4) {
                    Text(style.title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Switcher Style")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.48))
                }
            }
            .padding(.vertical, 22)
            .padding(.horizontal, 18)
        }
        .frame(width: 188, height: 152)
    }
}
