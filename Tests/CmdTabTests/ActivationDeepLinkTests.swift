import XCTest
@testable import CmdTab

final class ActivationDeepLinkTests: XCTestCase {
    func testParsesOpaqueActivationCredential() throws {
        let code = "CMDTAB-ACT-" + String(repeating: "A", count: 43)
        let url = try XCTUnwrap(ActivationDeepLink.makeURL(activationCode: code))

        XCTAssertEqual(
            ActivationDeepLink.parse(url),
            ActivationDeepLink(activationCode: code)
        )
    }

    func testParsesLegacySignedKey() throws {
        let code = "CMDTAB1.payload.signature"
        let url = try XCTUnwrap(
            URL(string: "cmdtab://activate?key=\(code)")
        )

        XCTAssertEqual(
            ActivationDeepLink.parse(url)?.activationCode,
            code
        )
    }

    func testRejectsWrongSchemeHostAndUnknownCredentialShape() throws {
        XCTAssertNil(
            ActivationDeepLink.parse(
                try XCTUnwrap(URL(string: "https://activate?code=CMDTAB1.payload.signature"))
            )
        )
        XCTAssertNil(
            ActivationDeepLink.parse(
                try XCTUnwrap(URL(string: "cmdtab://settings?code=CMDTAB1.payload.signature"))
            )
        )
        XCTAssertNil(
            ActivationDeepLink.parse(
                try XCTUnwrap(URL(string: "cmdtab://activate?code=not-a-license"))
            )
        )
    }

    func testRejectsAmbiguousOrOversizedCredentials() throws {
        XCTAssertNil(
            ActivationDeepLink.parse(
                try XCTUnwrap(
                    URL(string: "cmdtab://activate?code=CMDTAB1.a.b&key=CMDTAB1.c.d")
                )
            )
        )
        let oversized = "CMDTAB1." + String(repeating: "a", count: 4_100) + ".b"
        XCTAssertNil(
            ActivationDeepLink.parse(
                try XCTUnwrap(ActivationDeepLink.makeURL(activationCode: oversized))
            )
        )
    }
}
