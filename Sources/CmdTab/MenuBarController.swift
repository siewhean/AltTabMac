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
        statusItem.button?.toolTip = "Click for CmdTab controls and settings."

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

        let reverseHelp = NSMenuItem(
            title: "Reverse Cycle: ⇧⌘Tab or ⇧⌥Tab",
            action: nil,
            keyEquivalent: ""
        )
        reverseHelp.isEnabled = false
        menu.addItem(reverseHelp)
        menu.addItem(.separator())

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
            title: "Show Minimized Windows",
            action: #selector(toggleIncludeMinimizedWindows),
            keyEquivalent: ""
        )
        minimizedItem.state = preferences.includeMinimizedWindows ? .on : .off
        minimizedItem.toolTip = "Turn the checkmark off to exclude minimized windows."
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
        AlternateTriggerMode.productionHotSwapModes
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
        preferences.alternateTrigger = trigger.productionSafeMode
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
        guard let menu = contextMenu,
              let button = statusItem.button else {
            preferencesWindowController.show()
            return
        }
        menu.popUp(
            positioning: nil,
            at: NSPoint(x: 0, y: button.bounds.maxY),
            in: button
        )
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
        Click the menu-bar item to edit profiles, show or hide minimized windows, and change visibility or display scope.

        Press a profile's modifier and key as one deliberate chord. Holding Command or Option first and pressing Tab later is ignored. Quick release switches without opening the overlay; keep the modifier held to show it. Use Shift with Command-Tab or Option-Tab to cycle in reverse, or use the arrow keys while the overlay is visible.

        Optional Hot Swap accepts a short same-side Command double tap completed within 250 ms, or a same-side Command+Option chord pressed within 160 ms. One Command or Option press does nothing, and delayed taps or chords are ignored.

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
