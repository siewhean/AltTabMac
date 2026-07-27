import Foundation
import Sparkle

@MainActor
final class UpdaterController {
    static let shared = UpdaterController()

    private let standardController: SPUStandardUpdaterController?

    var isConfigured: Bool {
        standardController != nil
    }

    init(bundle: Bundle = .main) {
        guard Self.hasValidConfiguration(in: bundle) else {
            standardController = nil
            return
        }

        standardController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    func checkForUpdates() {
        guard standardController?.updater.canCheckForUpdates == true else {
            return
        }
        standardController?.checkForUpdates(nil)
    }

    nonisolated static func hasValidConfiguration(in bundle: Bundle) -> Bool {
        hasValidConfiguration(infoDictionary: bundle.infoDictionary ?? [:])
    }

    nonisolated static func hasValidConfiguration(infoDictionary: [String: Any]) -> Bool {
        guard
            let feed = infoDictionary["SUFeedURL"] as? String,
            let feedURL = URL(string: feed),
            feedURL.scheme == "https",
            feedURL.host?.isEmpty == false,
            let publicKey = infoDictionary["SUPublicEDKey"] as? String,
            let decodedKey = Data(base64Encoded: publicKey),
            decodedKey.count == 32,
            infoDictionary["SURequireSignedFeed"] as? Bool == true,
            infoDictionary["SUVerifyUpdateBeforeExtraction"] as? Bool == true
        else {
            return false
        }
        return true
    }
}
