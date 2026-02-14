import Foundation

struct ProgressStore {
    private static let prefix = "playback_progress_"

    /// Save playback position for a video URL
    static func save(time: Double, for url: URL) {
        guard time.isFinite && time > 0 else { return }
        UserDefaults.standard.set(time, forKey: key(for: url))
    }

    /// Load saved playback position for a video URL. Returns 0 if none saved.
    static func load(for url: URL) -> Double {
        UserDefaults.standard.double(forKey: key(for: url))
    }

    /// Clear saved progress for a video URL
    static func clear(for url: URL) {
        UserDefaults.standard.removeObject(forKey: key(for: url))
    }

    private static func key(for url: URL) -> String {
        prefix + url.absoluteString
    }
}
