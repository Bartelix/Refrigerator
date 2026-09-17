import SwiftUI
import SwiftData

/// Widok konfiguracji przeniesienia produktu między lodówką a zamrażarką.
///
/// Domyślnie przenoszona jest cała ilość i cała waga. Jeśli użytkownik zmieni
/// wartość na niepełną, pozycja zostaje podzielona: do miejsca docelowego trafia
/// nowa pozycja z wybraną ilością/wagą, a pozycja źródłowa jest odpowiednio pomniejszana.
struct MoveFoodItemView: View {
    let item: FoodItem
    /// Wywoływane po udanym przeniesieniu (np. aby zamknąć widok edycji).
    var onComplete: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var quantityText: String = ""
    @State private var weightText: String = ""

    private var destination: StorageLocation { item.location.opposite }
    private var hasQuantity: Bool { item.quantity != nil }
    private var hasWeight: Bool { item.weightInGrams != nil }

    private var parsedQuantity: Int? {
        guard hasQuantity else { return nil }
        return Int(quantityText)
    }

    private var parsedWeight: Double? {
        guard hasWeight else { return nil }
        return Double(weightText.replacingOccurrences(of: ",", with: "."))
    }

    /// Poprawność wprowadzonych wartości — musi być dodatnia i nie większa niż dostępna.
    private var isValid: Bool {
        if hasQuantity {
            guard let q = parsedQuantity, q > 0, q <= item.quantity! else { return false }
        }
        if hasWeight {
            guard let w = parsedWeight, w > 0, w <= item.weightInGrams! else { return false }
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

                if hasQuantity || hasWeight {
                    Section {
                        if hasQuantity {
                            HStack {
                                Text("Ilość (szt.)")
                                Spacer()
                                TextField("", text: $quantityText)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 120)
                            }
                            Text("Dostępne: \(item.quantity!) szt.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if hasWeight {
                            HStack {
                                Text("Waga (g)")
                                Spacer()
                                TextField("", text: $weightText)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 120)
                            }
                            Text("Dostępne: \(formattedWeight(item.weightInGrams!))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("Ile przenieść")
                    } footer: {
                        Text("Domyślnie przenoszona jest cała ilość i waga. Zmień wartości, aby przenieść tylko część — pozycja zostanie podzielona.")
                    }
                } else {
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
        if let q = item.quantity {
            quantityText = String(q)
        }
        if let w = item.weightInGrams {
            weightText = String(format: "%g", w)
        }
    }

    private func performMove() {
        guard isValid else { return }

        let moveQty = parsedQuantity
        let moveWeight = parsedWeight

        let movingAllQuantity = item.quantity == nil || (moveQty ?? 0) >= item.quantity!
        let movingAllWeight = item.weightInGrams == nil || (moveWeight ?? 0) >= item.weightInGrams!

        if movingAllQuantity && movingAllWeight {
            // Przeniesienie całości — wystarczy zmienić lokalizację.
            NotificationManager.shared.cancelAllNotifications(for: item)
            item.location = destination
            item.dateAdded = .now
            NotificationManager.shared.scheduleReminders(for: item)
        } else {
            // Podział pozycji — nowa pozycja w miejscu docelowym, źródło pomniejszone.
            let movedItem = FoodItem(
                name: item.name,
                location: destination,
                category: item.category,
                weightInGrams: hasWeight ? moveWeight : nil,
                quantity: hasQuantity ? moveQty : nil,
                dateAdded: .now,
                expiryDate: item.expiryDate,
                notes: item.notes
            )
            modelContext.insert(movedItem)

            if hasQuantity, let moveQty {
                let remaining = item.quantity! - moveQty
                item.quantity = remaining > 0 ? remaining : nil
            }
            if hasWeight, let moveWeight {
                let remaining = item.weightInGrams! - moveWeight
                item.weightInGrams = remaining > 0 ? remaining : nil
            }

            NotificationManager.shared.scheduleReminders(for: item)
            NotificationManager.shared.scheduleReminders(for: movedItem)
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
}
