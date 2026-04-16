import SwiftUI
import SwiftData

@main
struct TimeMeApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .modelContainer(for: FoodEntry.self)
    }
}
