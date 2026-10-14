import AppKit
import SwiftUI
import XCTest
@testable import CmdTab

final class ProductionRadialGeometryTests: XCTestCase {
    @MainActor
    func testRenderedIconsStayAtCardinalSlotCentersWithLongTitlesAndSelection() throws {
        // A non-square solid icon exposes both stretching and off-center layout.
        let icon = NSImage(size: NSSize(width: 26, height: 13), flipped: false) { rect in
            NSColor.red.setFill()
            rect.fill()
            return true
        }
        let model = SwitcherViewModel()
        model.items = (0..<4).map { index in
            SwitcherItem(
                title: index.isMultiple(of: 2) ? "Finder" : "A very long application and window title",
                subtitle: "",
                icon: icon,
                previewImage: nil,
                historyIdentity: .appWindow(pid: 1, windowID: UInt32(index + 1))
            ) {}
        }
        model.radialViewportState.reset(itemCount: 4, selectedIndex: 0)
        let centers = [CGPoint(x: 280, y: 92), CGPoint(x: 468, y: 280),
                       CGPoint(x: 280, y: 468), CGPoint(x: 92, y: 280)]

        // Move the highlight from a short title to a long one. Neither the
        // selector scale nor the label may move the image's visual center.
        for selected in [0, 1] {
            model.selectedIndex = selected
            model.radialViewportState.selectedSlot = selected
            let renderer = ImageRenderer(content: ProductionRadialMenuView(viewModel: model))
            renderer.scale = 1
            let image = try XCTUnwrap(renderer.cgImage)
            XCTAssertEqual(image.width, 560)
            XCTAssertEqual(image.height, 560)
            let bitmap = NSBitmapImageRep(cgImage: image)

            for (slot, center) in centers.enumerated() {
                var pixels: [CGPoint] = []
                // Sample locally: labels, center text and the blue highlight
                // cannot accidentally satisfy the solid red icon mask.
                for y in Int(center.y - 36)...Int(center.y + 36) {
                    for x in Int(center.x - 36)...Int(center.x + 36) {
                        let color = try XCTUnwrap(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB))
                        if color.redComponent > 0.8 && color.greenComponent < 0.15 && color.blueComponent < 0.15 {
                            pixels.append(CGPoint(x: x, y: y))
                        }
                    }
                }
                XCTAssertFalse(pixels.isEmpty, "Missing icon at slot \(slot)")
                guard !pixels.isEmpty else { continue }
                let minX = try XCTUnwrap(pixels.map(\.x).min())
                let maxX = try XCTUnwrap(pixels.map(\.x).max())
                let minY = try XCTUnwrap(pixels.map(\.y).min())
                let maxY = try XCTUnwrap(pixels.map(\.y).max())
                XCTAssertEqual((minX + maxX + 1) / 2, center.x, accuracy: 1, "Horizontal drift at slot \(slot)")
                XCTAssertEqual((minY + maxY + 1) / 2, center.y, accuracy: 1, "Vertical drift at slot \(slot)")
                let width = maxX - minX + 1
                let height = maxY - minY + 1
                XCTAssertEqual(width, slot == selected ? 56 : 52, accuracy: 2, "Icon size at slot \(slot)")
                XCTAssertEqual(width / height, 2, accuracy: 0.15, "Icon aspect ratio at slot \(slot)")
            }
        }
    }
}
