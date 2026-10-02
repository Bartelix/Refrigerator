import SwiftUI
import SwiftData

@main
struct RefrigeratorApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([FoodItem.self, CustomFoodCategory.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create the ModelContainer: \(error)")
        }
    }()

    /// App-wide undo stack, so both tabs share the same history of actions.
    @State private var undoActions = UndoActionManager()

    /// App-wide preferences, currently just the interface language.
    @State private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(undoActions)
                .environment(settings)
        }
        .modelContainer(sharedModelContainer)
    }
}
