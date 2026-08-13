import SwiftUI
import SwiftData

@main
struct RefrigeratorApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([FoodItem.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Nie udało się utworzyć ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
