import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \AppUser.createdAt)
    private var users: [AppUser]

    @Query(sort: \Challenge.createdAt, order: .reverse)
    private var challenges: [Challenge]

    private var currentChallenge: Challenge? {
        challenges.first { $0.status == .active } ?? challenges.first
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
        }
    }

    private func ensureLocalUser() {
        guard users.isEmpty else { return }
        modelContext.insert(AppUser())
        try? modelContext.save()
    }
}
