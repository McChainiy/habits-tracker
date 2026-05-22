import SwiftData
import SwiftUI

struct RootView: View {
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
    }
}
