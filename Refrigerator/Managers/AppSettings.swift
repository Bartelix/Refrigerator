import Foundation

/// Language the interface is shown in.
enum AppLanguage: String, CaseIterable, Identifiable {
    /// Follow the language chosen in the system settings.
    case system
    case polish = "pl"
    case english = "en"

    var id: String { rawValue }

    /// Locale used to resolve localized text, or `nil` when following the system.
    var locale: Locale? {
        switch self {
        case .system: nil
        case .polish, .english: Locale(identifier: rawValue)
        }
    }
}

/// Preferences that live outside the SwiftData store.
@MainActor
@Observable
final class AppSettings {
    private static let languageKey = "appLanguage"

    /// Language used for the interface and for the notification texts.
    var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: Self.languageKey)
        }
    }

    init() {
        let stored = UserDefaults.standard.string(forKey: Self.languageKey)
        language = stored.flatMap(AppLanguage.init(rawValue:)) ?? .system
    }

    /// Locale that views and notification texts resolve their strings with.
    var locale: Locale {
        language.locale ?? .autoupdatingCurrent
    }
}
