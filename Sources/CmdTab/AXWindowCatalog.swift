import AppKit
import ApplicationServices
import CoreGraphics
import Darwin
import Foundation

struct AXWindowMetadata {
    let ownerPID: pid_t
    let windowID: CGWindowID
    let title: String
    let role: String?
    let subrole: String?
    let parentRole: String?
    let documentURL: URL?
    let frame: CGRect?
    let isMinimized: Bool
    let isFullscreen: Bool
    let workspace: WindowWorkspaceSnapshot

    var isStandardSwitcherWindow: Bool {
        AXWindowCatalog.isEligible(
            role: role,
            subrole: subrole,
            parentRole: parentRole,
            isMinimized: isMinimized,
            includeMinimized: true,
            allowFloating: false
        )
    }
}

struct AXWindowCatalogSnapshot {
    let byPID: [pid_t: [CGWindowID: AXWindowMetadata]]
    let capability: CapabilityStatus

    func metadata(ownerPID: pid_t, windowID: CGWindowID) -> AXWindowMetadata? {
        byPID[ownerPID]?[windowID]
    }

    var allWindows: [AXWindowMetadata] {
        byPID.values.flatMap { $0.values }
    }
}

enum AXWindowIdentityLookup {
    private typealias GetWindowFn = @convention(c) (
        AXUIElement,
        UnsafeMutablePointer<CGWindowID>
    ) -> Int32

    private static let resolved: GetWindowFn? = {
        guard let symbol = dlsym(
            UnsafeMutableRawPointer(bitPattern: -2),
            "_AXUIElementGetWindow"
        ) else {
            return nil
        }
        return unsafeBitCast(symbol, to: GetWindowFn.self)
    }()

    static var status: CapabilityStatus {
        resolved == nil
            ? .unavailable("_AXUIElementGetWindow is unavailable; exact AX-window identity cannot be resolved.")
            : .available
    }

    static func windowID(for element: AXUIElement) -> CGWindowID? {
        guard let resolved else { return nil }
        var windowID: CGWindowID = 0
        guard resolved(element, &windowID) == 0, windowID != 0 else {
            return nil
        }
        return windowID
    }

    static func windowElement(ownerPID: pid_t, windowID: CGWindowID) -> AXUIElement? {
        let application = AXUIElementCreateApplication(ownerPID)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            application,
            kAXWindowsAttribute as CFString,
            &value
        ) == .success,
        let windows = value as? [AXUIElement] else {
            return nil
        }
        return windows.first { windowID(for: $0) == windowID }
    }
}

final class AXWindowCatalog {
    static let shared = AXWindowCatalog()

    private let workspaceProvider: WindowWorkspaceProviding
    private let fullscreenAttribute = "AXFullScreen" as CFString

    init(workspaceProvider: WindowWorkspaceProviding = WindowWorkspaceProvider.shared) {
        self.workspaceProvider = workspaceProvider
    }

