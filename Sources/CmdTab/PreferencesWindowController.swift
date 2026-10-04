import AppKit
import SwiftUI

final class PreferencesWindowController: NSWindowController {
    var onOpenApplications: (() -> Void)?
    var onRefreshPreviews: (() -> Void)?
    var onApplySwitcherStyle: ((SwitcherStyle) -> Void)?
    var onOpenOnboarding: (() -> Void)?
    private var preferredInitialPane: PreferencesPaneSelection = .appearance

    private let styleChangeHUDController = StyleChangeHUDController()

    init() {
        let rootView = PreferencesView(
            preferences: SwitcherPreferences.shared,
            onOpenApplications: { },
            onRefreshPreviews: { },
            onApplySwitcherStyle: { _ in },
            onOpenOnboarding: { },
            initialPane: .appearance
        )
        let hostingController = NSHostingController(rootView: rootView)
        // AppKit owns this fixed-size window. Avoid deriving its initial size
        // from a GeometryReader while the hosting hierarchy is being laid out.
        hostingController.sizingOptions = []
        let contentSize = NSSize(width: 720, height: 760)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = "CmdTab Settings"
        window.identifier = SettingsWindowVisibilityPolicy.settingsIdentifier
        // Reserve native titlebar space for the screen-sharing indicator:
        // macOS 26 reported negative geometry in _positionSharingIndicator
        // while the previous full-size transparent window was captured.
        window.titlebarAppearsTransparent = false
        window.titleVisibility = .visible
        window.contentViewController = hostingController
        window.setContentSize(contentSize)
        window.contentMinSize = contentSize
        window.isRestorable = false
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.fullScreenAuxiliary]
        window.center()

        super.init(window: window)
        refreshContent()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        show(initialPane: .appearance)
    }

    func show(initialPane: PreferencesPaneSelection) {
        preferredInitialPane = initialPane
        refreshContent()
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    func showLicensing() {
        show(initialPane: .licensing)
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
            onApplySwitcherStyle: { [weak self] style in self?.onApplySwitcherStyle?(style) },
            onOpenOnboarding: { [weak self] in self?.onOpenOnboarding?() },
            initialPane: preferredInitialPane
        )
    }
}
