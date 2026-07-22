import AppKit

// Migrate the legacy beta storage domain before any singleton reads UserDefaults
// or the license Keychain account under the permanent bundle identifier.
_ = BundleIdentityMigration.migrateIfNeeded()

// SPM executable entry point
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
