import XCTest
@testable import CmdTab

final class ClassicPreviewFallbackTests: XCTestCase {
    func testMissingPreviewUsesApplicationIconWhenAvailable() {
        XCTAssertEqual(
            ClassicPreviewFallback.iconKind(hasApplicationIcon: true),
            .applicationIcon
        )
    }

    func testMissingPreviewUsesVisibleSystemIconAndLabelWithoutApplicationIcon() {
        XCTAssertEqual(
            ClassicPreviewFallback.iconKind(hasApplicationIcon: false),
            .systemSymbol
        )
        XCTAssertEqual(ClassicPreviewFallback.systemSymbolName, "app.dashed")
        XCTAssertEqual(ClassicPreviewFallback.label, "Preview unavailable")
        XCTAssertEqual(
            ClassicPreviewFallback.accessibilityLabel(for: "Fixture"),
            "Preview unavailable for Fixture"
        )
    }
}
