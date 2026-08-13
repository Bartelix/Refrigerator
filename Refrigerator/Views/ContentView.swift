import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Query private var allItems: [FoodItem]

    var body: some View {
        TabView {
            FoodListView(location: .fridge)
                .tabItem {
                    Label(StorageLocation.fridge.rawValue, systemImage: StorageLocation.fridge.systemImage)
                }

            FoodListView(location: .freezer)
                .tabItem {
                    Label(StorageLocation.freezer.rawValue, systemImage: StorageLocation.freezer.systemImage)
                }
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
}
