import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

enum WindowManagementAction: String, CaseIterable, Codable, Hashable {
    case restoreWindow
    case zoomWindow
    case toggleFullscreen
    case moveToNextDisplay
    case centerWindow
    case tileLeft
    case tileRight
    case tileFirstThird
    case tileCenterThird
    case tileLastThird
    case forceQuitApplication

    var title: String {
        switch self {
        case .restoreWindow: return "Restore Window"
        case .zoomWindow: return "Zoom / Maximize"
        case .toggleFullscreen: return "Toggle Fullscreen"
        case .moveToNextDisplay: return "Move to Next Display"
        case .centerWindow: return "Center Window"
        case .tileLeft: return "Tile Left"
        case .tileRight: return "Tile Right"
        case .tileFirstThird: return "Tile First Third"
        case .tileCenterThird: return "Tile Centre Third"
        case .tileLastThird: return "Tile Last Third"
        case .forceQuitApplication: return "Force Quit Application"
        }
    }

    var systemImage: String {
        switch self {
        case .restoreWindow: return "arrow.up.left.and.arrow.down.right"
        case .zoomWindow: return "arrow.up.left.and.arrow.down.right.circle"
        case .toggleFullscreen: return "arrow.up.left.and.arrow.down.right.square"
        case .moveToNextDisplay: return "display.2"
        case .centerWindow: return "rectangle.center.inset.filled"
        case .tileLeft: return "rectangle.lefthalf.inset.filled"
        case .tileRight: return "rectangle.righthalf.inset.filled"
        case .tileFirstThird: return "rectangle.split.3x1.fill"
        case .tileCenterThird: return "rectangle.split.3x1"
        case .tileLastThird: return "rectangle.split.3x1.fill"
        case .forceQuitApplication: return "exclamationmark.octagon.fill"
        }
    }

    var requiresConfirmation: Bool {
        self == .forceQuitApplication
    }

    var removesSelectedItem: Bool {
        self == .forceQuitApplication
    }
}

struct WindowActionAvailability: Codable, Equatable {
    let isSupported: Bool
    let reason: String?

    static let supported = WindowActionAvailability(isSupported: true, reason: nil)

    static func unsupported(_ reason: String) -> WindowActionAvailability {
        WindowActionAvailability(isSupported: false, reason: reason)
    }
}

struct WindowActionResult: Equatable {
    let succeeded: Bool
    let message: String

    static func success(_ message: String) -> WindowActionResult {
        WindowActionResult(succeeded: true, message: message)
    }

    static func failure(_ message: String) -> WindowActionResult {
        WindowActionResult(succeeded: false, message: message)
    }
}

struct WindowGeometryTarget: Equatable {
    let frame: CGRect
    let displayID: CGDirectDisplayID
}

enum WindowGeometryPlanner {
    enum Tile: Equatable {
        case leftHalf
        case rightHalf
        case firstThird
        case centerThird
        case lastThird
    }

    static func centeredFrame(windowSize: CGSize, visibleFrame: CGRect) -> CGRect {
        let width = min(max(windowSize.width, 240), visibleFrame.width)
        let height = min(max(windowSize.height, 160), visibleFrame.height)
        return CGRect(
            x: visibleFrame.midX - width / 2,
            y: visibleFrame.midY - height / 2,
            width: width,
            height: height
        ).integral
    }

    static func tiledFrame(_ tile: Tile, visibleFrame: CGRect) -> CGRect {
        switch tile {
        case .leftHalf:
            return CGRect(
                x: visibleFrame.minX,
                y: visibleFrame.minY,
                width: visibleFrame.width / 2,
                height: visibleFrame.height
            ).integral
        case .rightHalf:
            return CGRect(
                x: visibleFrame.midX,
                y: visibleFrame.minY,
                width: visibleFrame.width / 2,
                height: visibleFrame.height
            ).integral
        case .firstThird:
            return thirdFrame(index: 0, visibleFrame: visibleFrame)
        case .centerThird:
            return thirdFrame(index: 1, visibleFrame: visibleFrame)
        case .lastThird:
            return thirdFrame(index: 2, visibleFrame: visibleFrame)
        }
    }

