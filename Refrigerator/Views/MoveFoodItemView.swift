import SwiftUI
import SwiftData

/// View for setting up a move of an item between the fridge and the freezer.
///
/// The move happens either by quantity or by weight — depending on how the item is
/// described. The weight stored on an item refers to a single piece, so when only
/// part of the pieces is moved it stays unchanged on both sides.
struct MoveFoodItemView: View {
    let item: FoodItem
    /// Called after a successful move (e.g. to dismiss the edit view).
    var onComplete: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(UndoActionManager.self) private var undoActions

    @State private var quantityText: String = ""
    @State private var weightText: String = ""

    /// How the item is moved.
    private enum MoveMode {
        /// Split by the number of pieces — the weight of a single piece stays unchanged.
        case quantity
        /// Split by weight — applies to items without a quantity or with a single piece.
        case weight
        /// No quantity and no weight — the item is moved as a whole.
        case whole
    }

    private var destination: StorageLocation { item.location.opposite }

    /// An item with more than one piece is split by quantity; a single piece
    /// (or an item without a quantity) that has a weight — by weight.
    private var mode: MoveMode {
        if let quantity = item.quantity, quantity > 1 { return .quantity }
        if item.weightInGrams != nil { return .weight }
        if item.quantity != nil { return .quantity }
        return .whole
    }

    private var parsedQuantity: Int? { Int(quantityText) }

    private var parsedWeight: Double? {
        Double(weightText.replacingOccurrences(of: ",", with: "."))
    }

    /// Validity of the entered value — it must be positive and no larger than what is available.
    private var isValid: Bool {
        switch mode {
        case .quantity:
            guard let quantity = parsedQuantity, quantity > 0, quantity <= (item.quantity ?? 0) else { return false }
        case .weight:
            guard let weight = parsedWeight, weight > 0, weight <= (item.weightInGrams ?? 0) else { return false }
        case .whole:
            break
        }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Label(item.location.rawValue, systemImage: item.location.systemImage)
                        Spacer()
                        Image(systemName: "arrow.right")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Label(destination.rawValue, systemImage: destination.systemImage)
                    }
                    .font(.subheadline.weight(.medium))

                    LabeledContent("Produkt", value: item.name)
                }

                switch mode {
                case .quantity:
                    Section {
                        HStack {
                            Text("Ilość (szt.)")
                            Spacer()
                            TextField("", text: $quantityText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 120)
                                // Keep the field away from the screen edge so it is
                                // easier to tap on its right side.
                                .padding(.trailing, 12)
                        }
                        Text("Dostępne: \(item.quantity ?? 0) szt.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let weight = item.weightInGrams {
                            Text("Waga: \(formattedWeight(weight)) / szt. — bez zmian")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("Ile przenieść (po ilości)")
                    } footer: {
                        Text("Domyślnie przenoszona jest cała ilość. Zmień wartość, aby przenieść tylko część sztuk — pozycja zostanie podzielona, a waga jednej sztuki pozostanie taka sama.")
                    }
                case .weight:
                    Section {
                        HStack {
                            Text("Waga (g)")
                            Spacer()
                            TextField("", text: $weightText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 120)
                                .padding(.trailing, 12)
                        }
                        Text("Dostępne: \(formattedWeight(item.weightInGrams ?? 0))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } header: {
                        Text("Ile przenieść (po wadze)")
                    } footer: {
                        Text("Domyślnie przenoszona jest cała waga. Zmień wartość, aby przenieść tylko część — pozycja zostanie podzielona.")
                    }
                case .whole:
                    Section {
                        Text("Produkt nie ma określonej ilości ani wagi — zostanie przeniesiony w całości.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Przenieś produkt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Przenieś") { performMove() }
                        .disabled(!isValid)
                }
            }
            .onAppear(perform: populateDefaults)
        }
    }

    private func populateDefaults() {
        if let quantity = item.quantity {
            quantityText = String(quantity)
        }
        if let weight = item.weightInGrams {
            weightText = String(format: "%g", weight)
        }
    }

    private func performMove() {
        guard isValid else { return }

        let previous = FoodItemSnapshot(item)

        // Quantity and weight of the new item, plus what stays on the source item.
        let movedQuantity: Int?
        let movedWeight: Double?
        let remainingQuantity: Int?
        let remainingWeight: Double?

        switch mode {
        case .quantity:
            let moveQuantity = parsedQuantity ?? 0
            movedQuantity = moveQuantity
            // The weight refers to a single piece, so both items keep the same value.
            movedWeight = item.weightInGrams
            remainingQuantity = (item.quantity ?? 0) - moveQuantity
            remainingWeight = item.weightInGrams
        case .weight:
            let moveWeight = parsedWeight ?? 0
            movedQuantity = item.quantity
            movedWeight = moveWeight
            remainingQuantity = item.quantity
            remainingWeight = (item.weightInGrams ?? 0) - moveWeight
        case .whole:
            movedQuantity = item.quantity
            movedWeight = item.weightInGrams
            remainingQuantity = nil
            remainingWeight = nil
        }

        // After a split something is left on the source only when the reduced value is positive.
        let keepsRemainder: Bool
        switch mode {
        case .quantity: keepsRemainder = (remainingQuantity ?? 0) > 0
        case .weight: keepsRemainder = (remainingWeight ?? 0) > 0
        case .whole: keepsRemainder = false
        }

        if keepsRemainder {
            // Splitting the item — a new item at the destination, the source reduced.
            let movedItem = FoodItem(
                name: item.name,
                location: destination,
                category: item.category,
                weightInGrams: movedWeight,
                quantity: movedQuantity,
                dateAdded: .now,
                expiryDate: item.expiryDate,
                notes: item.notes
            )
            modelContext.insert(movedItem)

            item.quantity = remainingQuantity
            item.weightInGrams = remainingWeight

            NotificationManager.shared.scheduleReminders(for: item)
            NotificationManager.shared.scheduleReminders(for: movedItem)
            undoActions.recordMove(previous: previous, createdItem: movedItem)
        } else {
            // Moving the whole item — changing the location is enough.
            NotificationManager.shared.cancelAllNotifications(for: item)
            item.location = destination
            item.dateAdded = .now
            NotificationManager.shared.scheduleReminders(for: item)
            undoActions.recordMove(previous: previous, createdItem: nil)
        }

        onComplete?()
        dismiss()
    }
}

#Preview {
    MoveFoodItemView(
        item: FoodItem(
            name: "Stek wołowy",
            location: .freezer,
            category: .beef,
            weightInGrams: 500,
            quantity: 4
        )
    )
    .modelContainer(for: FoodItem.self, inMemory: true)
    .environment(UndoActionManager())
}
