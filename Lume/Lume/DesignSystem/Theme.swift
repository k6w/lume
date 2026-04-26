import SwiftUI

/// Brand accent color, persisted to UserDefaults under `LumeTheme.accentKey`.
///
/// Views read it with the `@LumeAccent` property wrapper (declared below):
///
///     @LumeAccent private var accent
///
/// The wrapper is built on top of `@AppStorage`, so every view in every
/// hosting controller — popover, main window, settings, onboarding —
/// re-renders the moment the user moves the picker. SwiftUI broadcasts
/// UserDefaults changes process-wide, which is the *only* mechanism that
/// reliably crosses between independent `NSHostingController`s.
enum LumeTheme {
    static let accentKey = "lume.accent"
    static let defaultHex = "#7A70FF"

    /// Static convenience for non-View callers (e.g. AppKit code).
    static var accent: Color {
        get {
            if let hex = UserDefaults.standard.string(forKey: accentKey),
               let c = Color(hex: hex) {
                return c
            }
            return Tokens.Brand.indigo
        }
        set {
            UserDefaults.standard.set(newValue.hexString, forKey: accentKey)
        }
    }
}

/// Property wrapper that reads `LumeTheme.accentKey` from UserDefaults via
/// `@AppStorage` and returns it as a `Color`. Adopting `DynamicProperty`
/// lets SwiftUI observe the underlying storage and re-render the host view
/// whenever the value changes — no `@Observable` plumbing needed.
@MainActor
@propertyWrapper
struct LumeAccent: DynamicProperty {
    @AppStorage(LumeTheme.accentKey) private var hex: String = LumeTheme.defaultHex

    var wrappedValue: Color {
        Color(hex: hex) ?? Tokens.Brand.indigo
    }

    /// Two-way `Binding<Color>` for callers that need to drive a
    /// `ColorPicker`. Reading uses the same hex storage; writing converts
    /// the new colour back to a hex string and writes it through.
    var projectedValue: Binding<Color> {
        Binding(
            get: { Color(hex: hex) ?? Tokens.Brand.indigo },
            set: { hex = $0.hexString }
        )
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
        #if canImport(AppKit)
        if let c = NSColor(self).usingColorSpace(.sRGB) {
            return String(format: "#%02X%02X%02X",
                          Int(c.redComponent * 255),
                          Int(c.greenComponent * 255),
                          Int(c.blueComponent * 255))
        }
        #endif
        return LumeTheme.defaultHex
    }
}
