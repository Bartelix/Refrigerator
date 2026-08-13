import Foundation
import UserNotifications

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

    private let expiryReminderDaysBefore = [5, 3]
    private let freezerFirstReminderAfterDays = 30
    private let freezerReminderIntervalDays = 7
    private let notificationHour = 9 // godzina wysyłki, 9:00 rano

    private init() {}

    // MARK: - Uprawnienia

    func requestAuthorizationIfNeeded() {
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            self.center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }
    }

    // MARK: - Publiczne API

    /// Planuje / odświeża powiadomienia dla pojedynczego produktu (wywołuj po dodaniu/edycji).
    func scheduleReminders(for item: FoodItem) {
        cancelAllNotifications(for: item)

        switch item.location {
        case .fridge:
            scheduleFridgeExpiryReminders(for: item)
        case .freezer:
            scheduleNextFreezerReminder(for: item)
        }
    }

    /// Usuwa wszystkie zaplanowane powiadomienia dla produktu (wywołuj przed usunięciem produktu).
    func cancelAllNotifications(for item: FoodItem) {
        let prefix = item.id.uuidString
        center.getPendingNotificationRequests { requests in
            let idsToRemove = requests.map(\.identifier).filter { $0.hasPrefix(prefix) }
            if !idsToRemove.isEmpty {
                self.center.removePendingNotificationRequests(withIdentifiers: idsToRemove)
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

    // MARK: - Lodówka: termin ważności

    private func scheduleFridgeExpiryReminders(for item: FoodItem) {
        guard let expiryDate = item.expiryDate else { return }

        for daysBefore in expiryReminderDaysBefore {
            guard let triggerDate = Calendar.current.date(byAdding: .day, value: -daysBefore, to: expiryDate),
                  triggerDate > .now else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Kończy się termin ważności"
            content.body = "\(item.name) — termin ważności za \(daysBefore) \(dayWord(daysBefore))"
            content.sound = .default

            schedule(
                content: content,
                at: triggerDate,
                identifier: "\(item.id.uuidString)-expiry-\(daysBefore)"
            )
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
