import Foundation
import SwiftData

enum SyncClientError: Error {
    case invalidResponse
    case requestFailed(Int, String)
}

@MainActor
struct SyncClient {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL = AppConfig.apiBaseURL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func sync(
        user: AppUser,
        state: SyncState,
        challenges: [Challenge],
        modelContext: ModelContext
    ) async throws {
        normalizeOwnership(user: user, challenges: challenges)
        try await ensureRemoteUser(user)

        let pushPayload = makePushPayload(
            user: user,
            challenges: challenges,
            changedAfter: state.lastPushedAt
        )

        if pushPayload.hasChanges {
            let pushedChanges = try await pushChanges(pushPayload, userID: user.id)
            apply(changes: pushedChanges, user: user, challenges: challenges, modelContext: modelContext)
            state.markSuccess(pushedAt: pushedChanges.serverTimestamp)
        }

        let pulledChanges = try await pullChanges(since: state.lastPulledAt, userID: user.id)
        apply(changes: pulledChanges, user: user, challenges: challenges, modelContext: modelContext)
        state.markSuccess(pulledAt: pulledChanges.serverTimestamp)
    }

    private func ensureRemoteUser(_ user: AppUser) async throws {
        let payload = UserCreatePayload(
            id: user.id,
            email: user.email,
            displayName: user.displayName
        )

        var request = URLRequest(url: url(path: "/api/v1/users"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try SyncCoding.encoder.encode(payload)

        _ = try await send(request, expecting: UserPayload.self)
    }

    private func pushChanges(_ payload: SyncPushPayload, userID: UUID) async throws -> SyncChangesPayload {
        var request = URLRequest(url: url(path: "/api/v1/sync/push"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(userID.uuidString, forHTTPHeaderField: "X-User-Id")
        request.httpBody = try SyncCoding.encoder.encode(payload)

        return try await send(request, expecting: SyncChangesPayload.self)
    }

    private func pullChanges(since: Date?, userID: UUID) async throws -> SyncChangesPayload {
        var components = URLComponents(
            url: url(path: "/api/v1/sync/changes"),
            resolvingAgainstBaseURL: false
        )
        if let since {
            components?.queryItems = [
                URLQueryItem(name: "since", value: SyncCoding.isoString(from: since))
            ]
        }

        guard let url = components?.url else {
            throw SyncClientError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.setValue(userID.uuidString, forHTTPHeaderField: "X-User-Id")
        return try await send(request, expecting: SyncChangesPayload.self)
    }

    private func url(path: String) -> URL {
        URL(string: path, relativeTo: baseURL)!.absoluteURL
    }

    private func send<T: Decodable>(_ request: URLRequest, expecting type: T.Type) async throws -> T {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SyncClientError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw SyncClientError.requestFailed(httpResponse.statusCode, body)
        }

        return try SyncCoding.decoder.decode(type, from: data)
    }

    private func normalizeOwnership(user: AppUser, challenges: [Challenge]) {
        for challenge in challenges where challenge.user == nil {
            challenge.user = user
            challenge.touch()
        }

        for habit in challenges.flatMap(\.habits) where habit.userId == nil {
            habit.userId = user.id
            habit.touch()
        }

        for entry in challenges.flatMap(\.habits).flatMap(\.entries) where entry.userId == nil {
            entry.userId = user.id
            entry.touch()
        }
    }

    private func makePushPayload(
        user: AppUser,
        challenges: [Challenge],
        changedAfter: Date?
    ) -> SyncPushPayload {
        let ownedChallenges = challenges.filter { $0.user?.id == user.id }
        let ownedHabits = ownedChallenges.flatMap(\.habits).filter { $0.userId == user.id }
        let ownedEntries = ownedHabits.flatMap(\.entries).filter { $0.userId == user.id }

        return SyncPushPayload(
            challenges: ownedChallenges
                .filter { wasChanged($0.updatedAt, after: changedAfter) }
                .map(SyncChallengePayload.init),
            habits: ownedHabits
                .filter { wasChanged($0.updatedAt, after: changedAfter) }
                .compactMap(SyncHabitPayload.init),
            habitEntries: ownedEntries
                .filter { wasChanged($0.updatedAt, after: changedAfter) }
                .compactMap(SyncHabitEntryPayload.init)
        )
    }

    private func wasChanged(_ updatedAt: Date, after timestamp: Date?) -> Bool {
        guard let timestamp else { return true }
        return updatedAt > timestamp
    }

    private func apply(
        changes: SyncChangesPayload,
        user: AppUser,
        challenges: [Challenge],
        modelContext: ModelContext
    ) {
        var challengeByID = Dictionary(uniqueKeysWithValues: challenges.map { ($0.id, $0) })
        var habitByID = Dictionary(uniqueKeysWithValues: challenges.flatMap(\.habits).map { ($0.id, $0) })
        var entryByID = Dictionary(
            uniqueKeysWithValues: challenges.flatMap(\.habits).flatMap(\.entries).map { ($0.id, $0) }
        )

        for payload in changes.challenges {
            let challenge = challengeByID[payload.id] ?? Challenge(
                id: payload.id,
                month: payload.month,
                year: payload.year,
                startDate: SyncCoding.date(from: payload.startDate),
                endDate: SyncCoding.date(from: payload.endDate),
                status: ChallengeStatus(rawValue: payload.status) ?? .draft,
                user: user
            )

            challenge.month = payload.month
            challenge.year = payload.year
            challenge.startDate = SyncCoding.date(from: payload.startDate)
            challenge.endDate = SyncCoding.date(from: payload.endDate)
            challenge.statusRawValue = payload.status
            challenge.createdAt = payload.createdAt
            challenge.updatedAt = payload.updatedAt
            challenge.deletedAt = payload.deletedAt
            challenge.user = user

            if challengeByID[payload.id] == nil {
                modelContext.insert(challenge)
                challengeByID[payload.id] = challenge
            }
        }

        for payload in changes.habits {
            guard let challenge = challengeByID[payload.challengeID] else { continue }

            let habit = habitByID[payload.id] ?? Habit(
                id: payload.id,
                userId: user.id,
                title: payload.title,
                penaltyText: payload.penaltyText,
                colorHex: payload.colorHex,
                sortOrder: payload.sortOrder,
                challenge: challenge
            )

            habit.userId = user.id
            habit.title = payload.title
            habit.note = payload.note
            habit.penaltyText = payload.penaltyText
            habit.colorHex = payload.colorHex
            habit.sortOrder = payload.sortOrder
            habit.isArchived = payload.isArchived
            habit.createdAt = payload.createdAt
            habit.updatedAt = payload.updatedAt
            habit.deletedAt = payload.deletedAt
            habit.challenge = challenge

            if habitByID[payload.id] == nil {
                challenge.habits.append(habit)
                modelContext.insert(habit)
                habitByID[payload.id] = habit
            }
        }

        for payload in changes.habitEntries {
            guard let habit = habitByID[payload.habitID] else { continue }

            let entry = entryByID[payload.id] ?? HabitEntry(
                id: payload.id,
                userId: user.id,
                entryDate: SyncCoding.date(from: payload.entryDate),
                status: HabitEntryStatus(rawValue: payload.status) ?? .skipped,
                habit: habit
            )

            entry.userId = user.id
            entry.entryDate = SyncCoding.date(from: payload.entryDate)
            entry.statusRawValue = payload.status
            entry.createdAt = payload.createdAt
            entry.updatedAt = payload.updatedAt
            entry.deletedAt = payload.deletedAt
            entry.habit = habit

            if entryByID[payload.id] == nil {
                habit.entries.append(entry)
                modelContext.insert(entry)
                entryByID[payload.id] = entry
            }
        }
    }
}

private enum SyncCoding {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(isoString(from: date))
        }
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            return try dateTime(from: value)
        }
        return decoder
    }()

    private static let isoFormatterWithFractions: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func isoString(from date: Date) -> String {
        isoFormatterWithFractions.string(from: date)
    }

    static func dateString(from date: Date) -> String {
        dateFormatter.string(from: date)
    }

    static func date(from value: String) -> Date {
        dateFormatter.date(from: value) ?? Date()
    }

    private static func dateTime(from value: String) throws -> Date {
        if let date = isoFormatterWithFractions.date(from: value) ?? isoFormatter.date(from: value) {
            return date
        }
        throw DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: [], debugDescription: "Invalid date: \(value)")
        )
    }
}

