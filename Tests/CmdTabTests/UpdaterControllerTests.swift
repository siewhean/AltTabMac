import Foundation
import XCTest
@testable import CmdTab

final class UpdaterControllerTests: XCTestCase {
    private var validConfiguration: [String: Any] {
        [
            "SUFeedURL": UpdaterController.betaFeedURL,
            "SUPublicEDKey": Data(repeating: 0xA5, count: 32).base64EncodedString(),
            "SURequireSignedFeed": true,
            "SUVerifyUpdateBeforeExtraction": true,
        ]
    }

    func testAcceptsValidConfiguration() {
        XCTAssertTrue(UpdaterController.hasValidConfiguration(infoDictionary: validConfiguration))
    }

    func testRejectsInvalidConfiguration() {
        var missingKey = validConfiguration
        missingKey.removeValue(forKey: "SUPublicEDKey")
        XCTAssertFalse(UpdaterController.hasValidConfiguration(infoDictionary: missingKey))

        var insecureFeed = validConfiguration
        insecureFeed["SUFeedURL"] = "http://cmdtab.net/releases/appcast.xml"
        XCTAssertFalse(UpdaterController.hasValidConfiguration(infoDictionary: insecureFeed))

        var stableFeed = validConfiguration
        stableFeed["SUFeedURL"] = "https://cmdtab.net/releases/appcast.xml"
        XCTAssertFalse(UpdaterController.hasValidConfiguration(infoDictionary: stableFeed))

        var shortKey = validConfiguration
        shortKey["SUPublicEDKey"] = Data(repeating: 1, count: 31).base64EncodedString()
        XCTAssertFalse(UpdaterController.hasValidConfiguration(infoDictionary: shortKey))

        var unsignedFeed = validConfiguration
        unsignedFeed["SURequireSignedFeed"] = false
        XCTAssertFalse(UpdaterController.hasValidConfiguration(infoDictionary: unsignedFeed))
    }
}