    static func constrained(_ frame: CGRect, to visibleFrame: CGRect) -> CGRect {
        var result = frame
        result.size.width = min(max(result.width, 160), visibleFrame.width)
        result.size.height = min(max(result.height, 120), visibleFrame.height)
        result.origin.x = min(
            max(result.minX, visibleFrame.minX),
            visibleFrame.maxX - result.width
        )
        result.origin.y = min(
            max(result.minY, visibleFrame.minY),
            visibleFrame.maxY - result.height
        )
        return result.integral
    }

    static func appKitFrameToAX(_ frame: CGRect, mainDisplayTop: CGFloat) -> CGRect {
        CGRect(
            x: frame.minX,
            y: mainDisplayTop - frame.maxY,
            width: frame.width,
            height: frame.height
        )
    }

    static func approximatelyEqual(
        _ lhs: CGRect,
        _ rhs: CGRect,
        tolerance: CGFloat = 3
    ) -> Bool {
        abs(lhs.minX - rhs.minX) <= tolerance &&
        abs(lhs.minY - rhs.minY) <= tolerance &&
        abs(lhs.width - rhs.width) <= tolerance &&
        abs(lhs.height - rhs.height) <= tolerance
    }

    private static func thirdFrame(index: Int, visibleFrame: CGRect) -> CGRect {
        let third = visibleFrame.width / 3
        let x = visibleFrame.minX + third * CGFloat(index)
        let width = index == 2 ? visibleFrame.maxX - x : third
        return CGRect(
            x: x,
            y: visibleFrame.minY,
            width: width,
            height: visibleFrame.height
        ).integral
    }
}

final class ExactWindowActionProvider {
    static let shared = ExactWindowActionProvider()

    private let fullscreenAttribute = "AXFullScreen" as CFString

    func availability(
        for action: WindowManagementAction,
        ownerPID: pid_t?,
        windowID: CGWindowID?
    ) -> WindowActionAvailability {
        guard let ownerPID else {
            return .unsupported("The selected item has no running process.")
        }

        if action == .forceQuitApplication {
            return NSRunningApplication(processIdentifier: ownerPID) == nil
                ? .unsupported("The application is no longer running.")
                : .supported
        }

        guard let windowID,
              let window = AXWindowIdentityLookup.windowElement(
                  ownerPID: ownerPID,
                  windowID: windowID
              ) else {
            return .unsupported("The exact Accessibility window is unavailable.")
        }

        switch action {
        case .restoreWindow:
            guard boolValue(of: kAXMinimizedAttribute as CFString, on: window) == true else {
                return .unsupported("The selected window is not minimized.")
            }
            return isSettable(kAXMinimizedAttribute as CFString, on: window)
                ? .supported
                : .unsupported("The application does not expose a settable minimized state.")

        case .toggleFullscreen:
            return isSettable(fullscreenAttribute, on: window)
                ? .supported
                : .unsupported("The application does not expose a settable fullscreen state.")

        case .zoomWindow:
            return zoomButton(for: window) != nil || canSetFrame(of: window)
                ? .supported
                : .unsupported("The application exposes neither a zoom button nor a settable frame.")

        case .moveToNextDisplay:
            return canSetFrame(of: window) && displayTargets().count > 1
                ? .supported
                : .unsupported("Moving requires a settable frame and at least two displays.")

        case .centerWindow, .tileLeft, .tileRight, .tileFirstThird,
             .tileCenterThird, .tileLastThird:
            return canSetFrame(of: window)
                ? .supported
                : .unsupported("The application does not expose a settable window frame.")

        case .forceQuitApplication:
            return .supported
        }
    }

