import CryptoKit
import Foundation

enum CmdTabEntitlementType: String, Codable, Equatable {
    case trial
    case license
}

enum CmdTabEntitlementBindingType: String, Codable, Equatable {
    case install
    case activation
}

struct CmdTabTokenV2Binding: Codable, Equatable {
    let typ: CmdTabEntitlementBindingType
    let hash: String
}

struct CmdTabTokenV2Payload: Codable, Equatable {
    let v: Int
    let kid: String
    let typ: CmdTabEntitlementType
    let aud: String
    let sub: String
    let order: String
    let binding: CmdTabTokenV2Binding
    let iat: Int64
    let exp: Int64?
    let updates: String
}

enum VerifiedCmdTabEntitlement: Equatable {
    case legacyLicense(SignedLicensePayload)
    case tokenV2(CmdTabTokenV2Payload)
}

struct LicenseTokenKeyring {
    let legacyV1PublicKeyDERBase64: String
    let v2PublicKeysDERBase64: [String: String]
}

struct LicenseTokenVerificationContext {
    let expectedType: CmdTabEntitlementType?
    let expectedBinding: (typ: CmdTabEntitlementBindingType, value: String)?
    let now: Date

    init(
        expectedType: CmdTabEntitlementType? = nil,
        expectedBinding: (typ: CmdTabEntitlementBindingType, value: String)? = nil,
        now: Date = Date()
    ) {
        self.expectedType = expectedType
        self.expectedBinding = expectedBinding
        self.now = now
    }
}

enum LicenseTokenVerificationError: Error, Equatable {
    case malformed
    case unsupportedVersion
    case invalidEncoding
    case unknownKey
    case invalidSignature
    case invalidClaims
    case bindingMismatch
    case expired
}

struct LicenseTokenVerifier {
    static let v2Prefix = "CMDTAB2"
    static let audience = "cmdtab"
    static let updateEntitlement = "1.x"

    private static let maximumTokenBytes = 16 * 1024
    private static let trialDurationSeconds: Int64 = 14 * 24 * 60 * 60
    private static let sha256Hex = try! NSRegularExpression(pattern: "^[a-f0-9]{64}$")
    private static let keyID = try! NSRegularExpression(
        pattern: "^[A-Za-z0-9][A-Za-z0-9._/-]{0,127}$"
    )

    let keyring: LicenseTokenKeyring

    func verify(
        _ untrustedToken: String,
        context: LicenseTokenVerificationContext = LicenseTokenVerificationContext()
    ) throws -> VerifiedCmdTabEntitlement {
        let token = untrustedToken
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
        guard token.utf8.count <= Self.maximumTokenBytes else {
            throw LicenseTokenVerificationError.malformed
        }

        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else {
            throw LicenseTokenVerificationError.malformed
        }
        switch String(parts[0]) {
        case LicensingConfiguration.tokenPrefix:
            guard context.expectedType != .trial else {
                throw LicenseTokenVerificationError.unsupportedVersion
            }
            return .legacyLicense(
                try verifyLegacy(
                    payloadPart: String(parts[1]),
                    signaturePart: String(parts[2])
                )
            )
        case Self.v2Prefix:
            return .tokenV2(
                try verifyV2(
                    payloadPart: String(parts[1]),
                    signaturePart: String(parts[2]),
                    context: context
                )
            )
        default:
            throw LicenseTokenVerificationError.unsupportedVersion
        }
    }

    private func verifyLegacy(
        payloadPart: String,
        signaturePart: String
    ) throws -> SignedLicensePayload {
        let (payloadData, signature) = try decodeSignedParts(
            payloadPart: payloadPart,
            signaturePart: signaturePart
        )
        try verifySignature(
            payloadData: payloadData,
            signature: signature,
            publicKeyDERBase64: keyring.legacyV1PublicKeyDERBase64
        )
        guard let payload = try? JSONDecoder().decode(SignedLicensePayload.self, from: payloadData),
              payload.version == 1,
              payload.product.lowercased() == LicensingConfiguration.productIdentifier,
              !payload.email.isEmpty,
              payload.email.count <= 320,
              !payload.licenseID.isEmpty,
              payload.licenseID.count <= 160,
              payload.issuedDate != nil else {
            throw LicenseTokenVerificationError.invalidClaims
        }
        return payload
    }

