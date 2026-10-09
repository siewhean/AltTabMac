import Foundation

/// A dedicated, high-priority thread whose run loop services the keyboard
/// event tap. With the tap on the main run loop, every keystroke and scroll
/// event on the Mac waited for CmdTab's main thread, which also performs
/// Accessibility IPC, window inventory, and UI work; a stall there lagged
/// typing system-wide and let macOS disable the tap.
final class EventTapRunLoopThread: @unchecked Sendable {
    static let shared = EventTapRunLoopThread()

    let runLoop: CFRunLoop
    private let thread: Thread

    private init() {
        let ready = DispatchSemaphore(value: 0)
        var startedRunLoop: CFRunLoop?
        thread = Thread {
            startedRunLoop = CFRunLoopGetCurrent()
            // A run loop with no sources returns immediately; the port keeps
            // it alive between tap installations.
            RunLoop.current.add(NSMachPort(), forMode: .default)
            ready.signal()
            while true {
                RunLoop.current.run(mode: .default, before: .distantFuture)
            }
        }
        thread.name = "CmdTab.EventTap"
        thread.qualityOfService = .userInteractive
        thread.start()
        ready.wait()
        runLoop = startedRunLoop!
    }

    var isCurrent: Bool { Thread.current == thread }
}
