import Foundation
@preconcurrency import UserNotifications

/// Zarządza lokalnymi powiadomieniami (offline, bez serwera).
///
/// Ograniczenie systemowe: iOS pozwala na maks. 64 zaplanowane powiadomienia
/// na aplikację jednocześnie. Przy dużej liczbie produktów w zamrażarce nie da się
/// zaplanować "wszystkich cotygodniowych przypomnień na rok do przodu" dla każdego z nich.
///
/// Rozwiązanie: dla zamrażarki planujemy zawsze tylko NAJBLIŻSZE nadchodzące przypomnienie
/// dla danego produktu (1 miesiąc od włożenia, potem co tydzień). Przy każdym otwarciu
/// aplikacji `rescheduleAll(items:)` przelicza i odświeża te przypomnienia — więc jeśli
/// otwierasz appkę choć raz na jakiś czas, seria powiadomień "co tydzień" działa płynnie.
/// Dla lodówki planujemy oba przypomnienia (5 i 3 dni przed terminem) na raz — to tylko
/// 2 powiadomienia na produkt, więc mieszczą się bez problemu.
@MainActor
final class NotificationManager {
    static let shared = NotificationManager()
    private let center = UNUserNotificationCenter.current()

    private let expiryReminderDaysBefore = [5, 3, 1, 0]
    private let freezerFirstReminderAfterDays = 30
    private let freezerReminderIntervalDays = 7
    private let notificationHour = 9 // godzina wysyłki, 9:00 rano

    private init() {}

    // MARK: - Uprawnienia

    func requestAuthorizationIfNeeded() {
        let c = center
        c.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            c.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }
    }

    // MARK: - Publiczne API

    /// Planuje / odświeża powiadomienia dla pojedynczego produktu (wywołuj po dodaniu/edycji).
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

    /// Usuwa wszystkie zaplanowane powiadomienia dla produktu (wywołuj przed usunięciem produktu).
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

    /// Przelicza i odświeża powiadomienia dla wszystkich produktów. Wołaj przy starcie
    /// aplikacji i za każdym razem, gdy wraca na pierwszy plan.
    func rescheduleAll(items: [FoodItem]) {
        for item in items {
            scheduleReminders(for: item)
        }
    }

    // MARK: - Termin ważności (lodówka i zamrażarka)

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

    // MARK: - Zamrażarka: czas przechowywania

    private func scheduleNextFreezerReminder(for item: FoodItem) {
        let daysSinceAdded = Calendar.current.dateComponents(
            [.day], from: item.dateAdded, to: .now
        ).day ?? 0

        // Wyznacz najbliższy próg z serii: 30, 37, 44, 51... dni od włożenia
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

    // MARK: - Pomocnicze

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
