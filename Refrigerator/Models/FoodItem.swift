import Foundation
import SwiftData

enum StorageLocation: String, Codable, CaseIterable, Identifiable {
    case fridge = "Lodówka"
    case freezer = "Zamrażarka"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .fridge: return "refrigerator"
        case .freezer: return "snowflake"
        }
    }

    /// Przeciwna lokalizacja — używana przy przenoszeniu produktu.
    var opposite: StorageLocation {
        switch self {
        case .fridge: return .freezer
        case .freezer: return .fridge
        }
    }
}

enum FoodCategory: String, Codable, CaseIterable, Identifiable {
    case beef = "Wołowina"
    case pork = "Wieprzowina"
    case poultry = "Drób"
    case game = "Dziczyzna"
    case mutton = "Baranina"
    case fish = "Ryby"
    case butter = "Masło"
    case dairy = "Nabiał"
    case vegetables = "Warzywa"
    case readyMeal = "Danie gotowe"
    case other = "Inne"

    var id: String { rawValue }
}

@Model
final class FoodItem {
    var id: UUID
    var name: String
    var location: StorageLocation
    var category: FoodCategory
    var weightInGrams: Double?      // opcjonalna waga w gramach
    var quantity: Int?              // opcjonalna ilość (szt.)
    var dateAdded: Date             // data włożenia do lodówki/zamrażarki
    var expiryDate: Date?           // tylko dla lodówki (opcjonalnie)
    var notes: String?

    init(
        id: UUID = UUID(),
        name: String,
        location: StorageLocation,
        category: FoodCategory = .other,
        weightInGrams: Double? = nil,
        quantity: Int? = nil,
        dateAdded: Date = .now,
        expiryDate: Date? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.location = location
        self.category = category
        self.weightInGrams = weightInGrams
        self.quantity = quantity
        self.dateAdded = dateAdded
        self.expiryDate = expiryDate
        self.notes = notes
    }

    /// Liczba dni od włożenia do lodówki/zamrażarki
    var daysSinceAdded: Int {
        Calendar.current.dateComponents([.day], from: dateAdded, to: .now).day ?? 0
    }

    /// Liczba dni do upływu terminu ważności (tylko lodówka), ujemna gdy przeterminowane
    var daysUntilExpiry: Int? {
        guard let expiryDate else { return nil }
        return Calendar.current.dateComponents([.day], from: .now, to: expiryDate).day
    }

    var isExpiringSoon: Bool {
        guard let days = daysUntilExpiry else { return false }
        return days <= 3
    }

    var isExpired: Bool {
        guard let days = daysUntilExpiry else { return false }
        return days < 0
    }

    /// Ocena czasu przechowywania w zamrażarce — orientacyjne progi (dni)
    var freezerFreshness: FreezerFreshness {
        switch daysSinceAdded {
        case ..<90: return .fresh          // do 3 miesięcy
        case 90..<180: return .useSoon     // 3-6 miesięcy
        default: return .old               // ponad 6 miesięcy
        }
    }
}

enum FreezerFreshness {
    case fresh
    case useSoon
    case old
}
