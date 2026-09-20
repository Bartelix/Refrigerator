import Foundation
import SwiftData

/// An immutable copy of a `FoodItem`'s state, used to restore it when an action is undone.
struct FoodItemSnapshot: Equatable {
    var id: UUID
    var name: String
    var location: StorageLocation
    var category: FoodCategory
    var weightInGrams: Double?
    var quantity: Int?
    var dateAdded: Date
    var expiryDate: Date?
    var notes: String?

    init(_ item: FoodItem) {
        id = item.id
        name = item.name
        location = item.location
        category = item.category
        weightInGrams = item.weightInGrams
        quantity = item.quantity
        dateAdded = item.dateAdded
        expiryDate = item.expiryDate
        notes = item.notes
    }

    /// Recreates a deleted item, keeping the original `id` so later undo steps still match it.
    func makeItem() -> FoodItem {
        FoodItem(
            id: id,
            name: name,
            location: location,
            category: category,
            weightInGrams: weightInGrams,
            quantity: quantity,
            dateAdded: dateAdded,
            expiryDate: expiryDate,
            notes: notes
        )
    }

    /// Writes the snapshotted values back onto an existing item.
    func restore(onto item: FoodItem) {
        item.name = name
        item.location = location
        item.category = category
        item.weightInGrams = weightInGrams
        item.quantity = quantity
        item.dateAdded = dateAdded
        item.expiryDate = expiryDate
        item.notes = notes
    }
}

/// Kind of a recorded action, used to build the user-facing description.
enum UndoActionKind: Equatable {
    case add
    case edit
    case delete
    case move

    /// Polish phrase in the accusative case, so it reads correctly after
    /// „Cofnij” and „Cofnięto”.
    var phrase: String {
        switch self {
        case .add: return "dodanie"
        case .edit: return "edycję"
        case .delete: return "usunięcie"
        case .move: return "przeniesienie"
        }
    }
}

/// A single reversible action, described by what it did to the store.
///
/// Every action is expressed with the same three lists, so undoing one is always
/// the same operation: drop what the action created, bring back what it removed,
/// and restore the previous values of what it changed.
struct UndoStep: Equatable {
    let kind: UndoActionKind
    /// Preformatted name of what the action applied to, e.g. „Stek wołowy” or "3 pozycji".
    let subject: String
    /// Items created by the action — undo deletes them.
    var inserted: [FoodItemSnapshot] = []
    /// Items deleted by the action — undo brings them back.
    var removed: [FoodItemSnapshot] = []
    /// State of items before the action changed them — undo restores it.
    var updated: [FoodItemSnapshot] = []

    /// Full user-facing description, e.g. „usunięcie „Stek wołowy””.
    var description: String { "\(kind.phrase) \(subject)" }
}

/// Keeps a stack of recently performed actions so the user can reverse them one by one.
@MainActor
@Observable
final class UndoActionManager {
    /// Kind of the action that will be reversed next, or `nil` when there is nothing
    /// to undo. Used for the short label shown on the undo button.
    private(set) var lastActionKind: UndoActionKind?

    /// Full description of that action, e.g. „usunięcie „Stek wołowy””. Stored
    /// (instead of derived from `steps`) so that views observe only this value and
    /// not every change to the stack.
    private(set) var lastActionDescription: String?

    private var steps: [UndoStep] = []
    private let maxSteps = 20

    // MARK: - Recording

    func recordAdd(_ item: FoodItem) {
        record(UndoStep(
            kind: .add,
            subject: quoted(item.name),
            inserted: [FoodItemSnapshot(item)]
        ))
    }

    func recordEdit(previous: FoodItemSnapshot, current: FoodItem) {
        // Saving without touching anything is not worth an undo step.
        guard FoodItemSnapshot(current) != previous else { return }
        record(UndoStep(
            kind: .edit,
            subject: quoted(current.name),
            updated: [previous]
        ))
    }

    func recordDelete(_ items: [FoodItem]) {
        guard !items.isEmpty else { return }
        record(UndoStep(
            kind: .delete,
            subject: items.count == 1 ? quoted(items[0].name) : "\(items.count) pozycji",
            removed: items.map(FoodItemSnapshot.init)
        ))
    }

    /// Records a move. `createdItem` is set only when the item was split, i.e. when part
    /// of the quantity/weight stayed behind and a new item was created at the destination.
    func recordMove(previous: FoodItemSnapshot, createdItem: FoodItem?) {
        record(UndoStep(
            kind: .move,
            subject: quoted(previous.name),
            inserted: createdItem.map { [FoodItemSnapshot($0)] } ?? [],
            updated: [previous]
        ))
    }

    private func record(_ step: UndoStep) {
        steps.append(step)
        if steps.count > maxSteps {
            steps.removeFirst(steps.count - maxSteps)
        }
        updatePendingAction()
    }

    // MARK: - Undo

    /// Reverses the most recent action and returns its description, or `nil` when the
    /// stack is empty.
    @discardableResult
    func undoLast(in context: ModelContext) -> String? {
        guard let step = steps.popLast() else { return nil }
        updatePendingAction()

        // Items are matched by the model's own `id` rather than by a fetch predicate,
        // so that items re-inserted by this very undo are found by the steps that follow.
        let stored = (try? context.fetch(FetchDescriptor<FoodItem>())) ?? []
        var itemsByID = Dictionary(stored.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        for snapshot in step.inserted {
            guard let item = itemsByID[snapshot.id] else { continue }
            NotificationManager.shared.cancelAllNotifications(for: item)
            context.delete(item)
            itemsByID[snapshot.id] = nil
        }

        for snapshot in step.removed where itemsByID[snapshot.id] == nil {
            let item = snapshot.makeItem()
            context.insert(item)
            itemsByID[snapshot.id] = item
            NotificationManager.shared.scheduleReminders(for: item)
        }

        for snapshot in step.updated {
            guard let item = itemsByID[snapshot.id] else { continue }
            snapshot.restore(onto: item)
            NotificationManager.shared.scheduleReminders(for: item)
        }

        return step.description
    }

    // MARK: - Helpers

    /// Keeps the published properties in sync with the top of the stack.
    private func updatePendingAction() {
        lastActionKind = steps.last?.kind
        lastActionDescription = steps.last?.description
    }

    private func quoted(_ name: String) -> String {
        "„\(name)”"
    }
}
