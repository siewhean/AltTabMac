import AppKit
import SwiftUI

final class PreferencesWindowController: NSWindowController {
    var onOpenApplications: (() -> Void)?
    var onRefreshPreviews: (() -> Void)?
    var onApplySwitcherStyle: ((SwitcherStyle) -> Void)?

    private let styleChangeHUDController = StyleChangeHUDController()

    init() {
        let rootView = PreferencesView(
            preferences: SwitcherPreferences.shared,
            onOpenApplications: { },
            onRefreshPreviews: { },
            onApplySwitcherStyle: { _ in }
        )
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)

        window.title = "CmdTab Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.titlebarSeparatorStyle = .none
        window.center()
        window.setContentSize(NSSize(width: 720, height: 760))
        window.minSize = NSSize(width: 720, height: 760)
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

    func showStyleChangeHUD(for style: SwitcherStyle) {
        styleChangeHUDController.show(style: style, on: window?.screen)
    }

    private func refreshContent() {
        guard let hostingController = window?.contentViewController as? NSHostingController<PreferencesView> else { return }
        hostingController.rootView = PreferencesView(
            preferences: SwitcherPreferences.shared,
            onOpenApplications: { [weak self] in self?.onOpenApplications?() },
            onRefreshPreviews: { [weak self] in self?.onRefreshPreviews?() },
            onApplySwitcherStyle: { [weak self] style in self?.onApplySwitcherStyle?(style) }
        )
    }
}
