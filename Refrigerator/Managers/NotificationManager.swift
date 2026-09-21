import Foundation
@preconcurrency import UserNotifications

/// Manages local notifications (offline, no server).
///
/// System limit: iOS allows at most 64 scheduled notifications per app at a time.
/// With many items in the freezer there is no way to schedule "every weekly reminder
/// for a year ahead" for each of them.
///
/// Solution: for the freezer we always schedule only the NEXT upcoming reminder for
/// a given item (1 month after it was put in, then weekly). Every time the app is
/// opened, `rescheduleAll(items:)` recomputes and refreshes those reminders — so as
/// long as you open the app every once in a while, the "weekly" series runs smoothly.
/// For the fridge we schedule both reminders (5 and 3 days before the expiry date) at
/// once — that is only 2 notifications per item, so they fit without trouble.
@MainActor
final class NotificationManager {
    static let shared = NotificationManager()
    private let center = UNUserNotificationCenter.current()

    private let expiryReminderDaysBefore = [5, 3, 1, 0]
    private let freezerFirstReminderAfterDays = 30
    private let freezerReminderIntervalDays = 7
    private let notificationHour = 9 // delivery hour, 9:00 in the morning

    private init() {}

    // MARK: - Authorization

    func requestAuthorizationIfNeeded() {
        let c = center
        c.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            c.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }
    }

    // MARK: - Public API

    /// Schedules / refreshes the notifications for a single item (call it after adding/editing).
    func scheduleReminders(for item: FoodItem) {
        cancelAllNotifications(for: item)

        switch item.location {
        case .fridge:
            scheduleExpiryReminders(for: item)
        case .freezer:
            scheduleNextFreezerReminder(for: item)
            scheduleExpiryReminders(for: item)
        }
    }

    /// Removes every scheduled notification for an item (call it before deleting the item).
    func cancelAllNotifications(for item: FoodItem) {
        let prefix = item.id.uuidString
        let c = center
        c.getPendingNotificationRequests { requests in
            let idsToRemove = requests.map(\.identifier).filter { $0.hasPrefix(prefix) }
            if !idsToRemove.isEmpty {
                c.removePendingNotificationRequests(withIdentifiers: idsToRemove)
            }
        }
    }

    /// Recomputes and refreshes the notifications for every item. Call it on app
    /// launch and every time the app returns to the foreground.
    func rescheduleAll(items: [FoodItem]) {
        for item in items {
            scheduleReminders(for: item)
        }
    }

    // MARK: - Expiry date (fridge and freezer)

    private func scheduleExpiryReminders(for item: FoodItem) {
        guard let expiryDate = item.expiryDate else { return }

        for daysBefore in expiryReminderDaysBefore {
            let triggerDate: Date
            if daysBefore == 0 {
                triggerDate = expiryDate
            } else {
                guard let d = Calendar.current.date(byAdding: .day, value: -daysBefore, to: expiryDate) else { continue }
                triggerDate = d
            }
            guard triggerDate > .now else { continue }

            let content = UNMutableNotificationContent()
            content.title = expiryTitle(daysBefore: daysBefore)
            content.body = expiryBody(for: item, daysBefore: daysBefore)
            content.sound = .default

            schedule(
                content: content,
                at: triggerDate,
                identifier: "\(item.id.uuidString)-expiry-\(daysBefore)"
            )
        }
    }

    private func expiryTitle(daysBefore: Int) -> String {
        switch daysBefore {
        case 0: return "Termin ważności mija dziś"
        case 1: return "Termin ważności mija jutro"
        default: return "Zbliża się termin ważności"
        }
    }

    private func expiryBody(for item: FoodItem, daysBefore: Int) -> String {
        switch daysBefore {
        case 0: return "\(item.name) — ostatni dzień ważności"
        case 1: return "\(item.name) — wygasa jutro"
        default: return "\(item.name) — termin ważności za \(daysBefore) \(dayWord(daysBefore))"
        }
    }

    // MARK: - Freezer: storage time

    private func scheduleNextFreezerReminder(for item: FoodItem) {
        let daysSinceAdded = Calendar.current.dateComponents(
            [.day], from: item.dateAdded, to: .now
        ).day ?? 0

        // Find the nearest threshold in the series: 30, 37, 44, 51... days since added
        var nextThreshold = freezerFirstReminderAfterDays
        while nextThreshold <= daysSinceAdded {
            nextThreshold += freezerReminderIntervalDays
        }

        guard let triggerDate = Calendar.current.date(
            byAdding: .day, value: nextThreshold, to: item.dateAdded
        ), triggerDate > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = "Produkt długo w zamrażarce"
        content.body = "\(item.name) leży w zamrażarce już \(nextThreshold) dni"
        content.sound = .default

        schedule(
            content: content,
            at: triggerDate,
            identifier: "\(item.id.uuidString)-freezer-\(nextThreshold)"
        )
    }

    // MARK: - Helpers

    private func schedule(content: UNMutableNotificationContent, at date: Date, identifier: String) {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = notificationHour
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
    }

    private func dayWord(_ count: Int) -> String {
        count == 1 ? "dzień" : "dni"
    }
}
