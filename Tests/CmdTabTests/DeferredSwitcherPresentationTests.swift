import XCTest
@testable import CmdTab

final class DeferredSwitcherPresentationTests: XCTestCase {
    func testScopedSelectorWaitsForExactSnapshotWhileModifierIsHeld() {
        let profileID = UUID()
        var presentation = DeferredSwitcherPresentation()
        presentation.deferShow(
            profileID: profileID,
            reverse: false,
            requireHeldModifier: .command
        )

        XCTAssertEqual(
            presentation.takeReadyAction(isModifierHeld: { $0 == .command }),
            .show(
                profileID: profileID,
                reverse: false,
                requireHeldModifier: .command
            )
        )
        XCTAssertNil(presentation.action)
    }

    func testScopedSelectorDoesNotAppearAfterPrimaryModifierRelease() {
        var presentation = DeferredSwitcherPresentation()
        presentation.deferShow(
            profileID: UUID(),
            reverse: false,
            requireHeldModifier: .command
        )

        XCTAssertNil(
            presentation.takeReadyAction(isModifierHeld: { _ in false })
        )
        XCTAssertNil(presentation.action)
    }

    func testQuickSwitchRemainsPendingUntilExactSnapshotArrives() {
        let profileID = UUID()
        var presentation = DeferredSwitcherPresentation()
        presentation.deferCommit(profileID: profileID, reverse: true)

        XCTAssertEqual(
            presentation.takeReadyAction(isModifierHeld: { _ in false }),
            .commit(profileID: profileID, reverse: true)
        )
    }
}
