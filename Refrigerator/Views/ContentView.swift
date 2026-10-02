import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppSettings.self) private var settings
    @Query private var allItems: [FoodItem]
    @State private var selectedTab: StorageLocation = .freezer

    var body: some View {
        TabView(selection: $selectedTab) {
            // One tab per storage location, in declaration order.
            ForEach(StorageLocation.allCases) { location in
                FoodListView(location: location)
                    .tabItem {
                        Label(location.displayName, systemImage: location.systemImage)
                    }
                    .tag(location)
            }
        }
        // Overriding the locale is what switches the language of every view below,
        // including the sheets they present.
        .environment(\.locale, settings.locale)
        .onAppear {
            NotificationManager.shared.requestAuthorizationIfNeeded()
            refreshNotifications()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                refreshNotifications()
            }
        }
        .onChange(of: settings.language) {
            refreshNotifications()
        }
    }

    /// Reschedules every notification so that its text is written in the selected
    /// language — the text is fixed at the moment a notification is scheduled.
    private func refreshNotifications() {
        NotificationManager.shared.locale = settings.locale
        NotificationManager.shared.rescheduleAll(items: allItems)
    }
}

#Preview {
    ContentView()
        .environment(UndoActionManager())
        .environment(AppSettings())
}
