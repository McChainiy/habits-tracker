import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \AppUser.createdAt)
    private var users: [AppUser]

    @Query(sort: \SyncState.updatedAt)
    private var syncStates: [SyncState]

    @Query(sort: \Challenge.createdAt, order: .reverse)
    private var challenges: [Challenge]

    @Query(sort: \Habit.createdAt)
    private var habits: [Habit]

    private var activeChallenges: [Challenge] {
        let visibleChallenges = challenges.filter { $0.deletedAt == nil }
        let active = visibleChallenges.filter { $0.status == .active }
        return active.isEmpty ? visibleChallenges : active
    }

    var body: some View {
        NavigationStack {
            if activeChallenges.isEmpty {
                SetupChallengeView()
            } else {
                WeeklyDashboardView(challenges: activeChallenges)
            }
        }
        .tint(AppPalette.ink)
        .onAppear {
            ensureLocalUser()
            ensureSyncState()
        }
        .task {
            await scheduleExistingHabitNotifications()
            await runSyncLoop()
        }
    }

    private func ensureLocalUser() {
        guard users.isEmpty else { return }
        modelContext.insert(AppUser())
        try? modelContext.save()
    }

    @discardableResult
    private func ensureSyncState() -> SyncState {
        if let state = syncStates.first {
            return state
        }
        let state = SyncState()
        modelContext.insert(state)
        try? modelContext.save()
        return state
    }

    @MainActor
    private func runSyncLoop() async {
        while !Task.isCancelled {
            await syncOnce()
            try? await Task.sleep(for: .seconds(10))
        }
    }

    @MainActor
    private func syncOnce() async {
        guard let user = users.first else { return }
        let state = ensureSyncState()

        do {
            try await SyncClient().sync(
                user: user,
                state: state,
                challenges: challenges,
                habits: habits,
                modelContext: modelContext
            )
            try? modelContext.save()
        } catch {
            state.markFailure(error)
            try? modelContext.save()
        }
    }

    @MainActor
    private func scheduleExistingHabitNotifications() async {
        let plans = habits
            .filter { !$0.isArchived && $0.deletedAt == nil }
            .map(HabitNotificationScheduler.plan(for:))

        for plan in plans {
            await HabitNotificationScheduler.shared.scheduleNotifications(for: plan)
        }
    }
}
