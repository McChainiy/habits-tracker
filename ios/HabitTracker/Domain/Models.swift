import Foundation
import SwiftData
import SwiftUI

enum ChallengeStatus: String, Codable, CaseIterable {
    case draft
    case active
    case completed
}

enum HabitEntryStatus: String, Codable, CaseIterable {
    case done
    case failed
    case skipped
}

enum HabitScheduleMode: String, Codable, CaseIterable, Identifiable {
    case days
    case count

    var id: String { rawValue }
}

enum HabitColor: String, CaseIterable, Identifiable {
    case sage = "#62766A"
    case blue = "#71869C"
    case clay = "#9B6B5F"
    case sun = "#B99B45"
    case stone = "#8B8C83"
    case ink = "#60717A"
    case moss = "#75815A"

    var id: String { rawValue }
}

enum AppConfig {
    #if targetEnvironment(simulator)
    static let apiBaseURL = URL(string: "http://127.0.0.1:8001")!
    #else
    static let apiBaseURL = URL(string: "http://MacBook-Air-Danil.local:8001")!
    #endif
}

@Model
final class AppUser {
    @Attribute(.unique) var id: UUID
    var email: String?
    var displayName: String
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \Challenge.user)
    var challenges: [Challenge] = []

    init(
        id: UUID = UUID(),
        email: String? = nil,
        displayName: String = "Local user",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }

    func touch() {
        updatedAt = Date()
    }
}

@Model
final class SyncState {
    @Attribute(.unique) var id: String
    var lastPulledAt: Date?
    var lastPushedAt: Date?
    var lastError: String?
    var updatedAt: Date

    init(
        id: String = "main",
        lastPulledAt: Date? = nil,
        lastPushedAt: Date? = nil,
        lastError: String? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.lastPulledAt = lastPulledAt
        self.lastPushedAt = lastPushedAt
        self.lastError = lastError
        self.updatedAt = updatedAt
    }

    func markSuccess(pulledAt: Date? = nil, pushedAt: Date? = nil) {
        if let pulledAt {
            lastPulledAt = pulledAt
        }
        if let pushedAt {
            lastPushedAt = pushedAt
        }
        lastError = nil
        updatedAt = Date()
    }

    func markFailure(_ error: Error) {
        lastError = error.localizedDescription
        updatedAt = Date()
    }
}

@Model
final class Challenge {
    @Attribute(.unique) var id: UUID
    var customTitle: String = ""
    var colorHex: String = HabitColor.sage.rawValue
    var month: Int
    var year: Int
    var startDate: Date
    var endDate: Date
    var durationWeeks: Int = 4
    var targetWeeks: Int = 3
    var isTimeless: Bool = false
    var rewardText: String = ""
    var statusRawValue: String
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    var user: AppUser?

    @Relationship(deleteRule: .cascade, inverse: \Habit.challenge)
    var habits: [Habit] = []

    init(
        id: UUID = UUID(),
        customTitle: String = "",
        colorHex: String = HabitColor.sage.rawValue,
        month: Int,
        year: Int,
        startDate: Date,
        endDate: Date,
        durationWeeks: Int = 4,
        targetWeeks: Int = 3,
        isTimeless: Bool = false,
        rewardText: String = "",
        status: ChallengeStatus = .active,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil,
        user: AppUser? = nil
    ) {
        self.id = id
        self.customTitle = customTitle
        self.colorHex = colorHex
        self.month = month
        self.year = year
        self.startDate = startDate
        self.endDate = endDate
        self.durationWeeks = durationWeeks
        self.targetWeeks = targetWeeks
        self.isTimeless = isTimeless
        self.rewardText = rewardText
        self.statusRawValue = status.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.user = user
    }

    var status: ChallengeStatus {
        get { ChallengeStatus(rawValue: statusRawValue) ?? .draft }
        set {
            statusRawValue = newValue.rawValue
            touch()
        }
    }

    var title: String {
        let trimmedTitle = customTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty {
            return trimmedTitle
        }

        let components = DateComponents(year: year, month: month, day: 1)
        guard let date = Calendar.current.date(from: components) else {
            return "\(month).\(year)"
        }
        return date.formatted(.dateTime.month(.wide).year())
    }

    func touch() {
        updatedAt = Date()
    }

    func markDeleted(at date: Date = Date()) {
        deletedAt = date
        updatedAt = date
        for habit in habits {
            habit.markDeleted(at: date)
        }
    }
}

