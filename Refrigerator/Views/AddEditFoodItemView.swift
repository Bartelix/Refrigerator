import SwiftUI
import SwiftData

struct AddEditFoodItemView: View {
    let location: StorageLocation
    var itemToEdit: FoodItem?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(UndoActionManager.self) private var undoActions

    @State private var name: String = ""
    @State private var category: FoodCategory = .other
    @State private var weightText: String = ""
    @State private var quantityText: String = ""
    @State private var dateAdded: Date = .now
    @State private var hasExpiryDate: Bool = false
    @State private var expiryDate: Date = .now.addingTimeInterval(60 * 60 * 24 * 7)
    @State private var notes: String = ""
    @State private var showingMoveSheet = false

    private var isEditing: Bool { itemToEdit != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Basic information") {
                    TextField("Name (e.g. Beef steak)", text: $name)

                    Picker("Category", selection: $category) {
                        ForEach(FoodCategory.displayOrder) { cat in
                            Text(cat.displayName).tag(cat)
                        }
                    }
                }

                Section("Amount") {
                    HStack {
                        Text("Quantity (pcs.)")
                        Spacer()
                        TextField("optional", text: $quantityText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                            // Keep the field away from the screen edge so it is
                            // easier to tap on its right side.
                            .padding(.trailing, 12)
                    }
                    HStack {
                        Text("Weight (g)")
                        Spacer()
                        TextField("optional", text: $weightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                            .padding(.trailing, 12)
                    }
                }

                Section("Dates") {
                    DatePicker(
                        location.dateAddedLabel,
                        selection: $dateAdded,
                        displayedComponents: .date
                    )

                    Toggle("Set an expiry date", isOn: $hasExpiryDate)
                    if hasExpiryDate {
                        DatePicker("Best before", selection: $expiryDate, displayedComponents: .date)
                    }
                }

                Section("Notes") {
                    TextField("e.g. from the top freezer drawer, marinated, etc.", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle(isEditing ? "Edit item" : "New item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if itemToEdit != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showingMoveSheet = true
                        } label: {
                            Label("Move", systemImage: "arrow.left.arrow.right")
                        }
                    }
                    ToolbarItem(placement: .destructiveAction) {
                        Button("Delete", role: .destructive) { deleteAndDismiss() }
                    }
                }
            }
            .onAppear(perform: populateIfEditing)
            .sheet(isPresented: $showingMoveSheet) {
                if let item = itemToEdit {
                    MoveFoodItemView(item: item, onComplete: { dismiss() })
                }
            }
        }
    }

    private func populateIfEditing() {
        guard let item = itemToEdit else { return }
        name = item.name
        category = item.category
        weightText = item.weightInGrams.map { String(format: "%g", $0) } ?? ""
        quantityText = item.quantity.map(String.init) ?? ""
        dateAdded = item.dateAdded
        if let expiry = item.expiryDate {
            hasExpiryDate = true
            expiryDate = expiry
        }
        notes = item.notes ?? ""
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let weight = Double(weightText.replacingOccurrences(of: ",", with: "."))
        let quantity = Int(quantityText)
        let finalExpiry = hasExpiryDate ? expiryDate : nil
        let finalNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        if let item = itemToEdit {
            let previous = FoodItemSnapshot(item)
            item.name = trimmedName
            item.category = category
            item.weightInGrams = weight
            item.quantity = quantity
            item.dateAdded = dateAdded
            item.expiryDate = finalExpiry
            item.notes = finalNotes.isEmpty ? nil : finalNotes
            NotificationManager.shared.scheduleReminders(for: item)
            undoActions.recordEdit(previous: previous, current: item)
        } else {
            // When no expiry date was given, set a default one based on the
            // item's location and category.
            let expiry = finalExpiry ?? defaultExpiryDate()
            let newItem = FoodItem(
                name: trimmedName,
                location: location,
                category: category,
                weightInGrams: weight,
                quantity: quantity ?? 1,
                dateAdded: dateAdded,
                expiryDate: expiry,
                notes: finalNotes.isEmpty ? nil : finalNotes
            )
            modelContext.insert(newItem)
            NotificationManager.shared.scheduleReminders(for: newItem)
            undoActions.recordAdd(newItem)
        }

        dismiss()
    }

    /// Default expiry date, used when the user did not set one.
    /// - Fridge: 3 days from the date added.
    /// - Freezer: depends on the category (365 / 180 / 90 days).
    /// - Pantry: none. Shelf life there ranges from weeks to years and is printed on
    ///   the packaging, so guessing one would only produce misleading reminders.
    private func defaultExpiryDate() -> Date? {
        let days: Int
        switch location {
        case .fridge:
            days = 3
        case .freezer:
            days = category.freezerShelfLifeDays
        case .pantry:
            return nil
        }
        return Calendar.current.date(byAdding: .day, value: days, to: dateAdded) ?? dateAdded
    }

    private func deleteAndDismiss() {
        if let item = itemToEdit {
            undoActions.recordDelete([item])
            NotificationManager.shared.cancelAllNotifications(for: item)
            modelContext.delete(item)
        }
        dismiss()
    }
}

#Preview {
    AddEditFoodItemView(location: .freezer)
        .modelContainer(for: FoodItem.self, inMemory: true)
        .environment(UndoActionManager())
        .environment(AppSettings())
}