    func snapshot(for applications: [NSRunningApplication]) -> AXWindowCatalogSnapshot {
        guard AXIsProcessTrusted() else {
            return AXWindowCatalogSnapshot(
                byPID: [:],
                capability: .unavailable("Accessibility permission is required for exact window metadata.")
            )
        }

        workspaceProvider.refresh()
        var byPID: [pid_t: [CGWindowID: AXWindowMetadata]] = [:]
        byPID.reserveCapacity(applications.count)

        for application in applications {
            let pid = application.processIdentifier
            let axApplication = AXUIElementCreateApplication(pid)
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(
                axApplication,
                kAXWindowsAttribute as CFString,
                &value
            ) == .success,
            let windows = value as? [AXUIElement] else {
                continue
            }

            var metadataByID: [CGWindowID: AXWindowMetadata] = [:]
            metadataByID.reserveCapacity(windows.count)

            for window in windows {
                guard let windowID = AXWindowIdentityLookup.windowID(for: window) else {
                    continue
                }
                let role = stringValue(of: kAXRoleAttribute as CFString, on: window)
                let subrole = stringValue(of: kAXSubroleAttribute as CFString, on: window)
                let parentRole = parentRole(of: window)
                let minimized = boolValue(of: kAXMinimizedAttribute as CFString, on: window) ?? false
                let fullscreen = boolValue(of: fullscreenAttribute, on: window) ?? false
                let frame = frame(of: window)
                let title = stringValue(of: kAXTitleAttribute as CFString, on: window)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let documentURL = urlValue(of: kAXDocumentAttribute as CFString, on: window)
                let isOnScreen = isWindowOnScreen(windowID)
                let workspace = workspaceProvider.snapshot(
                    for: windowID,
                    isOnScreen: isOnScreen
                )

                metadataByID[windowID] = AXWindowMetadata(
                    ownerPID: pid,
                    windowID: windowID,
                    title: title,
                    role: role,
                    subrole: subrole,
                    parentRole: parentRole,
                    documentURL: documentURL,
                    frame: frame,
                    isMinimized: minimized,
                    isFullscreen: fullscreen,
                    workspace: workspace
                )
            }

            if !metadataByID.isEmpty {
                byPID[pid] = metadataByID
            }
        }

        let exactIdentityStatus = AXWindowIdentityLookup.status
        let workspaceStatus = workspaceProvider.status
        let capability: CapabilityStatus
        if exactIdentityStatus.level != .available {
            capability = exactIdentityStatus
        } else if workspaceStatus.level == .failed || workspaceStatus.level == .unavailable {
            capability = .degraded(
                "Exact window identity is available, but workspace metadata is degraded: \(workspaceStatus.reason ?? "unknown reason")"
            )
        } else {
            capability = workspaceStatus
        }

        return AXWindowCatalogSnapshot(byPID: byPID, capability: capability)
    }

    static func isEligible(
        role: String?,
        subrole: String?,
        parentRole: String?,
        isMinimized: Bool,
        includeMinimized: Bool,
        allowFloating: Bool = false
    ) -> Bool {
        guard role == (kAXWindowRole as String) else { return false }
        guard includeMinimized || !isMinimized else { return false }
        guard parentRole != (kAXWindowRole as String) else { return false }
        guard let subrole else { return false }

        if subrole == (kAXStandardWindowSubrole as String) || subrole == "AXFullScreenWindow" {
            return true
        }
        if allowFloating, subrole == (kAXFloatingWindowSubrole as String) {
            return true
        }
        return false
    }

    private func isWindowOnScreen(_ windowID: CGWindowID) -> Bool {
        let info = CGWindowListCopyWindowInfo(
            [.optionIncludingWindow, .excludeDesktopElements],
            windowID
        ) as? [[String: Any]]
        guard let row = info?.first,
              let value = row[kCGWindowIsOnscreen as String] as? NSNumber else {
            return false
        }
        return value.boolValue
    }

    private func stringValue(of attribute: CFString, on element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else {
            return nil
        }
        return value as? String
    }

    private func boolValue(of attribute: CFString, on element: AXUIElement) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
              let number = value as? NSNumber else {
            return nil
        }
        return number.boolValue
    }

    private func urlValue(of attribute: CFString, on element: AXUIElement) -> URL? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
              let value else {
            return nil
        }
        if let url = value as? URL {
            return url
        }
        if let string = value as? String {
            return URL(string: string)
        }
        return nil
    }

    private func parentRole(of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXParentAttribute as CFString,
            &value
        ) == .success,
        let value else {
            return nil
        }
        let parent = unsafeBitCast(value, to: AXUIElement.self)
        return stringValue(of: kAXRoleAttribute as CFString, on: parent)
    }

    private func frame(of element: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXPositionAttribute as CFString,
            &positionValue
        ) == .success,
        AXUIElementCopyAttributeValue(
            element,
            kAXSizeAttribute as CFString,
            &sizeValue
        ) == .success,
        let positionValue,
        let sizeValue,
        CFGetTypeID(positionValue) == AXValueGetTypeID(),
        CFGetTypeID(sizeValue) == AXValueGetTypeID() else {
            return nil
        }

        var position = CGPoint.zero
        var size = CGSize.zero
        let positionAXValue = unsafeBitCast(positionValue, to: AXValue.self)
        let sizeAXValue = unsafeBitCast(sizeValue, to: AXValue.self)
        guard AXValueGetValue(positionAXValue, .cgPoint, &position),
              AXValueGetValue(sizeAXValue, .cgSize, &size) else {
            return nil
        }
        return CGRect(origin: position, size: size)
    }
}