    func perform(
        _ action: WindowManagementAction,
        ownerPID: pid_t?,
        windowID: CGWindowID?
    ) -> WindowActionResult {
        guard let ownerPID else {
            return .failure("No running process is associated with the selected item.")
        }

        if action == .forceQuitApplication {
            guard let app = NSRunningApplication(processIdentifier: ownerPID) else {
                return .failure("The selected application is no longer running.")
            }
            return app.forceTerminate()
                ? .success("Force quit request sent to \(app.localizedName ?? "the application").")
                : .failure("macOS rejected the force quit request.")
        }

        guard let windowID,
              let window = AXWindowIdentityLookup.windowElement(
                  ownerPID: ownerPID,
                  windowID: windowID
              ) else {
            return .failure("The exact Accessibility window could not be resolved.")
        }

        switch action {
        case .restoreWindow:
            let result = AXUIElementSetAttributeValue(
                window,
                kAXMinimizedAttribute as CFString,
                kCFBooleanFalse
            )
            guard result == .success else {
                return .failure(
                    "The application rejected window restoration (AX error \(result.rawValue))."
                )
            }
            guard boolValue(of: kAXMinimizedAttribute as CFString, on: window) != true else {
                return .failure("The application accepted the request but the exact window remained minimized.")
            }
            return .success("The selected window was restored.")

        case .toggleFullscreen:
            let current = boolValue(of: fullscreenAttribute, on: window) ?? false
            let result = AXUIElementSetAttributeValue(
                window,
                fullscreenAttribute,
                current ? kCFBooleanFalse : kCFBooleanTrue
            )
            guard result == .success else {
                return .failure(
                    "The application rejected the fullscreen change (AX error \(result.rawValue))."
                )
            }
            if let observed = boolValue(of: fullscreenAttribute, on: window),
               observed == current {
                return .failure("The application accepted the request but fullscreen state did not change.")
            }
            return .success(current ? "Fullscreen was disabled." : "Fullscreen was enabled.")

        case .zoomWindow:
            if let zoomButton = zoomButton(for: window) {
                let before = frame(of: window)
                let result = AXUIElementPerformAction(
                    zoomButton,
                    kAXPressAction as CFString
                )
                if result == .success {
                    let after = frame(of: window)
                    if before == nil || after == nil || before != after {
                        return .success("The selected window's zoom control was activated.")
                    }
                }
            }
            guard let target = currentDisplayTarget(for: window) else {
                return .failure("The current display could not be resolved.")
            }
            return setFrame(
                target.frame,
                on: window,
                destinationVisibleFrame: target.frame
            )

        case .moveToNextDisplay:
            guard let currentFrame = frame(of: window),
                  let target = nextDisplayTarget(for: currentFrame) else {
                return .failure("A destination display could not be resolved.")
            }
            let destination = WindowGeometryPlanner.centeredFrame(
                windowSize: currentFrame.size,
                visibleFrame: target.frame
            )
            return setFrame(
                destination,
                on: window,
                destinationVisibleFrame: target.frame
            )

        case .centerWindow:
            guard let currentFrame = frame(of: window),
                  let target = displayTarget(containing: currentFrame) else {
                return .failure("The current display could not be resolved.")
            }
            return setFrame(
                WindowGeometryPlanner.centeredFrame(
                    windowSize: currentFrame.size,
                    visibleFrame: target.frame
                ),
                on: window,
                destinationVisibleFrame: target.frame
            )

        case .tileLeft:
            return tile(.leftHalf, window: window)
        case .tileRight:
            return tile(.rightHalf, window: window)
        case .tileFirstThird:
            return tile(.firstThird, window: window)
        case .tileCenterThird:
            return tile(.centerThird, window: window)
        case .tileLastThird:
            return tile(.lastThird, window: window)
        case .forceQuitApplication:
            return .failure("Unexpected force-quit routing state.")
        }
    }

    private func tile(
        _ tile: WindowGeometryPlanner.Tile,
        window: AXUIElement
    ) -> WindowActionResult {
        guard let currentFrame = frame(of: window),
              let target = displayTarget(containing: currentFrame) else {
            return .failure("The current display could not be resolved.")
        }
        return setFrame(
            WindowGeometryPlanner.tiledFrame(tile, visibleFrame: target.frame),
            on: window,
            destinationVisibleFrame: target.frame
        )
    }

    private func canSetFrame(of window: AXUIElement) -> Bool {
        isSettable(kAXPositionAttribute as CFString, on: window) &&
        isSettable(kAXSizeAttribute as CFString, on: window)
    }

    private func isSettable(
        _ attribute: CFString,
        on element: AXUIElement
    ) -> Bool {
        var settable = DarwinBoolean(false)
        return AXUIElementIsAttributeSettable(element, attribute, &settable) == .success &&
            settable.boolValue
    }

