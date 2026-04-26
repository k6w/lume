import SwiftUI

/// Single user-tunable token: the accent colour. Liquid Glass owns
/// light/dark, contrast, and vibrancy; we don't fight the system.
struct LumeTheme {
    static let accentKey = "lume.accent"

    static var accent: Color {
        get {
            if let hex = UserDefaults.standard.string(forKey: accentKey),
               let c = Color(hex: hex) { return c }
            return Tokens.Brand.indigo
        }
        set {
            UserDefaults.standard.set(newValue.hexString, forKey: accentKey)
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
        // Best-effort serialization; falls back to "#9B8CFF" if the system
        // can't resolve the components (e.g. dynamic colour).
        #if canImport(AppKit)
        if let c = NSColor(self).usingColorSpace(.sRGB) {
            return String(format: "#%02X%02X%02X",
                          Int(c.redComponent * 255),
                          Int(c.greenComponent * 255),
                          Int(c.blueComponent * 255))
        }
        #endif
        return "#9B8CFF"
    }
}
