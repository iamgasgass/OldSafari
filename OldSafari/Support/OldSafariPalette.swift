import SwiftUI

/// Centralized palette for the OldOS 2.0.8 Safari chrome. The same chrome
/// gradient is intentionally reused at the top and bottom so the standalone
/// extraction retains the original visual language.
enum OldSafariPalette {
    static let chromeTop = Color(red: 0.90, green: 0.92, blue: 0.95)
    static let chromeBottom = Color(red: 0.42, green: 0.52, blue: 0.66)

    static let chromeTopPrivate = Color(red: 0.16, green: 0.16, blue: 0.20)
    static let chromeBottomPrivate = Color(red: 0.05, green: 0.05, blue: 0.08)

    static let fieldTop = Color.white
    static let fieldBottom = Color(red: 0.88, green: 0.90, blue: 0.93)
    static let fieldBorder = Color(red: 0.30, green: 0.40, blue: 0.52)

    static let fieldTopPrivate = Color(red: 0.24, green: 0.24, blue: 0.27)
    static let fieldBottomPrivate = Color(red: 0.10, green: 0.10, blue: 0.12)
    static let fieldBorderPrivate = Color(red: 0.45, green: 0.45, blue: 0.50)

    static let tabsBackgroundTop = Color(red: 0.58, green: 0.63, blue: 0.68)
    static let tabsBackgroundBottom = Color(red: 0.34, green: 0.41, blue: 0.48)

    static let tabsBackgroundTopPrivate = Color(red: 0.10, green: 0.10, blue: 0.12)
    static let tabsBackgroundBottomPrivate = Color.black

    static let progressTint = Color(red: 0.20, green: 0.47, blue: 0.93)
    static let placeholderText = Color(red: 0.40, green: 0.40, blue: 0.40)
    static let hairline = Color.black.opacity(0.7)
}
