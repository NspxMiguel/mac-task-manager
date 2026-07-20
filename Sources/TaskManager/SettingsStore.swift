import Foundation
import Combine

final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    private let defaults = UserDefaults.standard
    private let comboKey = "hotkey.combo"

    @Published var hotKeyCombo: KeyCombo {
        didSet { save(combo: hotKeyCombo) }
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: "hotkey.combo"),
           let decoded = try? JSONDecoder().decode(KeyCombo.self, from: data) {
            hotKeyCombo = decoded
        } else {
            hotKeyCombo = .defaultCombo
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
