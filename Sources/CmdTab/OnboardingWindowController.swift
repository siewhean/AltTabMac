import AppKit
import SwiftUI

@MainActor
final class OnboardingWindowController: NSWindowController {
    init() {
        let preferences = SwitcherPreferences.shared
        let licensingController = LicensingController.shared

        var windowRef: NSWindow?
        let rootView = OnboardingView(
            preferences: preferences,
            licensingController: licensingController,
            onComplete: {
                windowRef?.close()
            }
        )

        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)
        windowRef = window

        window.title = "Welcome to CmdTab"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.center()
        window.setContentSize(NSSize(width: 580, height: 480))
        window.isReleasedWhenClosed = false

        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showOnboardingIfNeeded() {
        if !SwitcherPreferences.shared.hasCompletedOnboarding {
            NSApp.activate(ignoringOtherApps: true)
            showWindow(nil)
            window?.makeKeyAndOrderFront(nil)
        }
    }

    func showOnboarding() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}
