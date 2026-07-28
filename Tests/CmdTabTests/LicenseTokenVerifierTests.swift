import CryptoKit
import Foundation
import XCTest
@testable import CmdTab

final class LicenseTokenVerifierTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testV2PaidLicenseVerifiesOfflineWithoutExpiry() throws {
        let key = P256.Signing.PrivateKey()
        let payload = makeV2Payload(
            kid: "license-2026-01",
            typ: .license,
            bindingType: .activation,
            bindingValue: "activation-secret",
            issuedAt: Int64(now.timeIntervalSince1970),
            expiresAt: nil
        )
        let token = try signV2(payload, with: key)
        let verifier = makeVerifier(kid: payload.kid, key: key)

        let result = try verifier.verify(
            token,
            context: LicenseTokenVerificationContext(
                expectedType: .license,
                expectedBinding: (.activation, "activation-secret"),
                now: now.addingTimeInterval(10 * 365 * 24 * 60 * 60)
            )
        )

        XCTAssertEqual(result, .tokenV2(payload))
        XCTAssertEqual(payload.updates, "1.x")
        XCTAssertNil(payload.exp)
    }

    func testV2TrialRequiresExactFourteenDayExpiryAndInstallBinding() throws {
        let key = P256.Signing.PrivateKey()
        let issuedAt = Int64(now.timeIntervalSince1970)
        let payload = makeV2Payload(
            kid: "trial-2026-01",
            typ: .trial,
            bindingType: .install,
            bindingValue: "install-secret",
            issuedAt: issuedAt,
            expiresAt: issuedAt + 14 * 24 * 60 * 60
        )
        let verifier = makeVerifier(kid: payload.kid, key: key)
        let token = try signV2(payload, with: key)

        XCTAssertNoThrow(
            try verifier.verify(
                token,
                context: LicenseTokenVerificationContext(
                    expectedType: .trial,
                    expectedBinding: (.install, "install-secret"),
                    now: now
                )
            )
        )
        XCTAssertThrowsError(
            try verifier.verify(
                token,
                context: LicenseTokenVerificationContext(
                    expectedType: .trial,
                    expectedBinding: (.install, "different-install"),
                    now: now
                )
            )
        ) {
            XCTAssertEqual($0 as? LicenseTokenVerificationError, .bindingMismatch)
        }
        XCTAssertThrowsError(
            try verifier.verify(
                token,
                context: LicenseTokenVerificationContext(
                    expectedType: .trial,
                    expectedBinding: (.install, "install-secret"),
                    now: Date(timeIntervalSince1970: TimeInterval(payload.exp!))
                )
            )
        ) {
            XCTAssertEqual($0 as? LicenseTokenVerificationError, .expired)
        }
    }

    func testUnknownKidAndTamperedClaimsFailClosed() throws {
        let key = P256.Signing.PrivateKey()
        let payload = makeV2Payload(
            kid: "license-retired",
            typ: .license,
            bindingType: .activation,
            bindingValue: "binding",
            issuedAt: Int64(now.timeIntervalSince1970),
            expiresAt: nil
        )
        let token = try signV2(payload, with: key)
        let otherKey = P256.Signing.PrivateKey()

        XCTAssertThrowsError(try makeVerifier(kid: "different", key: key).verify(token)) {
            XCTAssertEqual($0 as? LicenseTokenVerificationError, .unknownKey)
        }
        XCTAssertThrowsError(try makeVerifier(kid: payload.kid, key: otherKey).verify(token)) {
            XCTAssertEqual($0 as? LicenseTokenVerificationError, .invalidSignature)
        }
    }

    func testLicenseWithInstallBindingNeverGrantsPaidEntitlement() throws {
        let key = P256.Signing.PrivateKey()
        let payload = makeV2Payload(
            kid: "license-2026-01",
            typ: .license,
            bindingType: .install,
            bindingValue: "install-secret",
            issuedAt: Int64(now.timeIntervalSince1970),
            expiresAt: nil
        )
        let token = try signV2(payload, with: key)

        XCTAssertThrowsError(
            try makeVerifier(kid: payload.kid, key: key).verify(token)
        ) {
            XCTAssertEqual(
                $0 as? LicenseTokenVerificationError,
                .invalidClaims
            )
        }
    }

    func testLegacyV1LicenseRemainsVerifiableDuringMigration() throws {
        let key = P256.Signing.PrivateKey()
        let payload = SignedLicensePayload(
            version: 1,
            product: "cmdtab",
            email: "owner@example.com",
            licenseID: "ORDER-123",
            issuedAt: ISO8601DateFormatter().string(from: now),
            purchaserName: "Owner"
        )
        let payloadData = try JSONEncoder().encode(payload)
        let signature = try key.signature(for: payloadData)
        let token = [
            "CMDTAB1",
            encode(payloadData),
            encode(signature.derRepresentation),
        ].joined(separator: ".")
        let verifier = LicenseTokenVerifier(
            keyring: LicenseTokenKeyring(
                legacyV1PublicKeyDERBase64: key.publicKey.derRepresentation.base64EncodedString(),
                v2PublicKeysDERBase64: [:]
            )
        )

        XCTAssertEqual(try verifier.verify(token), .legacyLicense(payload))
    }

    private func makeVerifier(
        kid: String,
        key: P256.Signing.PrivateKey
    ) -> LicenseTokenVerifier {
        LicenseTokenVerifier(
            keyring: LicenseTokenKeyring(
                legacyV1PublicKeyDERBase64: key.publicKey.derRepresentation.base64EncodedString(),
                v2PublicKeysDERBase64: [
                    kid: key.publicKey.derRepresentation.base64EncodedString()
                ]
            )
        )
    }

    private func makeV2Payload(
        kid: String,
        typ: CmdTabEntitlementType,
        bindingType: CmdTabEntitlementBindingType,
        bindingValue: String,
        issuedAt: Int64,
        expiresAt: Int64?
    ) -> CmdTabTokenV2Payload {
        CmdTabTokenV2Payload(
            v: 2,
            kid: kid,
            typ: typ,
            aud: "cmdtab",
            sub: LicenseTokenVerifier.hashIdentifier("owner@example.com"),
            order: LicenseTokenVerifier.hashIdentifier("order-123"),
            binding: CmdTabTokenV2Binding(
                typ: bindingType,
                hash: LicenseTokenVerifier.hashIdentifier(bindingValue)
            ),
            iat: issuedAt,
            exp: expiresAt,
            updates: "1.x"
        )
    }

    private func signV2(
        _ payload: CmdTabTokenV2Payload,
        with key: P256.Signing.PrivateKey
    ) throws -> String {
        let payloadData = try JSONEncoder().encode(payload)
        let signature = try key.signature(for: payloadData)
        return [
            "CMDTAB2",
            encode(payloadData),
            encode(signature.derRepresentation),
        ].joined(separator: ".")
    }

    private func encode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
