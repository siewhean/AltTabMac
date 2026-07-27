import CryptoKit
import Foundation
import XCTest
@testable import CmdTab

final class TrialEntitlementAuthenticatorTests: XCTestCase {
    func testSignedTrialAuthenticatesExactClaimAndInstallBinding() throws {
        let key = P256.Signing.PrivateKey()
        let startedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let endsAt = startedAt.addingTimeInterval(14 * 24 * 60 * 60)
        let claimID = "claim-123"
        let email = "owner@example.com"
        let installID = String(repeating: "a", count: 64)
        let token = try signedToken(
            key: key,
            claimID: claimID,
            email: email,
            installID: installID,
            startedAt: startedAt
        )
        let authenticator = SignedTrialClaimAuthenticator(
            v2PublicKeysDERBase64: [
                "trial-test-1":
                    key.publicKey.derRepresentation.base64EncodedString(),
            ]
        )
        let claim = TrialClaimRecord(
            id: claimID,
            email: email,
            installID: installID,
            startedAt: ISO8601DateFormatter().string(from: startedAt),
            endsAt: ISO8601DateFormatter().string(from: endsAt),
            appVersion: "1.0.0",
            osVersion: "14.0",
            entitlementToken: token
        )

        XCTAssertTrue(authenticator.validates(claim, installID: installID))
        XCTAssertFalse(
            authenticator.validates(
                TrialClaimRecord(
                    id: claim.id,
                    email: "attacker@example.com",
                    installID: claim.installID,
                    startedAt: claim.startedAt,
                    endsAt: claim.endsAt,
                    appVersion: claim.appVersion,
                    osVersion: claim.osVersion,
                    entitlementToken: claim.entitlementToken
                ),
                installID: installID
            )
        )
        XCTAssertFalse(
            authenticator.validates(
                claim,
                installID: String(repeating: "b", count: 64)
            )
        )
    }

    func testAuthoritativeValidationTimeRejectsExpiredRollbackClaim() throws {
        let privateKey = P256.Signing.PrivateKey()
        let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let endsAt = startedAt.addingTimeInterval(14 * 24 * 60 * 60)
        let installID = "install-expired"
        let claimID = "claim-expired"
        let token = try signedToken(
            key: privateKey,
            claimID: claimID,
            email: "expired@example.com",
            installID: installID,
            startedAt: startedAt
        )
        let claim = TrialClaimRecord(
            id: claimID,
            email: "expired@example.com",
            installID: installID,
            startedAt: ISO8601DateFormatter().string(from: startedAt),
            endsAt: ISO8601DateFormatter().string(from: endsAt),
            appVersion: "1.0",
            osVersion: "14.0",
            entitlementToken: token,
            validatedAt: ISO8601DateFormatter().string(
                from: endsAt.addingTimeInterval(60)
            )
        )
        let authenticator = SignedTrialClaimAuthenticator(
            legacyPublicKeyDERBase64: "",
            v2PublicKeysDERBase64: [
                "trial-test-1":
                    privateKey.publicKey.derRepresentation.base64EncodedString(),
            ]
        )

        XCTAssertFalse(authenticator.validates(claim, installID: installID))
    }

    private func signedToken(
        key: P256.Signing.PrivateKey,
        claimID: String,
        email: String,
        installID: String,
        startedAt: Date
    ) throws -> String {
        let issuedAt = Int64(startedAt.timeIntervalSince1970)
        let payload = CmdTabTokenV2Payload(
            v: 2,
            kid: "trial-test-1",
            typ: .trial,
            aud: "cmdtab",
            sub: LicenseTokenVerifier.hashIdentifier(email),
            order: LicenseTokenVerifier.hashIdentifier(claimID),
            binding: CmdTabTokenV2Binding(
                typ: .install,
                hash: LicenseTokenVerifier.hashIdentifier(installID)
            ),
            iat: issuedAt,
            exp: issuedAt + 14 * 24 * 60 * 60,
            updates: "1.x"
        )
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
