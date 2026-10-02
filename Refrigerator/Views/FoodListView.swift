import SwiftUI
import SwiftData

enum SortOption: String, CaseIterable, Identifiable {
    case expiryFarthest
    case expiryNearest
    case dateNewestFirst
    case dateOldestFirst
    case nameAZ
    case nameZA

    var id: String { rawValue }

    var displayName: LocalizedStringKey {
        switch self {
        case .expiryFarthest: "Expiry date (farthest)"
        case .expiryNearest: "Expiry date (nearest)"
        case .dateNewestFirst: "Date (newest)"
        case .dateOldestFirst: "Date (oldest)"
        case .nameAZ: "Name (A-Z)"
        case .nameZA: "Name (Z-A)"
        }
    }
}

struct FoodListView: View {
    let location: StorageLocation

    @Environment(\.modelContext) private var modelContext
    @Environment(UndoActionManager.self) private var undoActions
    @Environment(AppSettings.self) private var settings
    @Query private var allItems: [FoodItem]

    @State private var undoneAction: UndoActionSummary?
    @State private var searchText = ""
    @State private var sortOption: SortOption = .expiryNearest
    @State private var showingAddSheet = false
    @State private var itemToEdit: FoodItem?
    @State private var itemToMove: FoodItem?
    @State private var categoryFilter: FoodCategory?

    init(location: StorageLocation) {
        self.location = location
        _allItems = Query(sort: \FoodItem.dateAdded, order: .reverse)
    }

    /// While searching, results span both the fridge and the freezer instead of
    /// just this tab's location, so matching items are never hidden by the tab.
    private var isSearching: Bool { !searchText.isEmpty }

    private var filteredAndSorted: [FoodItem] {
        var items = isSearching ? allItems : allItems.filter { $0.location == location }

        if isSearching {
            items = items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        if let categoryFilter {
            items = items.filter { $0.category == categoryFilter }
        }

        switch sortOption {
        case .expiryNearest:
            items.sort {
                switch ($0.expiryDate, $1.expiryDate) {
                case let (lhs?, rhs?): return lhs < rhs
                case (_?, nil):        return true
                case (nil, _?):        return false
                case (nil, nil):       return $0.dateAdded < $1.dateAdded
                }
            }
        case .expiryFarthest:
            items.sort {
                switch ($0.expiryDate, $1.expiryDate) {
                case let (lhs?, rhs?): return lhs > rhs
                case (_?, nil):        return true
                case (nil, _?):        return false
                case (nil, nil):       return $0.dateAdded > $1.dateAdded
                }
            }
        case .dateNewestFirst:
            items.sort { $0.dateAdded > $1.dateAdded }
        case .dateOldestFirst:
            items.sort { $0.dateAdded < $1.dateAdded }
        case .nameAZ:
            items.sort { $0.name.localizedCompare($1.name) == .orderedAscending }
        case .nameZA:
            items.sort { $0.name.localizedCompare($1.name) == .orderedDescending }
        }

        return items
    }

    /// Summary in the list header. Built by joining `Text` pieces rather than plain
    /// strings, so each part is localized and pluralized on its own.
    private var summaryText: Text {
        let items = filteredAndSorted
        let count = items.count
        // An item's weight refers to a single piece, so the total is weight × quantity.
        let totalQuantity = items.reduce(0) { $0 + ($1.quantity ?? 1) }
        let totalWeight = items.reduce(0.0) { partial, item in
            guard let weight = item.weightInGrams else { return partial }
            return partial + weight * Double(item.quantity ?? 1)
        }

        let countText = Text("\(count) items")
        let quantityText = totalQuantity != count ? Text(" • \(totalQuantity) pcs.") : Text(verbatim: "")
        let weightText = totalWeight > 0 ? Text(" • \(formattedWeight(totalWeight)) in total") : Text(verbatim: "")
        return Text("\(countText)\(quantityText)\(weightText)")
    }

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            List {
                if filteredAndSorted.isEmpty {
                    ContentUnavailableView(
                        "No items",
                        systemImage: location.systemImage,
                        description: Text("Add something by tapping +")
                    )
                } else {
                    Section {
                        ForEach(filteredAndSorted) { item in
                            FoodRowView(item: item, showsLocation: isSearching)
                                .contentShape(Rectangle())
                                .onTapGesture { itemToEdit = item }
                                .swipeActions(edge: .leading) {
                                    Button {
                                        itemToMove = item
                                    } label: {
                                        Label("Move", systemImage: "arrow.left.arrow.right")
                                    }
                                    .tint(.blue)
                                }
                        }
                        .onDelete(perform: deleteItems)
                    } header: {
                        summaryText
                    }
                }
            }
            .overlay(alignment: .bottom) { undoToast }
            .navigationTitle(location.displayName)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: Text("Search by name")
            )
            .toolbar {
                if let action = undoActions.lastAction {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: performUndo) {
                            // An explicit stack — a Label is collapsed to icon-only by the
                            // toolbar. Only the kind of action fits next to the icon; the
                            // full description (with the name) goes to VoiceOver.
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.uturn.backward")
                                Text(action.shortLabel)
                            }
                        }
                        .accessibilityLabel(action.undoLabel)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Picker("Sort", selection: $sortOption) {
                            ForEach(SortOption.allCases) { option in
                                Text(option.displayName).tag(option)
                            }
                        }
                        Divider()
                        Picker("Category", selection: $categoryFilter) {
                            Text("All categories").tag(FoodCategory?.none)
                            ForEach(FoodCategory.allCases) { cat in
                                Text(cat.displayName).tag(FoodCategory?.some(cat))
                            }
                        }
                        Divider()
                        Picker("Language", selection: $settings.language) {
                            Text("System").tag(AppLanguage.system)
                            // Language names stay in their own language, so they are
                            // recognizable whichever language the app is currently in.
                            Text(verbatim: "Polski").tag(AppLanguage.polish)
                            Text(verbatim: "English").tag(AppLanguage.english)
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddEditFoodItemView(location: location)
            }
            .sheet(item: $itemToEdit) { item in
                AddEditFoodItemView(location: item.location, itemToEdit: item)
            }
            .sheet(item: $itemToMove) { item in
                MoveFoodItemView(item: item)
            }
        }
    }

    /// Short confirmation of the undo — disappears on its own after a moment.
    @ViewBuilder
    private var undoToast: some View {
        if let undoneAction {
            undoneAction.undidLabel
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: Capsule())
                .shadow(radius: 4, y: 2)
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task(id: undoneAction) {
                    try? await Task.sleep(for: .seconds(2.5))
                    withAnimation { self.undoneAction = nil }
                }
        }
    }

    private func performUndo() {
        guard let action = undoActions.undoLast(in: modelContext) else { return }
        withAnimation { undoneAction = action }
    }

    private func deleteItems(at offsets: IndexSet) {
        // Read the list once — it is recomputed on every access, so indexes
        // would shift while deleting more than one item.
        let visible = filteredAndSorted
        let items = offsets.map { visible[$0] }

        undoActions.recordDelete(items)
        for item in items {
            NotificationManager.shared.cancelAllNotifications(for: item)
            modelContext.delete(item)
        }
    }
}

func formattedWeight(_ grams: Double) -> String {
    if grams >= 1000 {
        return String(format: "%.2f kg", grams / 1000)
    }
    return String(format: "%.0f g", grams)
}

#Preview {
    FoodListView(location: .freezer)
        .modelContainer(for: FoodItem.self, inMemory: true)
        .environment(UndoActionManager())
        .environment(AppSettings())
}
