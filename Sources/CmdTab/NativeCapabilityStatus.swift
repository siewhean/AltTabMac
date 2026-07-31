import Foundation

/// Small, thread-safe status holder for an optional native capability. The
/// status deliberately describes the most recent operation as well as symbol
/// availability so Diagnostics can distinguish an absent private symbol from a
/// runtime failure on a supported macOS build.
final class NativeCapabilityStatus {
    private let lock = NSLock()
    private var current: CapabilityStatus

    init(initial: CapabilityStatus) {
        current = initial
    }

    var status: CapabilityStatus {
        lock.lock()
        defer { lock.unlock() }
        return current
    }

    @discardableResult
    func record(_ status: CapabilityStatus) -> CapabilityStatus {
        lock.lock()
        current = status
        lock.unlock()
        return status
    }
}

enum NativeCapabilityStatusEvaluator {
    static func operationStatus(
        symbolAvailable: Bool,
        resultCode: Int32?,
        capability: String
    ) -> CapabilityStatus {
        guard symbolAvailable else {
            return .unavailable("\(capability) is unavailable on this macOS build.")
        }
        guard let resultCode else { return .available }
        guard resultCode == 0 else {
            return .failed("\(capability) failed with result \(resultCode).")
        }
        return .available
    }
}
