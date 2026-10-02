import Foundation
import SwiftData

/// Raw values of this enum and of `FoodCategory` are what SwiftData writes into the
/// store, so they must never change — items already saved would fail to load. The text
/// shown to the user lives in `displayName` instead, and is translated.
enum StorageLocation: String, Codable, CaseIterable, Identifiable {
    case fridge = "Lodówka"
    case freezer = "Zamrażarka"
    case pantry = "Spiżarnia"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .fridge: return "refrigerator"
        case .freezer: return "snowflake"
        case .pantry: return "cabinet"
        }
    }

    /// Locations an item kept here can be moved to, in tab order.
    var otherLocations: [StorageLocation] {
        Self.allCases.filter { $0 != self }
    }
}

enum FoodCategory: String, Codable, CaseIterable, Identifiable {
    // Meat and fish
    case beef = "Wołowina"
    case pork = "Wieprzowina"
    case poultry = "Drób"
    case game = "Dziczyzna"
    case mutton = "Baranina"
    case fish = "Ryby"

    // Dairy and eggs
    case butter = "Masło"
    case dairy = "Nabiał"
    case eggs = "Jajka"

    // Fresh produce
    case vegetables = "Warzywa"
    case fruits = "Owoce"

    // Pantry staples
    case bread = "Pieczywo"
    case pasta = "Makaron"
    case grains = "Kasze i ryż"
    case flour = "Mąka"
    case cereals = "Płatki śniadaniowe"
    case legumes = "Strączkowe"
    case cannedGoods = "Konserwy"
    case preserves = "Przetwory"
    case sauces = "Sosy"
    case spices = "Przyprawy"
    case oils = "Oleje i tłuszcze"

    // Drinks
    case water = "Woda"
    case drinks = "Napoje"
    case coffeeAndTea = "Kawa i herbata"
    case alcohol = "Alkohol"

    // Snacks and ready-to-eat
    case nuts = "Orzechy i bakalie"
    case sweets = "Słodycze"
    case snacks = "Przekąski"
    case readyMeal = "Danie gotowe"

    case other = "Inne"

    var id: String { rawValue }

    /// Categories in the order they are offered for picking: the default `other`
    /// first, the rest in declaration order. Derived from `allCases` rather than
    /// spelled out, so a newly added case can never be left out by accident.
    static var displayOrder: [FoodCategory] {
        [.other] + allCases.filter { $0 != .other }
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
    /// Name of the user-defined category, or `nil` when `category` applies. Both are
    /// stored: `category` predates custom categories and still drives the freezer
    /// shelf life, so a custom category keeps it at `other` and takes over the label.
    var customCategoryName: String?
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
        customCategoryName: String? = nil,
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
        self.customCategoryName = customCategoryName
        self.weightInGrams = weightInGrams
        self.quantity = quantity
        self.dateAdded = dateAdded
        self.expiryDate = expiryDate
        self.notes = notes
    }

    /// The category as shown and picked in the interface.
    var categorySelection: CategorySelection {
        get {
            if let name = customCategoryName, !name.isEmpty { return .custom(name) }
            return .builtIn(category)
        }
        set {
            category = newValue.effectiveCategory
            customCategoryName = newValue.customName
        }
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