private struct UserCreatePayload: Encodable {
    let id: UUID
    let email: String?
    let displayName: String
}

private struct UserPayload: Decodable {
    let id: UUID
}

private struct SyncPushPayload: Encodable {
    let challenges: [SyncChallengePayload]
    let habits: [SyncHabitPayload]
    let habitEntries: [SyncHabitEntryPayload]

    var hasChanges: Bool {
        !challenges.isEmpty || !habits.isEmpty || !habitEntries.isEmpty
    }
}

private struct SyncChangesPayload: Decodable {
    let serverTimestamp: Date
    let challenges: [SyncChallengePayload]
    let habits: [SyncHabitPayload]
    let habitEntries: [SyncHabitEntryPayload]
}

private struct SyncChallengePayload: Codable {
    let id: UUID
    let month: Int
    let year: Int
    let startDate: String
    let endDate: String
    let status: String
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?

    init(_ challenge: Challenge) {
        id = challenge.id
        month = challenge.month
        year = challenge.year
        startDate = SyncCoding.dateString(from: challenge.startDate)
        endDate = SyncCoding.dateString(from: challenge.endDate)
        status = challenge.statusRawValue
        createdAt = challenge.createdAt
        updatedAt = challenge.updatedAt
        deletedAt = challenge.deletedAt
    }
}

private struct SyncHabitPayload: Codable {
    let id: UUID
    let challengeID: UUID
    let title: String
    let note: String
    let penaltyText: String
    let colorHex: String
    let sortOrder: Int
    let isArchived: Bool
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?

    init?(_ habit: Habit) {
        guard let challengeID = habit.challenge?.id else { return nil }
        id = habit.id
        self.challengeID = challengeID
        title = habit.title
        note = habit.note
        penaltyText = habit.penaltyText
        colorHex = habit.colorHex
        sortOrder = habit.sortOrder
        isArchived = habit.isArchived
        createdAt = habit.createdAt
        updatedAt = habit.updatedAt
        deletedAt = habit.deletedAt
    }
}

private struct SyncHabitEntryPayload: Codable {
    let id: UUID
    let habitID: UUID
    let entryDate: String
    let status: String
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?

    init?(_ entry: HabitEntry) {
        guard let habitID = entry.habit?.id else { return nil }
        id = entry.id
        self.habitID = habitID
        entryDate = SyncCoding.dateString(from: entry.entryDate)
        status = entry.statusRawValue
        createdAt = entry.createdAt
        updatedAt = entry.updatedAt
        deletedAt = entry.deletedAt
    }
}
