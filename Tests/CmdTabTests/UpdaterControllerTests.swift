import Foundation
import Testing
@testable import CmdTab

@Suite("Updater configuration")
struct UpdaterControllerTests {
    private var validConfiguration: [String: Any] {
        [
            "SUFeedURL": "https://cmdtab.net/releases/appcast.xml",
            "SUPublicEDKey": Data(repeating: 0xA5, count: 32).base64EncodedString(),
            "SURequireSignedFeed": true,
            "SUVerifyUpdateBeforeExtraction": true,
        ]
    }

    @Test("accepts a signed HTTPS stable feed")
    func acceptsValidConfiguration() {
        #expect(UpdaterController.hasValidConfiguration(infoDictionary: validConfiguration))
    }

    @Test("rejects missing, malformed, and insecure configuration")
    func rejectsInvalidConfiguration() {
        var missingKey = validConfiguration
        missingKey.removeValue(forKey: "SUPublicEDKey")
        #expect(!UpdaterController.hasValidConfiguration(infoDictionary: missingKey))

        var insecureFeed = validConfiguration
        insecureFeed["SUFeedURL"] = "http://cmdtab.net/releases/appcast.xml"
        #expect(!UpdaterController.hasValidConfiguration(infoDictionary: insecureFeed))

        var shortKey = validConfiguration
        shortKey["SUPublicEDKey"] = Data(repeating: 1, count: 31).base64EncodedString()
        #expect(!UpdaterController.hasValidConfiguration(infoDictionary: shortKey))

        var unsignedFeed = validConfiguration
        unsignedFeed["SURequireSignedFeed"] = false
        #expect(!UpdaterController.hasValidConfiguration(infoDictionary: unsignedFeed))
    }
}
