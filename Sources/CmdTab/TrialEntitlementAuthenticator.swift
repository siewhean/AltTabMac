import Foundation

protocol TrialClaimAuthenticating {
    func validates(_ claim: TrialClaimRecord, installID: String) -> Bool
}

struct SignedTrialClaimAuthenticator: TrialClaimAuthenticating {
    let verifier: LicenseTokenVerifier

    init(
        legacyPublicKeyDERBase64: String = LicensingConfiguration.publicKeyDERBase64,
        v2PublicKeysDERBase64: [String: String] =
            LicensingConfiguration.trialPublicKeyringDERBase64
    ) {
        verifier = LicenseTokenVerifier(
            keyring: LicenseTokenKeyring(
                legacyV1PublicKeyDERBase64: legacyPublicKeyDERBase64,
                v2PublicKeysDERBase64: v2PublicKeysDERBase64
            )
        )
    }

    func validates(_ claim: TrialClaimRecord, installID: String) -> Bool {
        guard let token = claim.entitlementToken,
              !token.isEmpty,
              claim.installID == installID,
              let startedAt = claim.startedDate,
              let endsAt = claim.endsDate,
              let validationDate = claim.validatedDate ?? claim.startedDate,
              case let .tokenV2(payload) = try? verifier.verify(
                token,
                context: LicenseTokenVerificationContext(
                    expectedType: .trial,
                    expectedBinding: (.install, installID),
                    now: validationDate
                )
              ),
              payload.sub == LicenseTokenVerifier.hashIdentifier(claim.email),
              payload.order == LicenseTokenVerifier.hashIdentifier(claim.id),
              payload.iat == Int64(startedAt.timeIntervalSince1970.rounded(.down)),
              payload.exp == Int64(endsAt.timeIntervalSince1970.rounded(.down)) else {
            return false
        }
        return true
    }
}
