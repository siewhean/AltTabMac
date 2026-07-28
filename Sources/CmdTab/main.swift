import AppKit

// SwiftPM executes this top-level entry point on the process main thread. Make
// that invariant explicit to Swift concurrency before constructing AppKit and
// the @MainActor application delegate.
MainActor.assumeIsolated {
    // Migrate the legacy beta storage domain before any singleton reads
    // UserDefaults or the license Keychain account under the permanent bundle
    // identifier.
    _ = BundleIdentityMigration.migrateIfNeeded()

    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
