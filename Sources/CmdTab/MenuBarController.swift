import AppKit

final class MenuBarController {

    private static var sharedStatusItem: NSStatusItem?
    private var statusItem: NSStatusItem!
    private let preferences = SwitcherPreferences.shared
    private let preferencesWindowController: PreferencesWindowController
    private var contextMenu: NSMenu?

    init(
        preferencesWindowController: PreferencesWindowController
    ) {
        self.preferencesWindowController = preferencesWindowController
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePreferencesDidChange),
            name: SwitcherPreferences.didChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePreferencesDidChange),
            name: LicensingController.didChangeNotification,
            object: nil
        )
        build()
    }

    private func build() {
        if let existingStatusItem = Self.sharedStatusItem {
            NSStatusBar.system.removeStatusItem(existingStatusItem)
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        Self.sharedStatusItem = statusItem
        statusItem.button?.image = NSImage(systemSymbolName: "arrow.right.arrow.left",
                                           accessibilityDescription: "CmdTab")
        statusItem.button?.image?.isTemplate = true   // adapts to dark/light menu bar
        statusItem.button?.target = self
        statusItem.button?.action = #selector(handleStatusItemClick)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem.button?.toolTip = "Left click to open CmdTab settings. Right click for quick controls."

        updateMenu()
    }

    private func trialStatusMenuItem() -> NSMenuItem {
        let status = MainActor.assumeIsolated { LicensingController.shared.status }
        let title: String
        switch status {
        case let .activeTrial(_, _, daysRemaining):
            title = daysRemaining == 1 ? "Trial: 1 day remaining" : "Trial: \(daysRemaining) days remaining"
        case .expired:
            title = "Trial Expired — Buy License to Activate"
        case let .licensed(payload, _):
            title = "CmdTab Licensed (\(payload.email))"
        case .unregistered:
            title = "Trial: Unregistered"
        }
        let item = NSMenuItem(title: title, action: #selector(openLicensing), keyEquivalent: "")
        item.target = self
        return item
    }

    func updateMenu() {
        let menu = NSMenu()

        menu.addItem(trialStatusMenuItem())
        menu.addItem(.separator())

        let visibilityMenuItem = NSMenuItem(title: "Window Visibility", action: nil, keyEquivalent: "")
        visibilityMenuItem.submenu = visibilitySubmenu()
        menu.addItem(visibilityMenuItem)

        let displayMenuItem = NSMenuItem(title: "Display Target", action: nil, keyEquivalent: "")
        displayMenuItem.submenu = displaySubmenu()
        menu.addItem(displayMenuItem)

        let alternateTriggerMenuItem = NSMenuItem(title: "Hot Swap Shortcut", action: nil, keyEquivalent: "")
        alternateTriggerMenuItem.submenu = alternateTriggerSubmenu()
        menu.addItem(alternateTriggerMenuItem)

        let launchAtLogin = NSMenuItem(
            title: "Launch At Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchAtLogin.state = preferences.launchAtLogin ? .on : .off
        launchAtLogin.target = self
        menu.addItem(launchAtLogin)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let licensingItem = NSMenuItem(title: "Licensing…", action: #selector(openLicensing), keyEquivalent: "")
        licensingItem.target = self
        menu.addItem(licensingItem)

        let buyItem = NSMenuItem(title: "Buy CmdTab", action: #selector(openBuyPage), keyEquivalent: "")
        buyItem.target = self
        menu.addItem(buyItem)

        let feedbackItem = NSMenuItem(title: "Send Feedback…", action: #selector(sendFeedback), keyEquivalent: "")
        feedbackItem.target = self
        menu.addItem(feedbackItem)

        // ── About / help ─────────────────────────────────────────────────────
        let aboutItem = NSMenuItem(title: "About CmdTab", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit CmdTab", action: #selector(quitCmdTab), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        self.contextMenu = menu
        self.statusItem.menu = nil
    }

    private func visibilitySubmenu() -> NSMenu {
        let menu = NSMenu()

        for scope in WindowVisibilityScope.allCases {
            let item = NSMenuItem(
                title: scope.title,
                action: #selector(setWindowVisibilityScope(_:)),
                keyEquivalent: ""
            )
            item.state = preferences.windowVisibilityScope == scope ? .on : .off
            item.target = self
            item.representedObject = scope.rawValue
            menu.addItem(item)
        }

        return menu
    }

    private func displaySubmenu() -> NSMenu {
        let menu = NSMenu()

        for displayPreference in SwitcherDisplayPreference.allCases {
            let item = NSMenuItem(
                title: displayPreference.title,
                action: #selector(setDisplayPreference(_:)),
                keyEquivalent: ""
            )
            item.state = preferences.displayPlacement == displayPreference ? .on : .off
            item.target = self
            item.representedObject = displayPreference.rawValue
            menu.addItem(item)
        }

        return menu
    }

    private func alternateTriggerSubmenu() -> NSMenu {
        let menu = NSMenu()

        for trigger in hotSwapShortcutModes {
            let item = NSMenuItem(
                title: trigger.title,
                action: #selector(setAlternateTrigger(_:)),
                keyEquivalent: ""
            )
            item.state = preferences.alternateTrigger == trigger ? .on : .off
            item.target = self
            item.representedObject = trigger.rawValue
            menu.addItem(item)
        }

        return menu
    }

    private var hotSwapShortcutModes: [AlternateTriggerMode] {
        [
            .disabled,
            .leftCommandDoubleTap,
            .rightCommandDoubleTap,
            .leftOptionDoubleTap,
            .rightOptionDoubleTap
        ]
    }

    @objc private func setWindowVisibilityScope(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let scope = WindowVisibilityScope(rawValue: rawValue) else {
            return
        }
        preferences.windowVisibilityScope = scope
    }

    @objc private func setDisplayPreference(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let displayPreference = SwitcherDisplayPreference(rawValue: rawValue) else {
            return
        }
        preferences.displayPlacement = displayPreference
    }

    @objc private func setAlternateTrigger(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let trigger = AlternateTriggerMode(rawValue: rawValue) else {
            return
        }
        preferences.alternateTrigger = trigger
    }

    @objc private func toggleLaunchAtLogin() {
        preferences.launchAtLogin.toggle()
    }

    @objc private func openSettings() {
        preferencesWindowController.show(initialPane: .general)
    }

    @objc private func openLicensing() {
        preferencesWindowController.showLicensing()
    }

    @objc private func openBuyPage() {
        MainActor.assumeIsolated {
            LicensingController.shared.openBuyPage()
        }
    }

    @objc private func sendFeedback() {
        NSWorkspace.shared.open(FeedbackConfiguration.reportBugURL)
    }

    @objc private func quitCmdTab() {
        (NSApp.delegate as? AppDelegate)?.requestTermination()
    }

    @objc private func handleStatusItemClick() {
        guard let event = NSApp.currentEvent else {
            dismissContextMenuIfNeeded()
            preferencesWindowController.show()
            return
        }

        if event.type == .rightMouseUp {
            dismissContextMenuIfNeeded()
            if let menu = contextMenu, let button = statusItem.button {
                menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.maxY), in: button)
            }
        } else {
            dismissContextMenuIfNeeded()
            preferencesWindowController.show()
        }
    }

    func dismissContextMenu() {
        dismissContextMenuIfNeeded()
    }

    private func dismissContextMenuIfNeeded() {
        contextMenu?.cancelTracking()
    }

    @objc private func handlePreferencesDidChange() {
        updateMenu()
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText    = "CmdTab"
        alert.informativeText = """
        Windows-style Alt+Tab for macOS.

        ⌘ Tab  — Switch between application windows
        ⌥ Tab  — Same switcher, alternate modifier
        Optional hot swap shortcut  — Instantly switches to the latest item
        Left click  — Open settings
        Right click  — Open settings and quick controls

        Hold the modifier and press Tab repeatedly to cycle.
        Release to activate the highlighted item.
        Press Escape to dismiss without switching.

        Grant Accessibility access in:
        System Settings → Privacy & Security → Accessibility
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
