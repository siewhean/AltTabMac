import CryptoKit
import Foundation
import IOKit

/// One trial per Mac: the trial server keys claims on a salted hash of the
/// hardware UUID, which survives Keychain resets. The raw UUID never leaves
/// this Mac, and the product-specific salt keeps the hash useless elsewhere.
enum HardwareIdentity {
    static func trialHardwareIdentifier() -> String? {
        guard let uuid = platformUUID() else { return nil }
        return hashedIdentifier(platformUUID: uuid)
    }

    static func hashedIdentifier(platformUUID: String) -> String? {
        let normalized = platformUUID
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        guard !normalized.isEmpty else { return nil }
        return SHA256.hash(data: Data("cmdtab-trial-hardware:v1:\(normalized)".utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static func platformUUID() -> String? {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOPlatformExpertDevice")
        )
        guard service != IO_OBJECT_NULL else { return nil }
        defer { IOObjectRelease(service) }
        return IORegistryEntryCreateCFProperty(
            service,
            kIOPlatformUUIDKey as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? String
    }
}
