import AppKit

/// Settings are opened explicitly from the menu, never as a side effect of
/// activating CmdTab for a shortcut. Ordering out preserves unsaved drafts.
enum SettingsWindowVisibilityPolicy {
    static let settingsIdentifier = NSUserInterfaceItemIdentifier("CmdTab.Settings")
    static let profilesIdentifier = NSUserInterfaceItemIdentifier("CmdTab.ShortcutProfiles")

    static func hideSettings(in windows: [NSWindow]) {
        for window in windows where window.identifier == settingsIdentifier
            || window.identifier == profilesIdentifier {
            window.orderOut(nil)
        }
    }

    static func handleReopen(onboardingWindow: NSWindow?) -> Bool {
        if onboardingWindow?.isVisible == true {
            onboardingWindow?.makeKeyAndOrderFront(nil)
        }
        return false
    }
}