    private func verifyV2(
        payloadPart: String,
        signaturePart: String,
        context: LicenseTokenVerificationContext
    ) throws -> CmdTabTokenV2Payload {
        let (payloadData, signature) = try decodeSignedParts(
            payloadPart: payloadPart,
            signaturePart: signaturePart
        )
        guard let payload = try? JSONDecoder().decode(CmdTabTokenV2Payload.self, from: payloadData),
              payload.v == 2,
              matches(Self.keyID, value: payload.kid),
              payload.aud == Self.audience,
              matches(Self.sha256Hex, value: payload.sub),
              matches(Self.sha256Hex, value: payload.order),
              matches(Self.sha256Hex, value: payload.binding.hash),
              payload.iat >= 0,
              payload.updates == Self.updateEntitlement else {
            throw LicenseTokenVerificationError.invalidClaims
        }
        guard let publicKey = keyring.v2PublicKeysDERBase64[payload.kid] else {
            throw LicenseTokenVerificationError.unknownKey
        }
        try verifySignature(
            payloadData: payloadData,
            signature: signature,
            publicKeyDERBase64: publicKey
        )
        guard context.expectedType == nil || context.expectedType == payload.typ else {
            throw LicenseTokenVerificationError.invalidClaims
        }

        switch payload.typ {
        case .trial:
            guard payload.binding.typ == .install,
                  let expiresAt = payload.exp,
                  expiresAt == payload.iat + Self.trialDurationSeconds else {
                throw LicenseTokenVerificationError.invalidClaims
            }
            guard expiresAt > Int64(context.now.timeIntervalSince1970.rounded(.down)) else {
                throw LicenseTokenVerificationError.expired
            }
        case .license:
            guard payload.binding.typ == .activation,
                  payload.exp == nil else {
                throw LicenseTokenVerificationError.invalidClaims
            }
        }

        if let expectedBinding = context.expectedBinding {
            guard payload.binding.typ == expectedBinding.typ,
                  constantTimeEqual(
                    payload.binding.hash,
                    Self.hashIdentifier(expectedBinding.value)
                  ) else {
                throw LicenseTokenVerificationError.bindingMismatch
            }
        }
        return payload
    }

    private func decodeSignedParts(
        payloadPart: String,
        signaturePart: String
    ) throws -> (Data, P256.Signing.ECDSASignature) {
        guard let payloadData = strictBase64URLDecode(payloadPart),
              let signatureData = strictBase64URLDecode(signaturePart),
              let signature = try? P256.Signing.ECDSASignature(
                derRepresentation: signatureData
              ) else {
            throw LicenseTokenVerificationError.invalidEncoding
        }
        return (payloadData, signature)
    }

    private func verifySignature(
        payloadData: Data,
        signature: P256.Signing.ECDSASignature,
        publicKeyDERBase64: String
    ) throws {
        guard let publicKeyData = Data(base64Encoded: publicKeyDERBase64),
              let publicKey = try? P256.Signing.PublicKey(
                derRepresentation: publicKeyData
              ) else {
            throw LicenseTokenVerificationError.invalidEncoding
        }
        guard publicKey.isValidSignature(signature, for: payloadData) else {
            throw LicenseTokenVerificationError.invalidSignature
        }
    }

    private func strictBase64URLDecode(_ value: String) -> Data? {
        guard !value.isEmpty,
              value.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil else {
            return nil
        }
        let remainder = value.count % 4
        let padded = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
            + String(repeating: "=", count: remainder == 0 ? 0 : 4 - remainder)
        guard let decoded = Data(base64Encoded: padded) else { return nil }
        return base64URLEncode(decoded) == value ? decoded : nil
    }

    private func base64URLEncode(_ value: Data) -> String {
        value.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func matches(_ expression: NSRegularExpression, value: String) -> Bool {
        expression.firstMatch(
            in: value,
            range: NSRange(value.startIndex..., in: value)
        ) != nil
    }

    private func constantTimeEqual(_ lhs: String, _ rhs: String) -> Bool {
        let lhsBytes = Array(lhs.utf8)
        let rhsBytes = Array(rhs.utf8)
        guard lhsBytes.count == rhsBytes.count else { return false }
        return zip(lhsBytes, rhsBytes).reduce(UInt8(0)) { result, pair in
            result | (pair.0 ^ pair.1)
        } == 0
    }

    static func hashIdentifier(_ value: String) -> String {
        let normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let digest = SHA256.hash(data: Data(normalized.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
