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

    /// The opposite location — used when moving an item.
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
    case eggs = "Jajka"
    case vegetables = "Warzywa"
    case fruits = "Owoce"
    case sauces = "Sosy"
    case drinks = "Napoje"
    case readyMeal = "Danie gotowe"
    case other = "Inne"

    var id: String { rawValue }

    /// The default „Inne” category is shown first in the list,
    /// the rest follow in declaration order.
    static var allCases: [FoodCategory] {
        [.other] + [
            .beef, .pork, .poultry, .game, .mutton, .fish,
            .butter, .dairy, .eggs, .vegetables, .fruits,
            .sauces, .drinks, .readyMeal
        ]
    }

    /// Default freezer shelf life (in days), used when no expiry date
    /// was given while adding the item.
    var freezerShelfLifeDays: Int {
        switch self {
        case .beef, .pork, .mutton, .game: return 365
        case .poultry, .fish, .butter: return 180
        default: return 90
        }
    }
}

@Model
final class FoodItem {
    var id: UUID
    var name: String
    var location: StorageLocation
    var category: FoodCategory
    var weightInGrams: Double?      // optional weight in grams
    var quantity: Int?              // optional quantity (pcs.)
    var dateAdded: Date             // date the item was put into the fridge/freezer
    var expiryDate: Date?           // fridge only (optional)
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

    /// Number of days since the item was put into the fridge/freezer
    var daysSinceAdded: Int {
        Calendar.current.dateComponents([.day], from: dateAdded, to: .now).day ?? 0
    }

    /// Number of days until the expiry date (fridge only), negative once expired
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

    /// Rating of the freezer storage time — rough thresholds (days)
    var freezerFreshness: FreezerFreshness {
        switch daysSinceAdded {
        case ..<90: return .fresh          // up to 3 months
        case 90..<180: return .useSoon     // 3-6 months
        default: return .old               // more than 6 months
        }
    }
}

enum FreezerFreshness {
    case fresh
    case useSoon
    case old
}
