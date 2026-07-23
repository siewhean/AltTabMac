import AppKit
import ApplicationServices
import CoreGraphics
import Darwin
import Foundation

private typealias GetWindowFunction = @convention(c) (
    AXUIElement,
    UnsafeMutablePointer<CGWindowID>
) -> Int32

private let getWindowID: GetWindowFunction? = {
    guard let symbol = dlsym(
        UnsafeMutableRawPointer(bitPattern: -2),
        "_AXUIElementGetWindow"
    ) else {
        return nil
    }
    return unsafeBitCast(symbol, to: GetWindowFunction.self)
}()

private func exactWindowID(_ element: AXUIElement?) -> CGWindowID? {
    guard let element, let getWindowID else { return nil }
    var windowID: CGWindowID = 0
    guard getWindowID(element, &windowID) == 0, windowID != 0 else {
        return nil
    }
    return windowID
}

private func windowAttribute(
    _ attribute: CFString,
    application: AXUIElement
) -> AXUIElement? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(application, attribute, &value) == .success,
          let value else {
        return nil
    }
    return unsafeBitCast(value, to: AXUIElement.self)
}

private func jsonFrame(_ value: Any?) -> [String: Double]? {
    guard let dictionary = value as? NSDictionary,
          let frame = CGRect(dictionaryRepresentation: dictionary) else {
        return nil
    }
    return [
        "x": frame.minX,
        "y": frame.minY,
        "width": frame.width,
        "height": frame.height,
    ]
}

private func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(2)
}

let bundleIdentifier = CommandLine.arguments.dropFirst().first
    ?? "net.cmdtab.fixture.WindowLab"
let applications = NSRunningApplication.runningApplications(
    withBundleIdentifier: bundleIdentifier
)

if applications.isEmpty {
    fail("No running application found for bundle identifier \(bundleIdentifier)")
}

let allWindows = CGWindowListCopyWindowInfo(
    [.optionAll, .excludeDesktopElements],
    kCGNullWindowID
) as? [[String: Any]] ?? []
let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier

var applicationRows: [[String: Any]] = []
for application in applications.sorted(by: {
    $0.processIdentifier < $1.processIdentifier
}) {
    let pid = application.processIdentifier
    let axApplication = AXUIElementCreateApplication(pid)
    let focusedID = exactWindowID(
        windowAttribute(kAXFocusedWindowAttribute as CFString, application: axApplication)
    )
    let mainID = exactWindowID(
        windowAttribute(kAXMainWindowAttribute as CFString, application: axApplication)
    )

    let windows: [[String: Any]] = allWindows
        .filter {
            ($0[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid
        }
        .compactMap { row in
            guard let windowID = (row[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
                  windowID != 0 else {
                return nil
            }
            var output: [String: Any] = [
                "windowID": windowID,
                "title": (row[kCGWindowName as String] as? String) ?? "",
                "layer": (row[kCGWindowLayer as String] as? NSNumber)?.intValue ?? -1,
                "isOnScreen": (row[kCGWindowIsOnscreen as String] as? NSNumber)?.boolValue ?? false,
                "alpha": (row[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 0,
                "isFocused": focusedID == windowID,
                "isMain": mainID == windowID,
            ]
            if let frame = jsonFrame(row[kCGWindowBounds as String]) {
                output["frame"] = frame
            }
            return output
        }
        .sorted {
            ($0["windowID"] as? UInt32 ?? 0) < ($1["windowID"] as? UInt32 ?? 0)
        }

    var output: [String: Any] = [
        "pid": pid,
        "bundleIdentifier": application.bundleIdentifier ?? bundleIdentifier,
        "localizedName": application.localizedName ?? "",
        "isFrontmostProcess": frontmostPID == pid,
        "accessibilityTrusted": AXIsProcessTrusted(),
        "exactWindowSymbolAvailable": getWindowID != nil,
        "windows": windows,
    ]
    if let focusedID { output["focusedWindowID"] = focusedID }
    if let mainID { output["mainWindowID"] = mainID }
    applicationRows.append(output)
}

let document: [String: Any] = [
    "bundleIdentifier": bundleIdentifier,
    "capturedAt": ISO8601DateFormatter().string(from: Date()),
    "applications": applicationRows,
]
let data = try JSONSerialization.data(
    withJSONObject: document,
    options: [.prettyPrinted, .sortedKeys]
)
FileHandle.standardOutput.write(data)
FileHandle.standardOutput.write(Data("\n".utf8))
