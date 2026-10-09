import AppKit
import CoreGraphics

/// Window bounds from Core Graphics use a global space whose origin is the
/// top-left of the main display, with y growing downwards. `NSScreen.frame`
/// and `NSEvent.mouseLocation` use AppKit's bottom-left origin. The two only
/// coincide on a single display, so screen lookups for CG window bounds must
/// stay in CG display coordinates.
enum DisplayGeometry {
    /// The CG bounds of the display containing the rect's centre, else the
    /// first display it overlaps.
    static func screenFrame(containing rect: CGRect, displayBounds: [CGRect]) -> CGRect? {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        if let containing = displayBounds.first(where: { $0.contains(center) }) {
            return containing
        }
        return displayBounds.first(where: { $0.intersects(rect) })
    }

    /// Converts an AppKit global point (bottom-left origin) to CG global
    /// coordinates, given the main display's height.
    static func cgPoint(fromAppKit point: CGPoint, mainDisplayHeight: CGFloat) -> CGPoint {
        CGPoint(x: point.x, y: mainDisplayHeight - point.y)
    }

    static func activeDisplayBounds() -> [CGRect] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else {
            return []
        }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &displays, &count) == .success else {
            return []
        }
        return displays.prefix(Int(count)).map(CGDisplayBounds)
    }

    static func mouseLocationInCG() -> CGPoint {
        cgPoint(
            fromAppKit: NSEvent.mouseLocation,
            mainDisplayHeight: CGDisplayBounds(CGMainDisplayID()).height
        )
    }
}
