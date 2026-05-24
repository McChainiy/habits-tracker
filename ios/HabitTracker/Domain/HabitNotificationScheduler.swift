import Foundation
import UserNotifications

final class HabitNotificationScheduler: NSObject, UNUserNotificationCenterDelegate {
    struct Plan: Sendable {
        let habitID: UUID
        let title: String
        let note: String
        let scheduleModeRawValue: String
        let scheduledWeekdays: Set<Int>
        let reminderTimes: [String]
        let isArchived: Bool
        let isDeleted: Bool
    }

    static let shared = HabitNotificationScheduler()

    private let center = UNUserNotificationCenter.current()

    private override init() {}

    func configure() {
        center.delegate = self
    }

    static func plan(for habit: Habit) -> Plan {
        Plan(
            habitID: habit.id,
            title: habit.title,
            note: habit.note,
            scheduleModeRawValue: habit.scheduleModeRawValue,
            scheduledWeekdays: habit.scheduledWeekdays,
            reminderTimes: habit.reminderTimes,
            isArchived: habit.isArchived,
            isDeleted: habit.deletedAt != nil
        )
    }

    func scheduleNotifications(for plan: Plan) async {
        await removeNotifications(forHabitID: plan.habitID)

        let times = plan.reminderTimes.compactMap(Self.timeComponents(from:))
        guard !times.isEmpty, !plan.isArchived, !plan.isDeleted else { return }
        guard await ensureAuthorization() else { return }

        let weekdays = notificationWeekdays(for: plan)
        for time in times {
            for weekday in weekdays {
                let content = UNMutableNotificationContent()
                content.title = plan.title
                content.body = plan.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "Время отметить привычку."
                    : plan.note
                content.sound = .default

                var dateComponents = DateComponents()
                dateComponents.calendar = Calendar.current
                dateComponents.weekday = weekday
                dateComponents.hour = time.hour
                dateComponents.minute = time.minute

                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
                let request = UNNotificationRequest(
                    identifier: notificationID(habitID: plan.habitID, weekday: weekday, hour: time.hour, minute: time.minute),
                    content: content,
                    trigger: trigger
                )
                try? await center.add(request)
            }
        }
    }

    func removeNotifications(forHabitID habitID: UUID) async {
        let prefix = notificationPrefix(for: habitID)
        let requests = await center.pendingNotificationRequests()
        let identifiers = requests
            .map(\.identifier)
            .filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func removeNotifications(forHabitIDs habitIDs: [UUID]) async {
        for habitID in habitIDs {
            await removeNotifications(forHabitID: habitID)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    private func ensureAuthorization() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    private func notificationWeekdays(for plan: Plan) -> [Int] {
        switch HabitScheduleMode(rawValue: plan.scheduleModeRawValue) ?? .days {
        case .days:
            return plan.scheduledWeekdays
                .sorted()
                .map(Self.notificationWeekday(fromMondayIndex:))
        case .count:
            return (1...7).map(Self.notificationWeekday(fromMondayIndex:))
        }
    }

    private static func timeComponents(from time: String) -> (hour: Int, minute: Int)? {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        let hour = parts[0]
        let minute = parts[1]
        guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        return (hour, minute)
    }

    private static func notificationWeekday(fromMondayIndex weekday: Int) -> Int {
        weekday == 7 ? 1 : weekday + 1
    }

    private func notificationPrefix(for habitID: UUID) -> String {
        "habit-reminder-\(habitID.uuidString)-"
    }

    private func notificationID(habitID: UUID, weekday: Int, hour: Int, minute: Int) -> String {
        "\(notificationPrefix(for: habitID))\(weekday)-\(hour)-\(minute)"
    }
}
