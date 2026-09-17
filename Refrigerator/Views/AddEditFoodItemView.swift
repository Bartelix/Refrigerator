import SwiftUI
import SwiftData

struct AddEditFoodItemView: View {
    let location: StorageLocation
    var itemToEdit: FoodItem?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

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
                Section("Podstawowe informacje") {
                    TextField("Nazwa (np. Stek wołowy)", text: $name)

                    Picker("Kategoria", selection: $category) {
                        ForEach(FoodCategory.allCases) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }
                }

                Section("Ilość") {
                    HStack {
                        Text("Waga (g)")
                        Spacer()
                        TextField("opcjonalnie", text: $weightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }
                    HStack {
                        Text("Ilość (szt.)")
                        Spacer()
                        TextField("opcjonalnie", text: $quantityText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }
                }

                Section("Daty") {
                    DatePicker(
                        location == .fridge ? "Data włożenia do lodówki" : "Data włożenia do zamrażarki",
                        selection: $dateAdded,
                        displayedComponents: .date
                    )

                    Toggle("Ustaw termin ważności", isOn: $hasExpiryDate)
                    if hasExpiryDate {
                        DatePicker("Ważne do", selection: $expiryDate, displayedComponents: .date)
                    }
                }

                Section("Notatki") {
                    TextField("np. z zamrażarki górnej, marynowany itd.", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle(isEditing ? "Edytuj produkt" : "Nowy produkt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Zapisz" : "Dodaj") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if let item = itemToEdit {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showingMoveSheet = true
                        } label: {
                            Label(
                                "Przenieś do: \(item.location.opposite.rawValue)",
                                systemImage: item.location.opposite.systemImage
                            )
                            .symbolVariant(.fill)
                        }
                    }
                    ToolbarItem(placement: .destructiveAction) {
                        Button("Usuń", role: .destructive) { deleteAndDismiss() }
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
            item.name = trimmedName
            item.category = category
            item.weightInGrams = weight
            item.quantity = quantity
            item.dateAdded = dateAdded
            item.expiryDate = finalExpiry
            item.notes = finalNotes.isEmpty ? nil : finalNotes
            NotificationManager.shared.scheduleReminders(for: item)
        } else {
            let newItem = FoodItem(
                name: trimmedName,
                location: location,
                category: category,
                weightInGrams: weight,
                quantity: quantity ?? 1,
                dateAdded: dateAdded,
                expiryDate: finalExpiry,
                notes: finalNotes.isEmpty ? nil : finalNotes
            )
            modelContext.insert(newItem)
            NotificationManager.shared.scheduleReminders(for: newItem)
        }

        dismiss()
    }

    private func deleteAndDismiss() {
        if let item = itemToEdit {
            NotificationManager.shared.cancelAllNotifications(for: item)
            modelContext.delete(item)
        }
        dismiss()
    }
}

#Preview {
    AddEditFoodItemView(location: .freezer)
        .modelContainer(for: FoodItem.self, inMemory: true)
}
