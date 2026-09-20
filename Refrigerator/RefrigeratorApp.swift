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

    /// App-wide undo stack, so both tabs share the same history of actions.
    @State private var undoActions = UndoActionManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(undoActions)
        }
        .modelContainer(sharedModelContainer)
    }
}
