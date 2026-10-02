import SwiftUI

// Wording of an undo action. A single item is inserted into the sentence as a quoted
// name, while a batch gets its own full sentence: languages that inflect nouns need a
// different form after "undo deleting" than the one used on its own.

extension UndoActionSummary {
    /// Short label next to the toolbar icon, e.g. "deleting".
    var shortLabel: LocalizedStringKey {
        switch kind {
        case .add: "adding"
        case .edit: "editing"
        case .delete: "deleting"
        case .move: "moving"
        }
    }

    /// Accessibility label of the undo button, e.g. "Undo deleting “Beef steak”".
    var undoLabel: Text {
        switch subject {
        case let .named(name):
            switch kind {
            case .add: Text("Undo adding \(quoted(name))")
            case .edit: Text("Undo editing \(quoted(name))")
            case .delete: Text("Undo deleting \(quoted(name))")
            case .move: Text("Undo moving \(quoted(name))")
            }
        case let .count(count):
            switch kind {
            case .add: Text("Undo adding \(count) items")
            case .edit: Text("Undo editing \(count) items")
            case .delete: Text("Undo deleting \(count) items")
            case .move: Text("Undo moving \(count) items")
            }
        }
    }

    /// Confirmation shown after undoing, e.g. "Undid deleting “Beef steak”".
    var undidLabel: Text {
        switch subject {
        case let .named(name):
            switch kind {
            case .add: Text("Undid adding \(quoted(name))")
            case .edit: Text("Undid editing \(quoted(name))")
            case .delete: Text("Undid deleting \(quoted(name))")
            case .move: Text("Undid moving \(quoted(name))")
            }
        case let .count(count):
            switch kind {
            case .add: Text("Undid adding \(count) items")
            case .edit: Text("Undid editing \(count) items")
            case .delete: Text("Undid deleting \(count) items")
            case .move: Text("Undid moving \(count) items")
            }
        }
    }

    /// An item name in the quotation marks used by the current language.
    private func quoted(_ name: String) -> Text {
        Text("“\(name)”")
    }
}
