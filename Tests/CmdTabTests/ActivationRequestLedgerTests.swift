import XCTest
@testable import CmdTab

final class ActivationRequestLedgerTests: XCTestCase {
    func testNewerSwitchCancelsAnEarlierActivationChain() {
        let ledger = ActivationRequestLedger()
        let first = ledger.begin(pid: 100)
        XCTAssertTrue(ledger.isCurrent(first))

        let second = ledger.begin(pid: 200)
        XCTAssertFalse(ledger.isCurrent(first), "Choosing B must stop A's retries from stealing focus back.")
        XCTAssertTrue(ledger.isCurrent(second))
        XCTAssertEqual(ledger.currentPID, 200)
    }

    func testRepeatedSwitchToTheSameAppIsStillANewRequest() {
        let ledger = ActivationRequestLedger()
        let first = ledger.begin(pid: 100)
        let second = ledger.begin(pid: 100)
        XCTAssertFalse(ledger.isCurrent(first))
        XCTAssertTrue(ledger.isCurrent(second))
        XCTAssertEqual(
            ledger.currentPID, first.pid,
            "Same process: the superseded chain must leave the shared pending state to the newer one."
        )
    }

    func testTokensAreSafeToCheckFromTheActivationQueue() {
        let ledger = ActivationRequestLedger()
        let token = ledger.begin(pid: 7)
        let checked = expectation(description: "background check")
        DispatchQueue.global(qos: .userInteractive).async {
            XCTAssertTrue(ledger.isCurrent(token))
            checked.fulfill()
        }
        wait(for: [checked], timeout: 1)
    }
}
