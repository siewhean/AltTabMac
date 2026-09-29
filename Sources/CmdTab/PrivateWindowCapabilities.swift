import AppKit
import ApplicationServices
import CoreGraphics
import Darwin

/// Result of one optional private-framework operation.  Callers must make an
/// explicit choice for an unavailable or failed capability; neither outcome is
/// silently equivalent to a verified identity or focus operation.
enum PrivateCapabilityResult<Value> {
    case success(Value)
    case unavailable
    case failed
}

/// Narrow boundary for the optional private APIs used to improve window
/// identity, previews, and focus.  Core Graphics membership and public AX
/// actions remain usable when this provider is unavailable.
protocol PrivateWindowCapabilityProviding: AnyObject {
    var identityStatus: CapabilityStatus { get }
    var captureStatus: CapabilityStatus { get }
    var focusStatus: CapabilityStatus { get }

    func windowID(for element: AXUIElement) -> PrivateCapabilityResult<CGWindowID>
    func captureWindow(_ windowID: CGWindowID) -> PrivateCapabilityResult<NSImage>
    func focusWindow(ownerPID: pid_t, windowID: CGWindowID) -> PrivateCapabilityResult<Void>
}

struct PrivateWindowCapabilitySnapshot: Equatable {
    let identity: CapabilityStatus
    let capture: CapabilityStatus
    let focus: CapabilityStatus
}

enum PrivateWindowCapabilityPolicy {
    /// Exact-window success is permitted only when both the identity bridge and
    /// the exact-focus bridge are live.  All other states intentionally take
    /// the app-level fallback path and therefore cannot update exact MRU.
    static func permitsExactFocus(
        identity: CapabilityStatus,
        focus: CapabilityStatus
    ) -> Bool {
        identity.level == .available && focus.level == .available
    }
}

/// Process-wide diagnostics only contain capability state and never a window
/// title, document URL, process name, or captured image.
final class PrivateWindowCapabilityDiagnostics {
    static let shared = PrivateWindowCapabilityDiagnostics()
    private let lock = NSLock()
    private var current = PrivateWindowCapabilitySnapshot(
        identity: .unavailable("Private capability provider has not been initialized."),
        capture: .unavailable("Private capability provider has not been initialized."),
        focus: .unavailable("Private capability provider has not been initialized.")
    )

    func update(from provider: PrivateWindowCapabilityProviding) {
        lock.lock()
        current = PrivateWindowCapabilitySnapshot(
            identity: provider.identityStatus,
            capture: provider.captureStatus,
            focus: provider.focusStatus
        )
        lock.unlock()
    }

    func snapshot() -> PrivateWindowCapabilitySnapshot {
        lock.lock()
        defer { lock.unlock() }
        return current
    }
}

/// The live implementation centralizes all dynamic symbol resolution.  No
/// switcher decision reaches directly into SkyLight or `_AXUIElementGetWindow`.
final class SystemPrivateWindowCapabilityProvider: PrivateWindowCapabilityProviding {
    static let shared = SystemPrivateWindowCapabilityProvider()

    private struct CaptureOptions: OptionSet {
        let rawValue: UInt32
        static let ignoreGlobalClipShape = CaptureOptions(rawValue: 1 << 11)
        static let bestResolution = CaptureOptions(rawValue: 1 << 8)
        static let fullSize = CaptureOptions(rawValue: 1 << 19)
    }

    private typealias AXWindowIDFn = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> Int32
    private typealias MainConnectionFn = @convention(c) () -> UInt32
    private typealias CaptureFn = @convention(c) (UInt32, UnsafeMutablePointer<CGWindowID>, UInt32, UInt32) -> Unmanaged<CFArray>?
    private typealias ProcessForPIDFn = @convention(c) (pid_t, UnsafeMutablePointer<ProcessSerialNumber>) -> OSStatus
    private typealias SetFrontProcessFn = @convention(c) (UnsafeMutablePointer<ProcessSerialNumber>, CGWindowID, UInt32) -> CGError
    private typealias PostEventFn = @convention(c) (UnsafeMutablePointer<ProcessSerialNumber>, UnsafeMutablePointer<UInt8>) -> CGError

