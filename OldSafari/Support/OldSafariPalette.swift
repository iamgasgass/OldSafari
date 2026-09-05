import SwiftUI

/// Shared visual tokens for the OldOS Safari chrome.
enum OldSafariPalette {
    // Brushed aluminium / blue-grey Safari chrome.
    static let chromeTop = Color(red: 0.91, green: 0.93, blue: 0.96)
    static let chromeBottom = Color(red: 0.43, green: 0.53, blue: 0.67)

    // Private Pages uses the same geometry and highlights, but a charcoal
    // aluminium treatment instead of modern translucent dark materials.
    static let chromeTopPrivate = Color(red: 0.29, green: 0.30, blue: 0.34)
    static let chromeBottomPrivate = Color(red: 0.075, green: 0.075, blue: 0.10)

    static let fieldTop = Color.white
    static let fieldBottom = Color(red: 0.87, green: 0.90, blue: 0.94)
    static let fieldBorder = Color(red: 0.28, green: 0.37, blue: 0.49)

    static let fieldTopPrivate = Color(red: 0.24, green: 0.25, blue: 0.28)
    static let fieldBottomPrivate = Color(red: 0.10, green: 0.10, blue: 0.12)
    static let fieldBorderPrivate = Color(red: 0.47, green: 0.48, blue: 0.53)

    static let tabsBackgroundTop = Color(red: 0.60, green: 0.65, blue: 0.70)
    static let tabsBackgroundBottom = Color(red: 0.34, green: 0.41, blue: 0.48)
    static let tabsBackgroundTopPrivate = Color(red: 0.11, green: 0.11, blue: 0.14)
    static let tabsBackgroundBottomPrivate = Color.black

    static let progressTint = Color(red: 0.17, green: 0.42, blue: 0.90)
    static let placeholderText = Color(red: 0.39, green: 0.40, blue: 0.42)
    static let hairline = Color.black.opacity(0.70)
}
