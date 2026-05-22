import SwiftData
import SwiftUI

@main
struct HabitTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [
            Challenge.self,
            Habit.self,
            HabitEntry.self
        ])
    }
}
