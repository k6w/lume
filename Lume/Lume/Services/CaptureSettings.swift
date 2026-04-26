import Foundation

/// User-tunable capture and retention policy.
///
/// Defaults are conservative on disk: text + colors + files (paths only —
/// effectively free) are captured automatically. Images are opt-in
/// because the actual pixel data lives in the database and would balloon
/// it. When a kind is enabled, it gets its own retention window.
enum CaptureSettings {
    enum Key: String {
        case captureImages       = "lume.capture.images"
        case retentionText       = "lume.retention.text"
        case retentionImages     = "lume.retention.images"
        case retentionFiles      = "lume.retention.files"
        case retentionColors     = "lume.retention.colors"
    }

    // Toggles
    static var captureImages: Bool {
        get { UserDefaults.standard.bool(forKey: Key.captureImages.rawValue) }
        set { UserDefaults.standard.set(newValue, forKey: Key.captureImages.rawValue) }
    }

    // Retention (days, ≥ 1)
    static var retentionText: Int {
        get { UserDefaults.standard.integer(forKey: Key.retentionText.rawValue).orDefault(30) }
        set { UserDefaults.standard.set(max(1, newValue), forKey: Key.retentionText.rawValue) }
    }
    static var retentionImages: Int {
        get { UserDefaults.standard.integer(forKey: Key.retentionImages.rawValue).orDefault(7) }
        set { UserDefaults.standard.set(max(1, newValue), forKey: Key.retentionImages.rawValue) }
    }
    static var retentionFiles: Int {
        get { UserDefaults.standard.integer(forKey: Key.retentionFiles.rawValue).orDefault(14) }
        set { UserDefaults.standard.set(max(1, newValue), forKey: Key.retentionFiles.rawValue) }
    }
    static var retentionColors: Int {
        get { UserDefaults.standard.integer(forKey: Key.retentionColors.rawValue).orDefault(90) }
        set { UserDefaults.standard.set(max(1, newValue), forKey: Key.retentionColors.rawValue) }
    }

    /// Days for the kind, or `nil` to mean "never purge by age".
    static func retentionDays(for kind: ClipKind) -> Int {
        switch kind {
        case .image:  return retentionImages
        case .file:   return retentionFiles
        case .color:  return retentionColors
        default:      return retentionText      // text, rtf, html, code
        }
    }
}

private extension Int {
    func orDefault(_ d: Int) -> Int { self == 0 ? d : self }
}
