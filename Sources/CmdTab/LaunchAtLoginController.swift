import Foundation
import ServiceManagement

final class LaunchAtLoginController {
    static let shared = LaunchAtLoginController()

    private init() {}

    func sync(enabled: Bool) {
        guard #available(macOS 13.0, *) else { return }

        let service = SMAppService.mainApp
        do {
            switch (enabled, service.status) {
            case (true, .enabled):
                break
            case (true, _):
                try service.register()
            case (false, .enabled):
                try service.unregister()
            case (false, _):
                break
            }
        } catch {
            print("[CmdTab] Failed to update launch-at-login status: \(error)")
        }
    }
}
