import XCTest
@testable import CmdTab

final class TrialNotificationCoordinatorTests: XCTestCase {
    func testActiveTrialSchedulesThreeDayAndOneDayWarnings() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let endsAt = now.addingTimeInterval(5 * 24 * 60 * 60)

        let plan = TrialNotificationPlan.make(
            status: .activeTrial(
                startedAt: now,
                endsAt: endsAt,
                daysRemaining: 5
            ),
            now: now
        )

        XCTAssertEqual(
            plan.reminders.map(\.identifier),
            ["CmdTab.trial.three-days", "CmdTab.trial.one-day"]
        )
        XCTAssertEqual(
            plan.reminders.map(\.deliveryDate),
            [
                endsAt.addingTimeInterval(-3 * 24 * 60 * 60),
                endsAt.addingTimeInterval(-1 * 24 * 60 * 60),
            ]
        )
    }

    func testPastReminderCheckpointsAreNotRescheduled() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let endsAt = now.addingTimeInterval(12 * 60 * 60)

        let plan = TrialNotificationPlan.make(
            status: .activeTrial(
                startedAt: now.addingTimeInterval(-13 * 24 * 60 * 60),
                endsAt: endsAt,
                daysRemaining: 1
            ),
            now: now
        )

        XCTAssertTrue(plan.reminders.isEmpty)
    }

    func testFreshExpirySchedulesOneImmediateNotice() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let endedAt = now.addingTimeInterval(-60)

        let plan = TrialNotificationPlan.make(
            status: .expired(
                startedAt: endedAt.addingTimeInterval(-14 * 24 * 60 * 60),
                endedAt: endedAt,
                daysOverdue: 0
            ),
            now: now
        )

        XCTAssertEqual(plan.reminders.map(\.identifier), ["CmdTab.trial.expired"])
        XCTAssertEqual(plan.reminders.first?.deliveryDate, now.addingTimeInterval(2))
    }

    func testOldExpiryAndLicensedStateScheduleNothing() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let oldEnd = now.addingTimeInterval(-2 * 24 * 60 * 60)
        let payload = SignedLicensePayload(
            version: 1,
            product: "cmdtab",
            email: "owner@example.com",
            licenseID: "license-1",
            issuedAt: ISO8601DateFormatter().string(from: now),
            purchaserName: nil
        )

        XCTAssertTrue(
            TrialNotificationPlan.make(
                status: .expired(
                    startedAt: oldEnd.addingTimeInterval(-14 * 24 * 60 * 60),
                    endedAt: oldEnd,
                    daysOverdue: 2
                ),
                now: now
            ).reminders.isEmpty
        )
        XCTAssertTrue(
            TrialNotificationPlan.make(
                status: .licensed(payload: payload, activatedAt: now),
                now: now
            ).reminders.isEmpty
        )
    }
}
