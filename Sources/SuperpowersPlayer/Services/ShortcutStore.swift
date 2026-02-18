import Foundation

/// Persists custom keyboard shortcuts to UserDefaults.
/// Follows the same pattern as ProgressStore.
struct ShortcutStore {
    private static let key = "custom_keyboard_shortcuts"

    /// Save all bindings.
    static func save(_ bindings: [PlayerAction: StoredKeyBinding]) {
        guard let data = try? JSONEncoder().encode(bindings) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    /// Load saved bindings, or nil if none saved.
    static func load() -> [PlayerAction: StoredKeyBinding]? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let bindings = try? JSONDecoder().decode(
                  [PlayerAction: StoredKeyBinding].self, from: data
              )
        else { return nil }
        return bindings
    }

    /// Clear all custom bindings (revert to defaults).
    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
