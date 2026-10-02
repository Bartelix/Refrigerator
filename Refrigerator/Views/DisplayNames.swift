import SwiftUI

// The text shown for a `StorageLocation` or a `FoodCategory` is kept separate from the
// enum's raw value on purpose: SwiftData persists the raw values, so they have to stay
// unchanged, while the displayed name has to follow the selected language.

extension StorageLocation {
    /// Name of the location, used for the tab bar and the list title.
    var displayName: LocalizedStringKey {
        switch self {
        case .fridge: "Fridge"
        case .freezer: "Freezer"
        case .pantry: "Pantry"
        }
    }

    /// Label of the date picker for when an item was put in.
    var dateAddedLabel: LocalizedStringKey {
        switch self {
        case .fridge: "Date put in the fridge"
        case .freezer: "Date put in the freezer"
        case .pantry: "Date put in the pantry"
        }
    }
}

extension FoodCategory {
    /// Name of the category, used in the lookup and in the list rows.
    ///
    /// A `LocalizedStringResource` rather than a `LocalizedStringKey`, because the
    /// category lookup matches what the user types against the translated names and
    /// therefore needs them as plain strings — see `resolvedName(in:)`.
    var displayName: LocalizedStringResource {
        switch self {
        case .beef: "Beef"
        case .pork: "Pork"
        case .poultry: "Poultry"
        case .game: "Game"
        case .mutton: "Mutton"
        case .fish: "Fish"
        case .butter: "Butter"
        case .dairy: "Dairy"
        case .eggs: "Eggs"
        case .vegetables: "Vegetables"
        case .fruits: "Fruit"
        case .bread: "Bread"
        case .pasta: "Pasta"
        case .grains: "Grains and rice"
        case .flour: "Flour"
        case .cereals: "Breakfast cereal"
        case .legumes: "Legumes"
        case .cannedGoods: "Canned goods"
        case .preserves: "Preserves"
        case .sauces: "Sauces"
        case .spices: "Spices"
        case .oils: "Oils and fats"
        case .water: "Water"
        case .drinks: "Drinks"
        case .coffeeAndTea: "Coffee and tea"
        case .alcohol: "Alcohol"
        case .nuts: "Nuts and dried fruit"
        case .sweets: "Sweets"
        case .snacks: "Snacks"
        case .readyMeal: "Ready meal"
        case .other: "Other"
        }
    }

    /// The translated name in a given language. Resolved explicitly rather than left
    /// to SwiftUI, so that matching and rendering always agree on the same text.
    func resolvedName(in locale: Locale) -> String {
        var resource = displayName
        resource.locale = locale
        return String(localized: resource)
    }
}

extension CategorySelection {
    /// Label of the category. A built-in name is translated; a custom one is the
    /// user's own text and is used as typed, so it never reaches the string catalog.
    func resolvedName(in locale: Locale) -> String {
        switch self {
        case let .builtIn(category): category.resolvedName(in: locale)
        case let .custom(name): name
        }
    }
}
