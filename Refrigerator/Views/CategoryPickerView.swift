import SwiftUI
import SwiftData

/// Lookup for picking a category.
///
/// There are far more categories than fit a plain `Picker` — all the built-in ones plus
/// however many the user has added — so this is a searchable list of its own. It is
/// also where custom categories are created: typing a name that matches nothing offers
/// to add it, which saves having a separate field for it.
struct CategoryPickerView: View {
    /// The picked category. `nil` stands for "every category" and is only reachable
    /// when `allowsAll` is set.
    @Binding var selection: CategorySelection?
    /// Whether the list offers an entry for "no category picked".
    var allowsAll: Bool = false
    /// Whether an unknown name can be added as a new category. Off while filtering a
    /// list, where creating a category nothing is filed under would be pointless.
    var allowsCreating: Bool = true

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    @Query(sort: \CustomFoodCategory.name) private var storedCategories: [CustomFoodCategory]
    @Query private var allItems: [FoodItem]

    @State private var searchText = ""

    private var query: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Form used for matching, with case and accents folded away, so that typing
    /// "maka" finds "Mąka" and "tluszcz" finds "Oleje i tłuszcze".
    ///
    /// "ł" has to be folded by hand: in Unicode it is a letter in its own right rather
    /// than an "l" carrying a diacritic, so diacritic-insensitive folding leaves it be.
    private func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: locale)
            .replacingOccurrences(of: "ł", with: "l")
    }

    private func matchesQuery(_ name: String) -> Bool {
        guard !query.isEmpty else { return true }
        return normalized(name).contains(normalized(query))
    }

    /// Names of the user's own categories: the ones they added, plus any name still
    /// carried by an item — so a category in use is never missing from the list.
    private var customNames: [String] {
        let stored = storedCategories.map(\.name)
        let inUse = allItems.compactMap(\.customCategoryName).filter { !$0.isEmpty }
        return Set(stored + inUse).sorted { $0.localizedCompare($1) == .orderedAscending }
    }

    private var matchingCustomNames: [String] {
        customNames.filter(matchesQuery)
    }

    private var matchingBuiltIns: [FoodCategory] {
        FoodCategory.displayOrder.filter { matchesQuery($0.resolvedName(in: locale)) }
    }

    /// The typed name, when it can be added as a new category — i.e. it is not blank
    /// and no existing category already goes by it.
    private var nameToCreate: String? {
        guard allowsCreating, !query.isEmpty else { return nil }
        let taken = customNames + FoodCategory.displayOrder.map { $0.resolvedName(in: locale) }
        guard !taken.contains(where: { $0.localizedCaseInsensitiveCompare(query) == .orderedSame })
        else { return nil }
        return query
    }

    private var hasResults: Bool {
        !matchingCustomNames.isEmpty || !matchingBuiltIns.isEmpty || nameToCreate != nil
    }

    var body: some View {
        List {
            if allowsAll, query.isEmpty {
                Section {
                    row(for: nil) { Text("All categories") }
                }
            }

            if let nameToCreate {
                Section {
                    Button {
                        create(nameToCreate)
                    } label: {
                        Label {
                            Text("Add “\(nameToCreate)”")
                        } icon: {
                            Image(systemName: "plus.circle.fill")
                        }
                    }
                }
            }

            if !matchingCustomNames.isEmpty {
                Section("Your categories") {
                    ForEach(matchingCustomNames, id: \.self) { name in
                        row(for: .custom(name)) { Text(verbatim: name) }
                            .swipeActions {
                                // A category some item is filed under stays put —
                                // removing it would leave that item pointing at
                                // something no longer on the list.
                                if !isInUse(name) {
                                    Button("Delete", role: .destructive) { delete(name) }
                                }
                            }
                    }
                }
            }

            if !matchingBuiltIns.isEmpty {
                Section("Built-in categories") {
                    ForEach(matchingBuiltIns) { category in
                        row(for: .builtIn(category)) {
                            Text(verbatim: category.resolvedName(in: locale))
                        }
                    }
                }
            }
        }
        .navigationTitle("Category")
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: Text("Search categories")
        )
        .overlay {
            if !hasResults {
                ContentUnavailableView.search(text: query)
            }
        }
    }

    /// A row that picks `value` and shows a checkmark while it is the current pick.
    private func row<Label: View>(
        for value: CategorySelection?,
        @ViewBuilder label: () -> Label
    ) -> some View {
        Button {
            selection = value
            dismiss()
        } label: {
            HStack {
                label()
                Spacer()
                if selection == value {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
        }
        .foregroundStyle(.primary)
    }

    private func isInUse(_ name: String) -> Bool {
        allItems.contains { $0.customCategoryName == name }
    }

    private func create(_ name: String) {
        modelContext.insert(CustomFoodCategory(name: name))
        selection = .custom(name)
        dismiss()
    }

    private func delete(_ name: String) {
        for category in storedCategories where category.name == name {
            modelContext.delete(category)
        }
        if selection == .custom(name) {
            selection = allowsAll ? nil : .builtIn(.other)
        }
    }
}

#Preview {
    @Previewable @State var selection: CategorySelection? = .builtIn(.other)

    NavigationStack {
        CategoryPickerView(selection: $selection)
    }
    .modelContainer(for: [FoodItem.self, CustomFoodCategory.self], inMemory: true)
}
