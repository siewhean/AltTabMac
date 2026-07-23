import AppKit

/// Debounces display-connect, disconnect, resolution, scaling, and wake changes.
/// The production switcher uses this to invalidate workspace/window metadata and
/// reposition any visible primary or mirrored panels without showing a hidden
/// switcher unexpectedly.
final class ScreenTopologyObserver {
    private var notificationTokens: [NSObjectProtocol] = []
    private var pendingRefresh: DispatchWorkItem?
    private let callback: () -> Void

    init(callback: @escaping () -> Void) {
        self.callback = callback

        let screenToken = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleRefresh()
        }

        let wakeToken = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleRefresh()
        }

        notificationTokens = [screenToken, wakeToken]
    }

    deinit {
        pendingRefresh?.cancel()
        for token in notificationTokens {
            NotificationCenter.default.removeObserver(token)
            NSWorkspace.shared.notificationCenter.removeObserver(token)
        }
    }

    private func scheduleRefresh() {
        pendingRefresh?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingRefresh = nil
            self.callback()
        }
        pendingRefresh = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: item)
    }
}