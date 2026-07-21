import Foundation

enum LicensingConfiguration {
    static let productIdentifier = "cmdtab"
    static let tokenPrefix = "CMDTAB1"
    static let trialLengthDays = 14

    // Public key only. The matching private key is kept out of the repo.
    static let publicKeyDERBase64 =
        "MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEZ9FZZyw0trHoeLiL/uri6aLwr8Rhw9vNEGuI6afJqY9foeogoVNhQRZ4Hexv/fLhASKa4FKqaEflq3Uh6PIfDw=="

    static let buyURL = URL(string: "https://store.cmdtab.net/checkout?utm_source=cmdtab-app&utm_medium=licensing")!
    static let helpURL = URL(string: "https://cmdtab.net/help?utm_source=cmdtab-app&utm_medium=licensing")!
    static let trialURL = URL(string: "https://cmdtab.net/trial?utm_source=cmdtab-app&utm_medium=licensing")!
    static let siteBaseURL = URL(string: "https://cmdtab.net")!
    static let trialStartAPIURL = URL(string: "https://cmdtab.net/api/trial/start")!
    static let appTelemetryAPIURL = URL(string: "https://cmdtab.net/api/app-telemetry")!
    static let licenseStatusAPIURL = URL(string: "https://cmdtab.net/api/license/status")!
}
