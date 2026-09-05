import SwiftUI

struct iOS6Theme {
    // MARK: - Normal Mode Colors
    static let topBarGradient = Gradient(colors: [
        Color(red: 0.88, green: 0.89, blue: 0.92),
        Color(red: 0.71, green: 0.74, blue: 0.79)
    ])
    
    static let bottomBarGradient = Gradient(colors: [
        Color(red: 0.82, green: 0.85, blue: 0.89),
        Color(red: 0.61, green: 0.65, blue: 0.71)
    ])
    
    static let addressBarInnerShadow = Color.black.opacity(0.3)
    static let progressBarGradient = Gradient(colors: [
        Color(red: 0.55, green: 0.68, blue: 0.88),
        Color(red: 0.28, green: 0.45, blue: 0.73)
    ])
    
    // MARK: - Private Mode Colors (Dark Skeuo)
    static let privateTopBarGradient = Gradient(colors: [
        Color(red: 0.22, green: 0.23, blue: 0.25),
        Color(red: 0.11, green: 0.12, blue: 0.13)
    ])
    
    static let privateBottomBarGradient = Gradient(colors: [
        Color(red: 0.18, green: 0.19, blue: 0.20),
        Color(red: 0.08, green: 0.08, blue: 0.09)
    ])
    
    static let privateProgressBarGradient = Gradient(colors: [
        Color(red: 0.40, green: 0.35, blue: 0.55),
        Color(red: 0.22, green: 0.18, blue: 0.35)
    ])
    
    // MARK: - Borders & Highlights
    static let topHighlight = Color.white.opacity(0.6)
    static let bottomBorder = Color(red: 0.40, green: 0.43, blue: 0.48)
    static let privateBottomBorder = Color.black
}
