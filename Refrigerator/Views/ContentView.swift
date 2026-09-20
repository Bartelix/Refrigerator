import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Query private var allItems: [FoodItem]
    @State private var selectedTab: StorageLocation = .freezer

    var body: some View {
        TabView(selection: $selectedTab) {
            FoodListView(location: .fridge)
                .tabItem {
                    Label(StorageLocation.fridge.rawValue, systemImage: StorageLocation.fridge.systemImage)
                }
                .tag(StorageLocation.fridge)

            FoodListView(location: .freezer)
                .tabItem {
                    Label(StorageLocation.freezer.rawValue, systemImage: StorageLocation.freezer.systemImage)
                }
                .tag(StorageLocation.freezer)
        }
        .onAppear {
            NotificationManager.shared.requestAuthorizationIfNeeded()
            NotificationManager.shared.rescheduleAll(items: allItems)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                NotificationManager.shared.rescheduleAll(items: allItems)
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(UndoActionManager())
}
