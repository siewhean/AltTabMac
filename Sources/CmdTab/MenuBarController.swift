import AppKit

final class MenuBarController {

    private static var sharedStatusItem: NSStatusItem?
    private var statusItem: NSStatusItem!
    private let preferences = SwitcherPreferences.shared
    private let preferencesWindowController: PreferencesWindowController
    private lazy var profilePreferencesWindowController = ProductionProfilePreferencesWindowController()
    private lazy var diagnosticsWindowController = ProductionDiagnosticsWindowController()
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
            name: SwitcherProfileStore.didChangeNotification,
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
        statusItem.button?.image = NSImage(
            systemSymbolName: "arrow.right.arrow.left",
            accessibilityDescription: "CmdTab"
        )
        statusItem.button?.image?.isTemplate = true
        statusItem.button?.target = self
        statusItem.button?.action = #selector(handleStatusItemClick)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem.button?.toolTip = "Left click to open CmdTab settings. Right click for quick controls."

        updateMenu()
    }

    func updateMenu() {
        let menu = NSMenu()

        let profilesItem = NSMenuItem(
            title: "Shortcut Profiles…",
            action: #selector(openShortcutProfiles),
            keyEquivalent: ""
        )
        profilesItem.target = self
        menu.addItem(profilesItem)

        let visibilityMenuItem = NSMenuItem(
            title: "Window Visibility",
            action: nil,
            keyEquivalent: ""
        )
        visibilityMenuItem.submenu = visibilitySubmenu()
        menu.addItem(visibilityMenuItem)

        let displayMenuItem = NSMenuItem(
            title: "Display Target",
            action: nil,
            keyEquivalent: ""
        )
        displayMenuItem.submenu = displaySubmenu()
        menu.addItem(displayMenuItem)

        let minimizedItem = NSMenuItem(
            title: "Include Minimized Windows",
            action: #selector(toggleIncludeMinimizedWindows),
            keyEquivalent: ""
        )
        minimizedItem.state = preferences.includeMinimizedWindows ? .on : .off
        minimizedItem.target = self
        menu.addItem(minimizedItem)

        let alternateTriggerMenuItem = NSMenuItem(
            title: "Hot Swap Shortcut",
            action: nil,
            keyEquivalent: ""
        )
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

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        let diagnosticsItem = NSMenuItem(
            title: "Diagnostics…",
            action: #selector(openDiagnostics),
            keyEquivalent: ""
        )
        diagnosticsItem.target = self
        menu.addItem(diagnosticsItem)

        let licensingItem = NSMenuItem(
            title: "Licensing…",
            action: #selector(openLicensing),
            keyEquivalent: ""
        )
        licensingItem.target = self
        menu.addItem(licensingItem)

        let buyItem = NSMenuItem(
            title: "Buy CmdTab",
            action: #selector(openBuyPage),
            keyEquivalent: ""
        )
        buyItem.target = self
        menu.addItem(buyItem)

        let aboutItem = NSMenuItem(
            title: "About CmdTab",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: "Quit CmdTab",
            action: #selector(quitCmdTab),
            keyEquivalent: "q"
        )
        quit.target = self
        menu.addItem(quit)

        contextMenu = menu
        statusItem.menu = nil
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
            .rightOptionDoubleTap,
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

    @objc private func toggleIncludeMinimizedWindows() {
        preferences.includeMinimizedWindows.toggle()
    }

    @objc private func toggleLaunchAtLogin() {
        preferences.launchAtLogin.toggle()
    }

    @objc private func openShortcutProfiles() {
        profilePreferencesWindowController.show()
    }

    @objc private func openSettings() {
        preferencesWindowController.show(initialPane: .general)
    }

    @objc private func openDiagnostics() {
        diagnosticsWindowController.show()
    }

    @objc private func openLicensing() {
        preferencesWindowController.showLicensing()
    }

    @objc private func openBuyPage() {
        MainActor.assumeIsolated {
            LicensingController.shared.openBuyPage()
        }
    }

    @objc private func quitCmdTab() {
        (NSApp.delegate as? AppDelegate)?.requestTermination()
    }

    @objc private func handleStatusItemClick() {
        guard let event = NSApp.currentEvent else {
            preferencesWindowController.show()
            return
        }

        if event.type == .rightMouseUp {
            if let menu = contextMenu, let button = statusItem.button {
                menu.popUp(
                    positioning: nil,
                    at: NSPoint(x: 0, y: button.bounds.maxY),
                    in: button
                )
            }
        } else {
            preferencesWindowController.show()
        }
    }

    @objc private func handlePreferencesDidChange() {
        updateMenu()
    }

    @objc private func showAbout() {
        let profileCount = SwitcherProfileStore.shared.profilesSnapshot().filter(\.isEnabled).count
        let alert = NSAlert()
        alert.messageText = "CmdTab"
        alert.informativeText = """
        Exact-window switching for macOS.

        \(profileCount) shortcut profile\(profileCount == 1 ? "" : "s") enabled.
        Right-click the menu-bar item to edit profiles, include minimized windows, and change visibility or display scope.

        Hold a profile's primary modifier and press its shortcut repeatedly to cycle, or use a press-to-toggle profile and press Return to commit. Escape always cancels.

        Right-click the visible switcher for exact-window restore, fullscreen, display movement, centering, tiling, and force-quit actions.

        Open Diagnostics from the menu-bar menu to inspect sanitized permission, profile, workspace, and durable-MRU status.

        Grant Accessibility access in:
        System Settings → Privacy & Security → Accessibility
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}