#!/usr/bin/env swift

import CryptoKit
import Foundation

struct LicensePayload: Codable {
    let version: Int
    let product: String
    let email: String
    let licenseID: String
    let issuedAt: String
    let purchaserName: String?
}

enum ScriptError: LocalizedError {
    case usage
    case missingEmail
    case missingPrivateKey(String)

    var errorDescription: String? {
        switch self {
        case .usage:
            return """
            Usage:
              swift scripts/generate_license_key.swift --email user@example.com [--name "User Name"] [--license-id LIC-123]

            Optional environment variables:
              CMDTAB_LICENSE_PRIVATE_KEY_PATH   defaults to .secrets/cmdtab-license-private-key.pem
            """
        case .missingEmail:
            return "An email address is required."
        case let .missingPrivateKey(path):
            return """
            Missing private key at \(path)

            Generate one with:
              mkdir -p .secrets
              openssl ecparam -name prime256v1 -genkey -noout -out .secrets/cmdtab-license-private-key.pem
              chmod 600 .secrets/cmdtab-license-private-key.pem
            """
        }
    }
}

let arguments = Array(CommandLine.arguments.dropFirst())
if arguments.contains("--help") || arguments.contains("-h") {
    throw ScriptError.usage
}

var email: String?
var purchaserName: String?
var licenseID: String?

var iterator = arguments.makeIterator()
while let argument = iterator.next() {
    switch argument {
    case "--email":
        email = iterator.next()
    case "--name":
        purchaserName = iterator.next()
    case "--license-id":
        licenseID = iterator.next()
    default:
        break
    }
}

guard let rawEmail = email?.trimmingCharacters(in: .whitespacesAndNewlines), !rawEmail.isEmpty else {
    throw ScriptError.missingEmail
}

let scriptDirectory = URL(fileURLWithPath: CommandLine.arguments[0])
    .deletingLastPathComponent()
    .standardizedFileURL
let repositoryRoot = scriptDirectory.deletingLastPathComponent()
let privateKeyPath = ProcessInfo.processInfo.environment["CMDTAB_LICENSE_PRIVATE_KEY_PATH"]
    .flatMap { $0.isEmpty ? nil : $0 }
    ?? repositoryRoot.appendingPathComponent(".secrets/cmdtab-license-private-key.pem").path

guard FileManager.default.fileExists(atPath: privateKeyPath) else {
    throw ScriptError.missingPrivateKey(privateKeyPath)
}

let privateKeyPEM = try String(contentsOfFile: privateKeyPath, encoding: .utf8)
let privateKey = try P256.Signing.PrivateKey(pemRepresentation: privateKeyPEM)

let payload = LicensePayload(
    version: 1,
    product: "cmdtab",
    email: rawEmail.lowercased(),
    licenseID: licenseID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        ? licenseID!.trimmingCharacters(in: .whitespacesAndNewlines)
        : UUID().uuidString.uppercased(),
    issuedAt: ISO8601DateFormatter().string(from: Date()),
    purchaserName: purchaserName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        ? purchaserName!.trimmingCharacters(in: .whitespacesAndNewlines)
        : nil
)

let payloadData = try JSONEncoder().encode(payload)
let signature = try privateKey.signature(for: payloadData)

let token = [
    "CMDTAB1",
    payloadData.base64URLEncodedString(),
    signature.derRepresentation.base64URLEncodedString(),
].joined(separator: ".")

print(token)

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
