import SwiftData
import SwiftUI

@main
struct HabitTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [
            AppUser.self,
            Challenge.self,
            Habit.self,
            HabitEntry.self
        ])
    }
}
