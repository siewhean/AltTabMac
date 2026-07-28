import Foundation
import UserNotifications

struct TrialNotificationPlan: Equatable {
    struct Reminder: Equatable {
        let identifier: String
        let title: String
        let body: String
        let deliveryDate: Date
    }

    let reminders: [Reminder]

    static func make(status: LicensingStatus, now: Date) -> TrialNotificationPlan {
        switch status {
        case let .activeTrial(_, endsAt, _):
            let checkpoints: [(days: Int, identifier: String)] = [
                (3, "CmdTab.trial.three-days"),
                (1, "CmdTab.trial.one-day"),
            ]
            let reminders = checkpoints.compactMap { checkpoint -> Reminder? in
                let deliveryDate = endsAt.addingTimeInterval(
                    -Double(checkpoint.days) * 24 * 60 * 60
                )
                guard deliveryDate > now else { return nil }
                let dayCopy = checkpoint.days == 1 ? "1 day" : "3 days"
                return Reminder(
                    identifier: checkpoint.identifier,
                    title: "CmdTab trial: \(dayCopy) remaining",
                    body: "Your CmdTab trial ends soon. Buy once to keep the CmdTab switcher, or continue using the native macOS switcher after expiry.",
                    deliveryDate: deliveryDate
                )
            }
            return TrialNotificationPlan(reminders: reminders)

        case let .expired(_, endedAt, _):
            guard now.timeIntervalSince(endedAt) < 24 * 60 * 60 else {
                return TrialNotificationPlan(reminders: [])
            }
            return TrialNotificationPlan(
                reminders: [
                    Reminder(
                        identifier: "CmdTab.trial.expired",
                        title: "CmdTab trial ended",
                        body: "CmdTab switching is locked, but native macOS Command-Tab remains available. Buy CmdTab or activate a license from the menu-bar app.",
                        deliveryDate: now.addingTimeInterval(2)
                    )
                ]
            )

        case .unregistered, .licensed:
            return TrialNotificationPlan(reminders: [])
        }
    }
}

@MainActor
final class TrialNotificationCoordinator {
    private static let managedIdentifiers = [
        "CmdTab.trial.three-days",
        "CmdTab.trial.one-day",
        "CmdTab.trial.expired",
    ]

    private let center: UNUserNotificationCenter
    private let currentDate: () -> Date

    init(
        center: UNUserNotificationCenter = .current(),
        currentDate: @escaping () -> Date = Date.init
    ) {
        self.center = center
        self.currentDate = currentDate
    }

    func refresh(for status: LicensingStatus) {
        let plan = TrialNotificationPlan.make(status: status, now: currentDate())
        center.removePendingNotificationRequests(
            withIdentifiers: Self.managedIdentifiers
        )

        guard !plan.reminders.isEmpty else { return }
        center.getNotificationSettings { [weak self] settings in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch settings.authorizationStatus {
                case .authorized, .provisional:
                    self.schedule(plan)
                case .notDetermined:
                    self.center.requestAuthorization(options: [.alert, .sound]) {
                        granted,
                        _ in
                        guard granted else { return }
                        Task { @MainActor [weak self] in
                            self?.schedule(plan)
                        }
                    }
                case .denied, .ephemeral:
                    break
                @unknown default:
                    break
                }
            }
        }
    }

    private func schedule(_ plan: TrialNotificationPlan) {
        for reminder in plan.reminders {
            let interval = max(1, reminder.deliveryDate.timeIntervalSince(currentDate()))
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: reminder.identifier,
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(
                    timeInterval: interval,
                    repeats: false
                )
            )
            center.add(request)
        }
    }
}
