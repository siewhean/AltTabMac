import AppKit
let app = NSApplication.shared
app.setActivationPolicy(.regular)
let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 720, height: 760), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
window.title = "Native Geometry Fixture"
window.isReleasedWhenClosed = false
let label = NSTextField(labelWithString: "Plain AppKit window. No SwiftUI or CmdTab code.")
label.frame = NSRect(x: 24, y: 350, width: 650, height: 40)
window.contentView?.addSubview(label)
window.center()
window.makeKeyAndOrderFront(nil)
app.activate(ignoringOtherApps: true)
app.run()
