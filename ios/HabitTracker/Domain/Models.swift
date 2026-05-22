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

enum HabitColor: String, CaseIterable, Identifiable {
    case sage = "#62766A"
    case clay = "#9B6B5F"
    case stone = "#8B8C83"
    case ink = "#60717A"
    case moss = "#75815A"

    var id: String { rawValue }
}

@Model
final class Challenge {
    @Attribute(.unique) var id: UUID
    var month: Int
    var year: Int
    var startDate: Date
    var endDate: Date
    var statusRawValue: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Habit.challenge)
    var habits: [Habit] = []

    init(
        id: UUID = UUID(),
        month: Int,
        year: Int,
        startDate: Date,
        endDate: Date,
        status: ChallengeStatus = .active,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.month = month
        self.year = year
        self.startDate = startDate
        self.endDate = endDate
        self.statusRawValue = status.rawValue
        self.createdAt = createdAt
    }

    var status: ChallengeStatus {
        get { ChallengeStatus(rawValue: statusRawValue) ?? .draft }
        set { statusRawValue = newValue.rawValue }
    }

    var title: String {
        let components = DateComponents(year: year, month: month, day: 1)
        guard let date = Calendar.current.date(from: components) else {
            return "\(month).\(year)"
        }
        return date.formatted(.dateTime.month(.wide).year())
    }
}

@Model
final class Habit {
    @Attribute(.unique) var id: UUID
    var title: String
    var note: String
    var penaltyText: String
    var colorHex: String
    var sortOrder: Int
    var isArchived: Bool
    var createdAt: Date

    var challenge: Challenge?

    @Relationship(deleteRule: .cascade, inverse: \HabitEntry.habit)
    var entries: [HabitEntry] = []

    init(
        id: UUID = UUID(),
        title: String,
        note: String = "",
        penaltyText: String,
        colorHex: String,
        sortOrder: Int,
        isArchived: Bool = false,
        createdAt: Date = Date(),
        challenge: Challenge? = nil
    ) {
        self.id = id
        self.title = title
        self.note = note
        self.penaltyText = penaltyText
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.challenge = challenge
    }
}

@Model
final class HabitEntry {
    @Attribute(.unique) var id: UUID
    var entryDate: Date
    var statusRawValue: String
    var createdAt: Date
    var updatedAt: Date

    var habit: Habit?

    init(
        id: UUID = UUID(),
        entryDate: Date,
        status: HabitEntryStatus,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        habit: Habit? = nil
    ) {
        self.id = id
        self.entryDate = entryDate
        self.statusRawValue = status.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.habit = habit
    }

    var status: HabitEntryStatus {
        get { HabitEntryStatus(rawValue: statusRawValue) ?? .skipped }
        set {
            statusRawValue = newValue.rawValue
            updatedAt = Date()
        }
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
