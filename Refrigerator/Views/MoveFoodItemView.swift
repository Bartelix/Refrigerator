import SwiftUI
import SwiftData

/// View for setting up a move of an item between storage locations.
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

    @State private var destination: StorageLocation
    @State private var quantityText: String = ""
    @State private var weightText: String = ""

    init(item: FoodItem, onComplete: (() -> Void)? = nil) {
        self.item = item
        self.onComplete = onComplete
        // Preselect the first of the possible destinations; with more than one the
        // user picks from them below.
        _destination = State(initialValue: item.location.otherLocations.first ?? item.location)
    }

    /// How the item is moved.
    private enum MoveMode {
        /// Split by the number of pieces — the weight of a single piece stays unchanged.
        case quantity
        /// Split by weight — applies to items without a quantity or with a single piece.
        case weight
        /// No quantity and no weight — the item is moved as a whole.
        case whole
    }

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
                        Label(item.location.displayName, systemImage: item.location.systemImage)
                        Spacer()
                        Image(systemName: "arrow.right")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Label(destination.displayName, systemImage: destination.systemImage)
                    }
                    .font(.subheadline.weight(.medium))

                    LabeledContent("Item", value: item.name)

                    // With a single possible destination there is nothing to choose.
                    if item.location.otherLocations.count > 1 {
                        Picker("Move to", selection: $destination) {
                            ForEach(item.location.otherLocations) { location in
                                Label(location.displayName, systemImage: location.systemImage)
                                    .tag(location)
                            }
                        }
                    }
                }

                switch mode {
                case .quantity:
                    Section {
                        HStack {
                            Text("Quantity (pcs.)")
                            Spacer()
                            // The field is prefilled, so it needs no placeholder;
                            // an empty literal would end up in the string catalog.
                            TextField(text: $quantityText) { Text(verbatim: "") }
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 120)
                                // Keep the field away from the screen edge so it is
                                // easier to tap on its right side.
                                .padding(.trailing, 12)
                        }
                        Text("Available: \(item.quantity ?? 0) pcs.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let weight = item.weightInGrams {
                            Text("Weight: \(formattedWeight(weight)) per piece — unchanged")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("How much to move (by quantity)")
                    } footer: {
                        Text("The whole quantity is moved by default. Change the value to move only some of the pieces — the item will be split, and the weight of a single piece will stay the same.")
                    }
                case .weight:
                    Section {
                        HStack {
                            Text("Weight (g)")
                            Spacer()
                            TextField(text: $weightText) { Text(verbatim: "") }
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 120)
                                .padding(.trailing, 12)
                        }
                        Text("Available: \(formattedWeight(item.weightInGrams ?? 0))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } header: {
                        Text("How much to move (by weight)")
                    } footer: {
                        Text("The whole weight is moved by default. Change the value to move only part of it — the item will be split.")
                    }
                case .whole:
                    Section {
                        Text("The item has no quantity or weight set — it will be moved as a whole.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Move item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Move") { performMove() }
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
            name: "Beef steak",
            location: .freezer,
            category: .beef,
            weightInGrams: 500,
            quantity: 4
        )
    )
    .modelContainer(for: FoodItem.self, inMemory: true)
    .environment(UndoActionManager())
    .environment(AppSettings())
}
