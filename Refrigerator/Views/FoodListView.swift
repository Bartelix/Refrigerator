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
    @Environment(UndoActionManager.self) private var undoActions
    @Query private var allItems: [FoodItem]

    @State private var undoMessage: String?
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
        let items = filteredAndSorted
        let count = items.count
        // An item's weight refers to a single piece, so the total is weight × quantity.
        let totalQuantity = items.reduce(0) { $0 + ($1.quantity ?? 1) }
        let totalWeight = items.reduce(0.0) { partial, item in
            guard let weight = item.weightInGrams else { return partial }
            return partial + weight * Double(item.quantity ?? 1)
        }

        var parts = ["\(count) poz."]
        if totalQuantity != count {
            parts.append("\(totalQuantity) szt.")
        }
        if totalWeight > 0 {
            parts.append("łącznie \(formattedWeight(totalWeight))")
        }
        return parts.joined(separator: " • ")
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
            .overlay(alignment: .bottom) { undoToast }
            .navigationTitle(location.rawValue)
            .searchable(text: $searchText, prompt: "Szukaj po nazwie")
            .toolbar {
                if let kind = undoActions.lastActionKind {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: performUndo) {
                            // An explicit stack — a Label is collapsed to icon-only by the
                            // toolbar. Only the kind of action fits next to the icon; the
                            // full description (with the name) goes to VoiceOver.
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.uturn.backward")
                                Text(kind.phrase)
                            }
                        }
                        .accessibilityLabel("Cofnij \(undoActions.lastActionDescription ?? kind.phrase)")
                    }
                }
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

    /// Krótkie potwierdzenie cofnięcia — znika samo po chwili.
    @ViewBuilder
    private var undoToast: some View {
        if let undoMessage {
            Text(undoMessage)
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: Capsule())
                .shadow(radius: 4, y: 2)
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task(id: undoMessage) {
                    try? await Task.sleep(for: .seconds(2.5))
                    withAnimation { self.undoMessage = nil }
                }
        }
    }

    private func performUndo() {
        guard let description = undoActions.undoLast(in: modelContext) else { return }
        withAnimation { undoMessage = "Cofnięto \(description)" }
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
}
