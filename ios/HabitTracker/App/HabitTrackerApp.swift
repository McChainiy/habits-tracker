import SwiftData
import SwiftUI

@main
struct HabitTrackerApp: App {
    init() {
        HabitNotificationScheduler.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [
            AppUser.self,
            SyncState.self,
            Challenge.self,
            Habit.self,
            HabitEntry.self
        ])
    }
}
