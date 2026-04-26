import SwiftUI
import Observation

/// User-tunable accent color for Lume.
///
/// Single source of truth: `LumeTheme.shared`. Inject at the root of
/// every window with `.environment(LumeTheme.shared)`, then read in
/// views with `@Environment(LumeTheme.self) private var theme` and use
/// `theme.accent`. The setter writes to UserDefaults so the choice
/// survives restarts; the `@Observable` machinery makes every reading
/// view re-render the moment the picker fires.
@MainActor
@Observable
final class LumeTheme {
    static let shared = LumeTheme()
    static let accentKey = "lume.accent"

    var accent: Color {
        didSet {
            UserDefaults.standard.set(accent.hexString, forKey: Self.accentKey)
        }
    }

    private init() {
        if let hex = UserDefaults.standard.string(forKey: Self.accentKey),
           let c = Color(hex: hex) {
            self.accent = c
        } else {
            self.accent = Tokens.Brand.indigo
        }
    }
}

extension Color {
    init?(hex: String) {
        let scrubbed = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard scrubbed.count == 6, let v = UInt32(scrubbed, radix: 16) else { return nil }
        let r = Double((v >> 16) & 0xFF) / 255
        let g = Double((v >>  8) & 0xFF) / 255
        let b = Double( v        & 0xFF) / 255
        self = Color(red: r, green: g, blue: b)
    }
    var hexString: String {
        // Best-effort serialization; falls back to "#7A70FF" if the system
        // can't resolve the components (e.g. dynamic colour).
        #if canImport(AppKit)
        if let c = NSColor(self).usingColorSpace(.sRGB) {
            return String(format: "#%02X%02X%02X",
                          Int(c.redComponent * 255),
                          Int(c.greenComponent * 255),
                          Int(c.blueComponent * 255))
        }
        #endif
        return "#7A70FF"
    }
}
