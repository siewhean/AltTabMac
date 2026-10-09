import Foundation

/// Runs on the event tap's owning run loop. Recovery must not depend on macOS
/// delivering a disabled-tap callback (for example after sleep or a TCC change).
final class EventTapWatchdog {
    private let isTrusted: () -> Bool
    private let hasValidTap: () -> Bool
    private let isEnabled: () -> Bool
    private let reinstall: () -> Void
    private let reenable: () -> Void
    private let suspend: () -> Void
    private var timer: Timer?

    init(
        isTrusted: @escaping () -> Bool,
        hasValidTap: @escaping () -> Bool,
        isEnabled: @escaping () -> Bool,
        reinstall: @escaping () -> Void,
        reenable: @escaping () -> Void,
        suspend: @escaping () -> Void
    ) {
        self.isTrusted = isTrusted
        self.hasValidTap = hasValidTap
        self.isEnabled = isEnabled
        self.reinstall = reinstall
        self.reenable = reenable
        self.suspend = suspend
    }

    deinit { timer?.invalidate() }

    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.checkHealth()
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func checkHealth() {
        guard isTrusted() else {
            if hasValidTap() { suspend() }
            return
        }
        guard hasValidTap() else {
            reinstall()
            return
        }
        if !isEnabled() { reenable() }
    }
}
