import AppKit
import XCTest
@testable import CmdTab

final class CapturePixelFormatTests: XCTestCase {
    private let formats: [UInt32] = [
        CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue,
        CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue,
        CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue,
        CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue,
        CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.noneSkipFirst.rawValue,
        CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.noneSkipLast.rawValue,
    ]

    private func image(format: UInt32, draw: (CGContext) -> Void) throws -> CGImage {
        let context = try XCTUnwrap(CGContext(
            data: nil, width: 120, height: 80, bitsPerComponent: 8, bytesPerRow: 480,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: format
        ))
        draw(context)
        return try XCTUnwrap(context.makeImage())
    }

    func testOpaquePrimaryColorsAreAcceptedInEveryByteOrder() throws {
        for format in formats {
            for color in [NSColor.red, .green, .blue] {
                let capture = try image(format: format) { context in
                    context.setFillColor(color.cgColor)
                    context.fill(CGRect(x: 0, y: 0, width: 120, height: 80))
                }
                XCTAssertTrue(AppSwitcher.isPresentationUsefulWindowCapture(capture), "format \(format), \(color)")
                let trimmed = AppSwitcher.trimmedWindowCapture(capture)
                XCTAssertEqual(trimmed.width, 120, "Opaque color must not be interpreted as transparency")
                XCTAssertEqual(trimmed.height, 80)
            }
        }
    }

    func testBlackCapturesAreRejectedInEveryByteOrder() throws {
        for format in formats {
            let capture = try image(format: format) { context in
                context.setFillColor(NSColor.black.cgColor)
                context.fill(CGRect(x: 0, y: 0, width: 120, height: 80))
            }
            XCTAssertFalse(AppSwitcher.isPresentationUsefulWindowCapture(capture), "format \(format)")
        }
    }

    func testDarkCapturesWithContentArePreservedInEveryByteOrder() throws {
        for format in formats {
            let capture = try image(format: format) { context in
                context.setFillColor(CGColor(gray: 0.015, alpha: 1))
                context.fill(CGRect(x: 0, y: 0, width: 120, height: 80))
                context.setFillColor(CGColor(gray: 0.4, alpha: 1))
                context.fill(CGRect(x: 30, y: 20, width: 60, height: 40))
            }
            XCTAssertTrue(AppSwitcher.isPresentationUsefulWindowCapture(capture), "format \(format)")
        }
    }

    func testTransparentCapturesAreRejectedInBothByteOrders() throws {
        for format in formats.prefix(4) {
            let capture = try image(format: format) { $0.clear(CGRect(x: 0, y: 0, width: 120, height: 80)) }
            XCTAssertFalse(AppSwitcher.isPresentationUsefulWindowCapture(capture))
        }
    }

    func testTransparentBordersAreTrimmedWithoutCroppingOpaqueRedContent() throws {
        for format in formats.prefix(4) {
            let capture = try image(format: format) { context in
                context.clear(CGRect(x: 0, y: 0, width: 120, height: 80))
                context.setFillColor(NSColor.red.cgColor)
                context.fill(CGRect(x: 7, y: 5, width: 102, height: 62))
            }
            let trimmed = AppSwitcher.trimmedWindowCapture(capture)
            XCTAssertEqual(trimmed.width, 102)
            XCTAssertEqual(trimmed.height, 62)
            let alphaContext = try XCTUnwrap(CGContext(
                data: nil, width: trimmed.width, height: trimmed.height,
                bitsPerComponent: 8, bytesPerRow: trimmed.width,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue
            ))
            alphaContext.draw(trimmed, in: CGRect(x: 0, y: 0, width: trimmed.width, height: trimmed.height))
            let alpha = try XCTUnwrap(alphaContext.data).assumingMemoryBound(to: UInt8.self)
            for y in [0, trimmed.height - 1] {
                for x in [0, trimmed.width - 1] {
                    XCTAssertEqual(alpha[y * alphaContext.bytesPerRow + x], 255,
                                   "Every cropped corner must lie inside the opaque content")
                }
            }
            // A second trim catches asymmetric crop-coordinate mistakes.
            let retrimmed = AppSwitcher.trimmedWindowCapture(trimmed)
            XCTAssertEqual(retrimmed.width, 102)
            XCTAssertEqual(retrimmed.height, 62)
            XCTAssertTrue(AppSwitcher.isPresentationUsefulWindowCapture(trimmed))
        }
    }

    func testGrayscaleWithoutAlphaIsValidatedInsteadOfAutomaticallyAccepted() throws {
        for value: UInt8 in [0, 160] {
            let bytes = Data(repeating: value, count: 120 * 80)
            let provider = try XCTUnwrap(CGDataProvider(data: bytes as CFData))
            let capture = try XCTUnwrap(CGImage(
                width: 120, height: 80, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: 120,
                space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
            ))
            XCTAssertEqual(AppSwitcher.isPresentationUsefulWindowCapture(capture), value != 0)
            XCTAssertEqual(AppSwitcher.trimmedWindowCapture(capture).width, 120)
        }
    }

    func testBlackInteriorWithBrightCaptureBorderIsRejected() throws {
        for format in formats {
            let capture = try image(format: format) { context in
                context.setFillColor(NSColor.black.cgColor)
                context.fill(CGRect(x: 0, y: 0, width: 120, height: 80))
                context.setStrokeColor(NSColor.white.cgColor)
                context.setLineWidth(6)
                context.stroke(CGRect(x: 0, y: 0, width: 120, height: 80))
            }
            XCTAssertFalse(AppSwitcher.isPresentationUsefulWindowCapture(capture), "format \(format)")
            XCTAssertFalse(AppSwitcher.isPresentationUsefulWindowCapture(
                AppSwitcher.presentationPreparedWindowCapture(capture)
            ), "A remaining bright border after preparation must not validate a black interior")
        }
    }

    func testDarkContentNearEachEdgeSurvivesBorderExclusion() throws {
        // These marks extend from the outer margin into the content area, as
        // sidebar text or controls do. Content exclusively in the outer 1/12
        // is deliberately not sufficient to validate an otherwise black frame.
        let marks = [
            CGRect(x: 5, y: 30, width: 14, height: 8),
            CGRect(x: 101, y: 30, width: 14, height: 8),
            CGRect(x: 40, y: 3, width: 20, height: 9),
            CGRect(x: 40, y: 68, width: 20, height: 9),
        ]
        for mark in marks {
            let capture = try image(format: formats[0]) { context in
                context.setFillColor(CGColor(gray: 0.015, alpha: 1))
                context.fill(CGRect(x: 0, y: 0, width: 120, height: 80))
                context.setFillColor(CGColor(gray: 0.4, alpha: 1))
                context.fill(mark)
            }
            XCTAssertTrue(AppSwitcher.isPresentationUsefulWindowCapture(capture), "Near-edge content \(mark)")
            XCTAssertTrue(AppSwitcher.isPresentationUsefulWindowCapture(
                AppSwitcher.presentationPreparedWindowCapture(capture)
            ), "Prepared near-edge content \(mark)")
        }
    }
}
