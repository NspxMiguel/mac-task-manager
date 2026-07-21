import Foundation
import Combine

enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case english = "en"
    case portuguese = "pt"

    var id: String { rawValue }
    var displayName: String { self == .english ? "English" : "Português" }
}

enum ThemeMode: String, CaseIterable, Identifiable, Codable {
    case system, light, dark

    var id: String { rawValue }
    var label: String {
        tr(en: rawValue.capitalized, pt: ptLabel)
    }
    private var ptLabel: String {
        switch self {
        case .system: return "Sistema"
        case .light: return "Claro"
        case .dark: return "Escuro"
        }
    }
}

final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    private let defaults = UserDefaults.standard
    private let comboKey = "hotkey.combo"
    private let languageKey = "app.language"
    private let themeKey = "app.theme"

    @Published var hotKeyCombo: KeyCombo {
        didSet { save(combo: hotKeyCombo) }
    }

    @Published var language: AppLanguage {
        didSet { defaults.set(language.rawValue, forKey: languageKey) }
    }

    @Published var themeMode: ThemeMode {
        didSet { defaults.set(themeMode.rawValue, forKey: themeKey) }
    }

    private init() {
        if let data = defaults.data(forKey: "hotkey.combo"),
           let decoded = try? JSONDecoder().decode(KeyCombo.self, from: data) {
            hotKeyCombo = decoded
        } else {
            hotKeyCombo = .defaultCombo
        }

        if let raw = defaults.string(forKey: "app.language"), let lang = AppLanguage(rawValue: raw) {
            language = lang
        } else {
            language = .english
        }

        if let raw = defaults.string(forKey: "app.theme"), let mode = ThemeMode(rawValue: raw) {
            themeMode = mode
        } else {
            themeMode = .system
        }
    }

    private func save(combo: KeyCombo) {
        if let data = try? JSONEncoder().encode(combo) {
            defaults.set(data, forKey: comboKey)
        }
    }

    func resetToDefault() {
        hotKeyCombo = .defaultCombo
    }
}

/// Tiny translation helper — English is the default; Portuguese is the only
/// other supported language for now. Call sites read the current language
/// from `SettingsStore.shared` each time, so views that observe it (via
/// `@ObservedObject`) re-render automatically when it changes.
func tr(en: String, pt: String) -> String {
    SettingsStore.shared.language == .portuguese ? pt : en
}
