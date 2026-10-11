import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case spanish = "es"

    var id: String { rawValue }
}

extension Notification.Name {
    static let historialLanguageDidChange = Notification.Name("HistorialLanguageDidChange")
}

@MainActor
final class LocalizationStore: ObservableObject {
    static let shared = LocalizationStore()

    @Published var selection: AppLanguage {
        didSet {
            UserDefaults.standard.set(selection.rawValue, forKey: "appLanguage")
            NotificationCenter.default.post(name: .historialLanguageDidChange, object: nil)
        }
    }

    private init() {
        selection = AppLanguage(rawValue: UserDefaults.standard.string(forKey: "appLanguage") ?? "system") ?? .system
    }

    var languageCode: String {
        switch selection {
        case .english: return "en"
        case .spanish: return "es"
        case .system:
            return Bundle.preferredLocalizations(
                from: ["en", "es"],
                forPreferences: Locale.preferredLanguages
            ).first ?? "en"
        }
    }

    func text(_ key: String, _ arguments: CVarArg...) -> String {
        #if SWIFT_PACKAGE
        let resources = Bundle.module
        #else
        let resources = Bundle.main
        #endif
        let language = languageCode
        let bundle = resources.url(forResource: language, withExtension: "lproj")
            .flatMap(Bundle.init(url:)) ?? resources
        let template = bundle.localizedString(forKey: key, value: key, table: "Localizable")
        guard !arguments.isEmpty else { return template }
        return String(format: template, locale: Locale(identifier: language), arguments: arguments)
    }
}
