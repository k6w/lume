import SwiftUI

/// Spacing, radius, duration, and color tokens. Single source of truth so
/// the design stays consistent as the app grows.
enum Tokens {
    enum Spacing {
        static let xs: CGFloat  = 4
        static let s:  CGFloat  = 8
        static let m:  CGFloat  = 12
        static let l:  CGFloat  = 16
        static let xl: CGFloat  = 24
        static let xxl: CGFloat = 32
    }
    enum Radius {
        static let s:  CGFloat = 8
        static let m:  CGFloat = 12
        static let l:  CGFloat = 16
        static let xl: CGFloat = 24
        static let pill: CGFloat = 999
    }
    enum Duration {
        static let snap:  Double = 0.12
        static let smooth: Double = 0.22
        static let lift:   Double = 0.36
    }
    /// Restrained, monochrome-leaning palette. One accent (`indigo`) for state
    /// (selection, focus, primary buttons). Everything else is neutral so the
    /// app reads as serious tooling, not a candy app.
    enum Brand {
        static let indigo  = Color(red: 110/255, green:  99/255, blue: 255/255)  // accent
        static let slate   = Color(red:  26/255, green:  28/255, blue:  38/255)  // tile top
        static let ink     = Color(red:  14/255, green:  15/255, blue:  20/255)  // tile bottom / dark surface
        static let bone    = Color(red: 244/255, green: 241/255, blue: 255/255)  // light text on dark
        static let mist    = Color(red: 150/255, green: 144/255, blue: 184/255)  // secondary text on dark
    }
    enum Sizing {
        /// Popover dimensions tuned for menu-bar density (≈ 7 rows + search).
        static let popoverWidth:  CGFloat = 380
        static let popoverHeight: CGFloat = 520
    }
}