    private func boolValue(
        of attribute: CFString,
        on element: AXUIElement
    ) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
              let number = value as? NSNumber else {
            return nil
        }
        return number.boolValue
    }

    private func zoomButton(for window: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            window,
            kAXZoomButtonAttribute as CFString,
            &value
        ) == .success, let value else {
            return nil
        }
        return unsafeBitCast(value, to: AXUIElement.self)
    }

    private func frame(of window: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            window,
            kAXPositionAttribute as CFString,
            &positionValue
        ) == .success,
        AXUIElementCopyAttributeValue(
            window,
            kAXSizeAttribute as CFString,
            &sizeValue
        ) == .success,
        let positionValue,
        let sizeValue else {
            return nil
        }

        var position = CGPoint.zero
        var size = CGSize.zero
        guard CFGetTypeID(positionValue) == AXValueGetTypeID(),
              CFGetTypeID(sizeValue) == AXValueGetTypeID(),
              AXValueGetValue(
                  unsafeBitCast(positionValue, to: AXValue.self),
                  .cgPoint,
                  &position
              ),
              AXValueGetValue(
                  unsafeBitCast(sizeValue, to: AXValue.self),
                  .cgSize,
                  &size
              ) else {
            return nil
        }
        return CGRect(origin: position, size: size)
    }

    private func setFrame(
        _ requestedFrame: CGRect,
        on window: AXUIElement,
        destinationVisibleFrame: CGRect
    ) -> WindowActionResult {
        let targetFrame = WindowGeometryPlanner.constrained(
            requestedFrame,
            to: destinationVisibleFrame
        )
        var position = targetFrame.origin
        var size = targetFrame.size
        guard let positionValue = AXValueCreate(.cgPoint, &position),
              let sizeValue = AXValueCreate(.cgSize, &size) else {
            return .failure("macOS could not encode the requested window frame.")
        }

        // Position first when moving across displays; then size. Some apps clamp
        // size according to the display containing the current origin.
        let positionResult = AXUIElementSetAttributeValue(
            window,
            kAXPositionAttribute as CFString,
            positionValue
        )
        let sizeResult = AXUIElementSetAttributeValue(
            window,
            kAXSizeAttribute as CFString,
            sizeValue
        )
        guard sizeResult == .success, positionResult == .success else {
            return .failure(
                "The application rejected the requested frame (size AX \(sizeResult.rawValue), position AX \(positionResult.rawValue))."
            )
        }

        if let observed = frame(of: window),
           !WindowGeometryPlanner.approximatelyEqual(observed, targetFrame) {
            return .failure(
                "The application accepted the frame request but reported \(observed.integral) instead of \(targetFrame.integral)."
            )
        }
        return .success("The selected exact window frame was updated.")
    }

    private func currentDisplayTarget(
        for window: AXUIElement
    ) -> WindowGeometryTarget? {
        guard let current = frame(of: window) else { return nil }
        return displayTarget(containing: current)
    }

    private func nextDisplayTarget(
        for currentFrame: CGRect
    ) -> WindowGeometryTarget? {
        let targets = displayTargets()
        guard targets.count > 1 else { return nil }
        guard let currentIndex = targets.firstIndex(where: {
            $0.frame.contains(currentFrame.center)
        }) ?? targets.firstIndex(where: {
            $0.frame.intersects(currentFrame)
        }) else {
            return targets.first
        }
        return targets[(currentIndex + 1) % targets.count]
    }

    private func displayTarget(
        containing frame: CGRect
    ) -> WindowGeometryTarget? {
        let targets = displayTargets()
        return targets.first(where: { $0.frame.contains(frame.center) }) ??
            targets.first(where: { $0.frame.intersects(frame) }) ??
            targets.first
    }

    private func displayTargets() -> [WindowGeometryTarget] {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return [] }
        let mainDisplayTop = screens.first(where: {
            screenDisplayID($0) == CGMainDisplayID()
        })?.frame.maxY ?? NSScreen.main?.frame.maxY ?? screens[0].frame.maxY

        return screens.compactMap { screen in
            guard let displayID = screenDisplayID(screen) else { return nil }
            return WindowGeometryTarget(
                frame: WindowGeometryPlanner.appKitFrameToAX(
                    screen.visibleFrame,
                    mainDisplayTop: mainDisplayTop
                ),
                displayID: displayID
            )
        }
        .sorted { $0.displayID < $1.displayID }
    }

    private func screenDisplayID(_ screen: NSScreen) -> CGDirectDisplayID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return (screen.deviceDescription[key] as? NSNumber)?.uint32Value
    }
}

private extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}
