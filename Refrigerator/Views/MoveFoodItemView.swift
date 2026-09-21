import SwiftUI
import SwiftData

/// Widok konfiguracji przeniesienia produktu między lodówką a zamrażarką.
///
/// Przeniesienie odbywa się albo po ilości, albo po wadze — zależnie od tego, jak
/// opisana jest pozycja. Waga zapisana przy pozycji dotyczy jednej sztuki, więc przy
/// przenoszeniu części sztuk pozostaje bez zmian po obu stronach.
struct MoveFoodItemView: View {
    let item: FoodItem
    /// Wywoływane po udanym przeniesieniu (np. aby zamknąć widok edycji).
    var onComplete: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(UndoActionManager.self) private var undoActions

    @State private var quantityText: String = ""
    @State private var weightText: String = ""

    /// Sposób przenoszenia pozycji.
    private enum MoveMode {
        /// Dzielenie po liczbie sztuk — waga jednej sztuki pozostaje bez zmian.
        case quantity
        /// Dzielenie po wadze — dotyczy pozycji bez ilości lub z jedną sztuką.
        case weight
        /// Brak ilości i wagi — pozycja przenoszona w całości.
        case whole
    }

    private var destination: StorageLocation { item.location.opposite }

    /// Pozycja z więcej niż jedną sztuką dzielona jest po ilości; pojedyncza sztuka
    /// (lub pozycja bez ilości) z podaną wagą — po wadze.
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

    /// Poprawność wprowadzonych wartości — musi być dodatnia i nie większa niż dostępna.
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

        // Ilość i waga nowej pozycji oraz to, co zostaje w pozycji źródłowej.
        let movedQuantity: Int?
        let movedWeight: Double?
        let remainingQuantity: Int?
        let remainingWeight: Double?

        switch mode {
        case .quantity:
            let moveQuantity = parsedQuantity ?? 0
            movedQuantity = moveQuantity
            // Waga dotyczy jednej sztuki, więc obie pozycje zachowują tę samą wartość.
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

        // Po podziale zostaje coś w źródle tylko wtedy, gdy zmniejszana wartość jest dodatnia.
        let keepsRemainder: Bool
        switch mode {
        case .quantity: keepsRemainder = (remainingQuantity ?? 0) > 0
        case .weight: keepsRemainder = (remainingWeight ?? 0) > 0
        case .whole: keepsRemainder = false
        }

        if keepsRemainder {
            // Podział pozycji — nowa pozycja w miejscu docelowym, źródło pomniejszone.
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
            // Przeniesienie całości — wystarczy zmienić lokalizację.
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
