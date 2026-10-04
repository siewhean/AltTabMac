// A local private-key based generator is a development-only tool. Do not
// compile its key-path handling or token generation into public builds.
#if DEBUG
import AppKit
import CryptoKit
import Foundation

struct DeveloperGeneratedLicense {
    let token: String
    let payload: SignedLicensePayload
}

enum DeveloperLicenseGeneratorError: LocalizedError {
    case missingPrivateKey(String)
    case unreadablePrivateKey

    var errorDescription: String? {
        switch self {
        case let .missingPrivateKey(path):
            return "Missing local signing key at \(path)."
        case .unreadablePrivateKey:
            return "The local signing key could not be read."
        }
    }
}

enum DeveloperLicenseGenerator {
    static func generate(email: String, purchaserName: String?) throws -> DeveloperGeneratedLicense {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedName = purchaserName?.trimmingCharacters(in: .whitespacesAndNewlines)

        let privateKeyPath = ProcessInfo.processInfo.environment["CMDTAB_LICENSE_PRIVATE_KEY_PATH"]
            .flatMap { $0.isEmpty ? nil : $0 }
            ?? NSString(string: "~/Documents/GitHub/CmdTab/.secrets/cmdtab-license-private-key.pem").expandingTildeInPath

        guard FileManager.default.fileExists(atPath: privateKeyPath) else {
            throw DeveloperLicenseGeneratorError.missingPrivateKey(privateKeyPath)
        }

        guard let privateKeyPEM = try? String(contentsOfFile: privateKeyPath, encoding: .utf8) else {
            throw DeveloperLicenseGeneratorError.unreadablePrivateKey
        }

        let privateKey = try P256.Signing.PrivateKey(pemRepresentation: privateKeyPEM)
        let payload = SignedLicensePayload(
            version: 1,
            product: LicensingConfiguration.productIdentifier,
            email: normalizedEmail,
            licenseID: UUID().uuidString.uppercased(),
            issuedAt: ISO8601DateFormatter().string(from: Date()),
            purchaserName: normalizedName?.isEmpty == false ? normalizedName : nil
        )

        let payloadData = try JSONEncoder().encode(payload)
        let signature = try privateKey.signature(for: payloadData)

        let token = [
            LicensingConfiguration.tokenPrefix,
            payloadData.base64URLEncodedString(),
            signature.derRepresentation.base64URLEncodedString(),
        ].joined(separator: ".")

        return DeveloperGeneratedLicense(token: token, payload: payload)
    }

    static func copyToPasteboard(_ token: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(token, forType: .string)
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
#endif
