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

    private var currentChallenge: Challenge? {
        challenges.first { $0.status == .active && $0.deletedAt == nil } ??
        challenges.first { $0.deletedAt == nil }
    }

    var body: some View {
        NavigationStack {
            if let currentChallenge {
                MonthDashboardView(challenge: currentChallenge)
            } else {
                SetupChallengeView()
            }
        }
        .tint(AppPalette.ink)
        .onAppear {
            ensureLocalUser()
            ensureSyncState()
        }
        .task {
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
                modelContext: modelContext
            )
            try? modelContext.save()
        } catch {
            state.markFailure(error)
            try? modelContext.save()
        }
    }
}
