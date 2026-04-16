import SwiftUI
import SwiftData

@main
struct IntuukApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .modelContainer(for: FoodEntry.self)
    }
}