@Model
final class Habit {
    @Attribute(.unique) var id: UUID
    var userId: UUID?
    var title: String
    var note: String
    var penaltyText: String
    var colorHex: String
    var scheduleModeRawValue: String = HabitScheduleMode.days.rawValue
    var scheduledWeekdaysRawValue: String = "1,2,3,4,5,6,7"
    var weeklyTarget: Int = 3
    var reminderTimesRawValue: String = ""
    var sortOrder: Int
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    var challenge: Challenge?

    @Relationship(deleteRule: .cascade, inverse: \HabitEntry.habit)
    var entries: [HabitEntry] = []

    init(
        id: UUID = UUID(),
        userId: UUID? = nil,
        title: String,
        note: String = "",
        penaltyText: String,
        colorHex: String,
        scheduleMode: HabitScheduleMode = .days,
        scheduledWeekdays: Set<Int> = Set(1...7),
        weeklyTarget: Int = 3,
        reminderTimes: [String] = [],
        sortOrder: Int,
        isArchived: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil,
        challenge: Challenge? = nil
    ) {
        self.id = id
        self.userId = userId
        self.title = title
        self.note = note
        self.penaltyText = penaltyText
        self.colorHex = colorHex
        self.scheduleModeRawValue = scheduleMode.rawValue
        self.scheduledWeekdaysRawValue = Habit.encodeWeekdays(scheduledWeekdays)
        self.weeklyTarget = weeklyTarget
        self.reminderTimesRawValue = reminderTimes.joined(separator: ",")
        self.sortOrder = sortOrder
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.challenge = challenge
    }

    func touch() {
        updatedAt = Date()
    }

    func markDeleted(at date: Date = Date()) {
        deletedAt = date
        updatedAt = date
        for entry in entries {
            entry.markDeleted(at: date)
        }
    }

    var scheduleMode: HabitScheduleMode {
        get { HabitScheduleMode(rawValue: scheduleModeRawValue) ?? .days }
        set {
            scheduleModeRawValue = newValue.rawValue
            touch()
        }
    }

    var scheduledWeekdays: Set<Int> {
        get {
            let weekdays = scheduledWeekdaysRawValue
                .split(separator: ",")
                .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
                .filter { (1...7).contains($0) }
            return Set(weekdays)
        }
        set {
            scheduledWeekdaysRawValue = Habit.encodeWeekdays(newValue)
            touch()
        }
    }

    var reminderTimes: [String] {
        get {
            reminderTimesRawValue
                .split(separator: ",")
                .map { String($0.trimmingCharacters(in: .whitespaces)) }
                .filter { !$0.isEmpty }
        }
        set {
            reminderTimesRawValue = newValue.joined(separator: ",")
            touch()
        }
    }

    static func encodeWeekdays(_ weekdays: Set<Int>) -> String {
        weekdays
            .filter { (1...7).contains($0) }
            .sorted()
            .map(String.init)
            .joined(separator: ",")
    }

    static func decodeWeekdays(_ value: String) -> Set<Int> {
        let weekdays = value
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            .filter { (1...7).contains($0) }
        return Set(weekdays)
    }

    static func decodeReminderTimes(_ value: String) -> [String] {
        value
            .split(separator: ",")
            .map { String($0.trimmingCharacters(in: .whitespaces)) }
            .filter { !$0.isEmpty }
    }
}

@Model
final class HabitEntry {
    @Attribute(.unique) var id: UUID
    var userId: UUID?
    var entryDate: Date
    var statusRawValue: String
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    var habit: Habit?

    init(
        id: UUID = UUID(),
        userId: UUID? = nil,
        entryDate: Date,
        status: HabitEntryStatus,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil,
        habit: Habit? = nil
    ) {
        self.id = id
        self.userId = userId
        self.entryDate = entryDate
        self.statusRawValue = status.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.habit = habit
    }

    var status: HabitEntryStatus {
        get { HabitEntryStatus(rawValue: statusRawValue) ?? .skipped }
        set {
            statusRawValue = newValue.rawValue
            updatedAt = Date()
        }
    }

    func touch() {
        updatedAt = Date()
    }

    func markDeleted(at date: Date = Date()) {
        deletedAt = date
        updatedAt = date
    }
}

extension Color {
    init(hex: String) {
        let value = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: value).scanHexInt64(&int)

        let red = Double((int >> 16) & 0xFF) / 255.0
        let green = Double((int >> 8) & 0xFF) / 255.0
        let blue = Double(int & 0xFF) / 255.0

        self.init(red: red, green: green, blue: blue)
    }
}
