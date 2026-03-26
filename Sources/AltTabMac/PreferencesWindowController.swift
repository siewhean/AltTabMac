import AppKit
import SwiftUI

final class PreferencesWindowController: NSWindowController {
    var onOpenApplications: (() -> Void)?

    init() {
        let rootView = PreferencesView(
            preferences: SwitcherPreferences.shared,
            onOpenApplications: { }
        )
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)

        window.title = "AltTabMac Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.center()
        window.setContentSize(NSSize(width: 620, height: 640))
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.fullScreenAuxiliary]

        super.init(window: window)
        refreshContent()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        refreshContent()
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    private func refreshContent() {
        guard let hostingController = window?.contentViewController as? NSHostingController<PreferencesView> else { return }
        hostingController.rootView = PreferencesView(
            preferences: SwitcherPreferences.shared,
            onOpenApplications: { [weak self] in self?.onOpenApplications?() }
        )
    }
}
