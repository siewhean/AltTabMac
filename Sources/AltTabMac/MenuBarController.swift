import AppKit

final class MenuBarController {

    private var statusItem: NSStatusItem!
    private let preferences = SwitcherPreferences.shared
    private let preferencesWindowController: PreferencesWindowController
    private let onActivatePrimarySwitcher: () -> Void
    private var contextMenu: NSMenu?

    init(
        preferencesWindowController: PreferencesWindowController,
        onActivatePrimarySwitcher: @escaping () -> Void
    ) {
        self.preferencesWindowController = preferencesWindowController
        self.onActivatePrimarySwitcher = onActivatePrimarySwitcher
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePreferencesDidChange),
            name: SwitcherPreferences.didChangeNotification,
            object: nil
        )
        build()
    }

    private func build() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "arrow.right.arrow.left",
                                           accessibilityDescription: "AltTabMac")
        statusItem.button?.image?.isTemplate = true   // adapts to dark/light menu bar
        statusItem.button?.target = self
        statusItem.button?.action = #selector(handleStatusItemClick)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem.button?.toolTip = "Left click to open the AltTab switcher. Right click for settings and quick controls."

        updateMenu()
    }

    func updateMenu() {
        let menu = NSMenu()

        let primaryHeader = NSMenuItem(title: "Primary Switcher", action: nil, keyEquivalent: "")
        primaryHeader.isEnabled = false
        menu.addItem(primaryHeader)

        let appsItem = NSMenuItem(
            title: "⌘ Tab  →  Applications",
            action: #selector(selectApplications),
            keyEquivalent: ""
        )
        appsItem.state = preferences.primaryMode == .app ? .on : .off
        appsItem.target = self
        menu.addItem(appsItem)

        let tabsItem = NSMenuItem(
            title: "⌘ Tab  →  Browser Tabs",
            action: #selector(selectBrowserTabs),
            keyEquivalent: ""
        )
        tabsItem.state = preferences.primaryMode == .tab ? .on : .off
        tabsItem.target = self
        menu.addItem(tabsItem)

        let alternateItem = NSMenuItem(title: "⌥ Tab  →  Alternate Mode", action: nil, keyEquivalent: "")
        alternateItem.isEnabled = false
        menu.addItem(alternateItem)

        menu.addItem(.separator())

        let showBackgroundWindows = NSMenuItem(
            title: "Include Background Windows",
            action: #selector(toggleBackgroundWindows),
            keyEquivalent: ""
        )
        showBackgroundWindows.state = preferences.includeBackgroundWindows ? .on : .off
        showBackgroundWindows.target = self
        menu.addItem(showBackgroundWindows)

        let includeBrowserTabs = NSMenuItem(
            title: "Include Browser Tabs In App Switcher",
            action: #selector(toggleIncludeBrowserTabs),
            keyEquivalent: ""
        )
        includeBrowserTabs.state = preferences.includeTabsInAppSwitcher ? .on : .off
        includeBrowserTabs.target = self
        menu.addItem(includeBrowserTabs)

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

        // ── About / help ─────────────────────────────────────────────────────
        let aboutItem = NSMenuItem(title: "About AltTabMac", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit AltTabMac", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        self.contextMenu = menu
        self.statusItem.menu = nil
    }

    @objc private func selectApplications() {
        preferences.primaryMode = .app
        updateMenu()
    }

    @objc private func selectBrowserTabs() {
        preferences.primaryMode = .tab
        updateMenu()
    }

    @objc private func toggleBackgroundWindows() {
        preferences.includeBackgroundWindows.toggle()
    }

    @objc private func toggleIncludeBrowserTabs() {
        preferences.includeTabsInAppSwitcher.toggle()
    }

    @objc private func toggleLaunchAtLogin() {
        preferences.launchAtLogin.toggle()
    }

    @objc private func openSettings() {
        preferencesWindowController.show()
    }

    @objc private func handleStatusItemClick() {
        guard let event = NSApp.currentEvent else {
            onActivatePrimarySwitcher()
            return
        }

        if event.type == .rightMouseUp {
            if let menu = contextMenu, let button = statusItem.button {
                menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.maxY), in: button)
            }
        } else {
            onActivatePrimarySwitcher()
        }
    }

    @objc private func handlePreferencesDidChange() {
        updateMenu()
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText    = "AltTabMac"
        alert.informativeText = """
        Windows-style Alt+Tab for macOS.

        ⌘ Tab  — Switch with your selected primary mode
        ⌥ Tab  — Open the alternate mode
        Left click  — Open the live switcher
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
