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
    /// Name of the category, used in pickers and in the list rows.
    var displayName: LocalizedStringKey {
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
        case .sauces: "Sauces"
        case .drinks: "Drinks"
        case .readyMeal: "Ready meal"
        case .other: "Other"
        }
    }
}
