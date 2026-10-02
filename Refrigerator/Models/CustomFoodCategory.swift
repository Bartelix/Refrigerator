import Foundation
import SwiftData

/// A category added by the user, kept so that it can be offered again when the next
/// item is added. The built-in `FoodCategory` cases cannot cover every pantry, and a
/// name typed once would otherwise be gone as soon as the item was saved.
@Model
final class CustomFoodCategory {
    /// Name as typed by the user. It is also the value stored on the items that use
    /// this category, which is why it has to stay unique.
    @Attribute(.unique) var name: String
    var dateAdded: Date

    init(name: String, dateAdded: Date = .now) {
        self.name = name
        self.dateAdded = dateAdded
    }
}

/// The category of an item as the user picks it: either one of the built-ins or one
/// they added themselves.
enum CategorySelection: Hashable, Identifiable {
    case builtIn(FoodCategory)
    case custom(String)

    var id: String {
        switch self {
        case let .builtIn(category): "builtIn:\(category.rawValue)"
        case let .custom(name): "custom:\(name)"
        }
    }

    /// Name of a custom category, or `nil` for a built-in one.
    var customName: String? {
        switch self {
        case .builtIn: nil
        case let .custom(name): name
        }
    }

    /// The built-in category this selection behaves as. A custom category carries no
    /// shelf-life data of its own, so it falls back to `other`.
    var effectiveCategory: FoodCategory {
        switch self {
        case let .builtIn(category): category
        case .custom: .other
        }
    }
}
