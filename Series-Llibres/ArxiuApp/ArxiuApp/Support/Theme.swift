import UIKit
import SwiftUI

/// Paleta traduïda de les variables CSS de l'HTML original, adaptada a mode clar i fosc.
enum Theme {
    static let bg          = Color("ThemeBG",        light: 0xFBFBFA, dark: 0x0F1012)
    static let panel       = Color("ThemePanel",     light: 0xFFFFFF, dark: 0x1B1D20)
    static let line        = Color("ThemeLine",      light: 0xE7E5E0, dark: 0x2E3135)
    static let ink         = Color("ThemeInk",       light: 0x22231F, dark: 0xF2F2F0)
    static let inkDim      = Color("ThemeInkDim",    light: 0x6B6A63, dark: 0x9C9E9F)
    static let inkFaint    = Color("ThemeInkFaint",  light: 0xA3A199, dark: 0x6E7174)
    static let accent      = Color("ThemeAccent",    light: 0x3F6659, dark: 0x6FA792)
    static let accentSoft  = Color("ThemeAccentSoft",light: 0xE6EDE9, dark: 0x22322C)
    static let danger      = Color("ThemeDanger",    light: 0xB3554A, dark: 0xE0786B)
    static let inProgress  = Color("ThemeProgress",  light: 0xA9834F, dark: 0xD3A667)

    /// Colors dels tiles i de les etiquetes de tipus, alineats amb la icona de l'app.
    static let serieTint   = Color(hex: 0x2C7BE5)
    static let peliTint    = Color(hex: 0xE23B32)
    static let llibreTint  = Color(hex: 0x7C4DE0)
    static let allTint     = Color(hex: 0x3FA9A0)
    static let progressTint = Color(hex: 0xE9903B)

    static let tileCorner: CGFloat = 18
    static let tileHeight: CGFloat = 96
    static let smallTileHeight: CGFloat = 58
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >>  8) & 0xFF) / 255,
            blue:  Double( hex        & 0xFF) / 255,
            opacity: 1
        )
    }

    /// Color dinàmic clar/fosc sense necessitat d'entrades al catàleg d'assets.
    init(_ name: String, light: UInt32, dark: UInt32) {
        self.init(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(Color(hex: dark))
                : UIColor(Color(hex: light))
        })
    }
}
