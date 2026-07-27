import AppKit

/// Debounces display-connect, disconnect, resolution, scaling, and wake changes.
/// The production switcher uses this to invalidate workspace/window metadata and
/// reposition any visible primary or mirrored panels without showing a hidden
/// switcher unexpectedly.
final class ScreenTopologyObserver {
    private struct Observation {
        let center: NotificationCenter
        let token: NSObjectProtocol
    }

    private var observations: [Observation] = []
    private var pendingRefresh: DispatchWorkItem?
    private let callback: () -> Void

    init(callback: @escaping () -> Void) {
        self.callback = callback

        let screenCenter = NotificationCenter.default
        let screenToken = screenCenter.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleRefresh()
        }

        let workspaceCenter = NSWorkspace.shared.notificationCenter
        let wakeToken = workspaceCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleRefresh()
        }

        observations = [
            Observation(center: screenCenter, token: screenToken),
            Observation(center: workspaceCenter, token: wakeToken),
        ]
    }

    deinit {
        pendingRefresh?.cancel()
        for observation in observations {
            observation.center.removeObserver(observation.token)
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