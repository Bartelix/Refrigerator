import SwiftUI
import SwiftData

enum SortOption: String, CaseIterable, Identifiable {
    case expiryFarthest = "Termin ważności (najdalszy)"
    case expiryNearest = "Termin ważności (najbliższy)"
    case dateNewestFirst = "Data (najnowsze)"
    case dateOldestFirst = "Data (najstarsze)"
    case nameAZ = "Nazwa (A-Z)"
    case nameZA = "Nazwa (Z-A)"

    var id: String { rawValue }
}

struct FoodListView: View {
    let location: StorageLocation

    @Environment(\.modelContext) private var modelContext
    @Query private var allItems: [FoodItem]

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

    private var filteredAndSorted: [FoodItem] {
        var items = allItems.filter { $0.location == location }

        if !searchText.isEmpty {
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

    private var summaryText: String {
        let count = filteredAndSorted.count
        let totalWeight = filteredAndSorted.compactMap(\.weightInGrams).reduce(0, +)
        if totalWeight > 0 {
            return "\(count) poz. • łącznie \(formattedWeight(totalWeight))"
        }
        return "\(count) poz."
    }

    var body: some View {
        NavigationStack {
            List {
                if filteredAndSorted.isEmpty {
                    ContentUnavailableView(
                        "Brak produktów",
                        systemImage: location.systemImage,
                        description: Text("Dodaj coś, stukając w +")
                    )
                } else {
                    Section {
                        ForEach(filteredAndSorted) { item in
                            FoodRowView(item: item)
                                .contentShape(Rectangle())
                                .onTapGesture { itemToEdit = item }
                                .swipeActions(edge: .leading) {
                                    Button {
                                        itemToMove = item
                                    } label: {
                                        Label(
                                            "Przenieś do: \(item.location.opposite.rawValue)",
                                            systemImage: item.location.opposite.systemImage
                                        )
                                    }
                                    .tint(.blue)
                                }
                        }
                        .onDelete(perform: deleteItems)
                    } header: {
                        Text(summaryText)
                    }
                }
            }
            .navigationTitle(location.rawValue)
            .searchable(text: $searchText, prompt: "Szukaj po nazwie")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Picker("Sortuj", selection: $sortOption) {
                            ForEach(SortOption.allCases) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        Divider()
                        Picker("Kategoria", selection: $categoryFilter) {
                            Text("Wszystkie kategorie").tag(FoodCategory?.none)
                            ForEach(FoodCategory.allCases) { cat in
                                Text(cat.rawValue).tag(FoodCategory?.some(cat))
                            }
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
                AddEditFoodItemView(location: location, itemToEdit: item)
            }
            .sheet(item: $itemToMove) { item in
                MoveFoodItemView(item: item)
            }
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            let item = filteredAndSorted[index]
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
}
