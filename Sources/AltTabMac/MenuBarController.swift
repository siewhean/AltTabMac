import AppKit

final class MenuBarController {

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
        statusItem.button?.toolTip = "Left click to open AltTabMac settings. Right click for quick controls."

        updateMenu()
    }

    func updateMenu() {
        let menu = NSMenu()

        let showBackgroundWindows = NSMenuItem(
            title: "Include Background Windows",
            action: #selector(toggleBackgroundWindows),
            keyEquivalent: ""
        )
        showBackgroundWindows.state = preferences.includeBackgroundWindows ? .on : .off
        showBackgroundWindows.target = self
        menu.addItem(showBackgroundWindows)

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

    @objc private func toggleBackgroundWindows() {
        preferences.includeBackgroundWindows.toggle()
    }

    @objc private func toggleLaunchAtLogin() {
        preferences.launchAtLogin.toggle()
    }

    @objc private func openSettings() {
        preferencesWindowController.show()
    }

    @objc private func handleStatusItemClick() {
        guard let event = NSApp.currentEvent else {
            preferencesWindowController.show()
            return
        }

        if event.type == .rightMouseUp {
            if let menu = contextMenu, let button = statusItem.button {
                menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.maxY), in: button)
            }
        } else {
            preferencesWindowController.show()
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

        ⌘ Tab  — Switch between application windows
        ⌥ Tab  — Same switcher, alternate modifier
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