    private let axWindowID: AXWindowIDFn?
    private let mainConnection: MainConnectionFn?
    private let capture: CaptureFn?
    private let processForPID: ProcessForPIDFn?
    private let setFrontProcess: SetFrontProcessFn?
    private let postEvent: PostEventFn?

    init() {
        let globalHandle = UnsafeMutableRawPointer(bitPattern: -2)
        axWindowID = dlsym(globalHandle, "_AXUIElementGetWindow").map {
            unsafeBitCast($0, to: AXWindowIDFn.self)
        }

        guard let skyLight = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", 0x1) else {
            mainConnection = nil; capture = nil; processForPID = nil; setFrontProcess = nil; postEvent = nil
            return
        }
        mainConnection = (dlsym(skyLight, "CGSMainConnectionID") ?? dlsym(skyLight, "SLSMainConnectionID")).map {
            unsafeBitCast($0, to: MainConnectionFn.self)
        }
        capture = (dlsym(skyLight, "CGSHWCaptureWindowList") ?? dlsym(skyLight, "SLSHWCaptureWindowList")).map {
            unsafeBitCast($0, to: CaptureFn.self)
        }
        processForPID = dlsym(globalHandle, "GetProcessForPID").map {
            unsafeBitCast($0, to: ProcessForPIDFn.self)
        }
        setFrontProcess = dlsym(skyLight, "_SLPSSetFrontProcessWithOptions").map {
            unsafeBitCast($0, to: SetFrontProcessFn.self)
        }
        postEvent = dlsym(skyLight, "SLPSPostEventRecordTo").map {
            unsafeBitCast($0, to: PostEventFn.self)
        }
    }

    var identityStatus: CapabilityStatus {
        axWindowID == nil ? .unavailable("Exact AX-window identity is unavailable.") : .available
    }
    var captureStatus: CapabilityStatus {
        mainConnection == nil || capture == nil
            ? .unavailable("Private preview capture is unavailable; public capture fallback is used.")
            : .available
    }
    var focusStatus: CapabilityStatus {
        processForPID == nil || setFrontProcess == nil || postEvent == nil
            ? .unavailable("Exact private window focus is unavailable; app-level activation is used.")
            : .available
    }

    func windowID(for element: AXUIElement) -> PrivateCapabilityResult<CGWindowID> {
        guard let axWindowID else { return .unavailable }
        var windowID: CGWindowID = 0
        guard axWindowID(element, &windowID) == 0, windowID != 0 else { return .failed }
        return .success(windowID)
    }

    func captureWindow(_ windowID: CGWindowID) -> PrivateCapabilityResult<NSImage> {
        guard let mainConnection, let capture else { return .unavailable }
        var target = windowID
        let options: CaptureOptions = [.ignoreGlobalClipShape, .bestResolution, .fullSize]
        guard let array = capture(mainConnection(), &target, 1, options.rawValue) else { return .failed }
        let retained = array.takeRetainedValue()
        guard CFArrayGetCount(retained) > 0, let raw = CFArrayGetValueAtIndex(retained, 0) else { return .failed }
        let image = Unmanaged<CGImage>.fromOpaque(raw).takeUnretainedValue()
        guard image.width >= 40, image.height >= 30 else { return .failed }
        return .success(NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height)))
    }

    func focusWindow(ownerPID: pid_t, windowID: CGWindowID) -> PrivateCapabilityResult<Void> {
        guard windowID != 0 else { return .failed }
        guard let processForPID, let setFrontProcess, let postEvent else { return .unavailable }
        var psn = ProcessSerialNumber()
        guard processForPID(ownerPID, &psn) == 0 else { return .failed }
        guard setFrontProcess(&psn, windowID, 0x200) == .success else { return .failed }
        var bytes = [UInt8](repeating: 0, count: 0xf8)
        bytes[0x04] = 0xf8; bytes[0x3a] = 0x10
        var mutableWindowID = windowID
        memcpy(&bytes[0x3c], &mutableWindowID, MemoryLayout<UInt32>.size)
        memset(&bytes[0x20], 0xff, 0x10)
        bytes[0x08] = 0x01
        guard postEvent(&psn, &bytes) == .success else { return .failed }
        bytes[0x08] = 0x02
        guard postEvent(&psn, &bytes) == .success else { return .failed }
        return .success(())
    }
}
