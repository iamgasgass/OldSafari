import SwiftUI

struct iOS6Theme {
    // MARK: - Normal Navigation Bar & Toolbar (Skeuomorphic Steel Blue / Silver)
    static let topBarGradient = Gradient(stops: [
        .init(color: Color(red: 0.82, green: 0.85, blue: 0.89), location: 0.0),
        .init(color: Color(red: 0.70, green: 0.74, blue: 0.79), location: 0.5),
        .init(color: Color(red: 0.60, green: 0.65, blue: 0.71), location: 0.51),
        .init(color: Color(red: 0.66, green: 0.71, blue: 0.77), location: 1.0)
    ])
    
    static let bottomBarGradient = Gradient(stops: [
        .init(color: Color(red: 0.75, green: 0.79, blue: 0.84), location: 0.0),
        .init(color: Color(red: 0.61, green: 0.66, blue: 0.72), location: 0.5),
        .init(color: Color(red: 0.50, green: 0.56, blue: 0.63), location: 0.51),
        .init(color: Color(red: 0.57, green: 0.63, blue: 0.70), location: 1.0)
    ])
    
    // MARK: - Private Browsing Dark Skeuo Theme (iOS 6 Ultra-Skeuo Black Slate)
    static let privateTopBarGradient = Gradient(stops: [
        .init(color: Color(red: 0.28, green: 0.29, blue: 0.31), location: 0.0),
        .init(color: Color(red: 0.18, green: 0.19, blue: 0.20), location: 0.5),
        .init(color: Color(red: 0.10, green: 0.11, blue: 0.12), location: 0.51),
        .init(color: Color(red: 0.15, green: 0.16, blue: 0.17), location: 1.0)
    ])
    
    static let privateBottomBarGradient = Gradient(stops: [
        .init(color: Color(red: 0.22, green: 0.23, blue: 0.25), location: 0.0),
        .init(color: Color(red: 0.14, green: 0.15, blue: 0.16), location: 0.5),
        .init(color: Color(red: 0.07, green: 0.08, blue: 0.09), location: 0.51),
        .init(color: Color(red: 0.12, green: 0.13, blue: 0.14), location: 1.0)
    ])
    
    // MARK: - Glossy Address Bar Progress Loader (iOS 6 Blue Candy Stripe / Gloss Fill)
    static let progressBarGradient = Gradient(stops: [
        .init(color: Color(red: 0.65, green: 0.78, blue: 0.98), location: 0.0),
        .init(color: Color(red: 0.35, green: 0.55, blue: 0.88), location: 0.48),
        .init(color: Color(red: 0.18, green: 0.38, blue: 0.75), location: 0.5),
        .init(color: Color(red: 0.25, green: 0.48, blue: 0.82), location: 1.0)
    ])
    
    static let privateProgressBarGradient = Gradient(stops: [
        .init(color: Color(red: 0.45, green: 0.40, blue: 0.60), location: 0.0),
        .init(color: Color(red: 0.28, green: 0.22, blue: 0.42), location: 0.48),
        .init(color: Color(red: 0.15, green: 0.10, blue: 0.28), location: 0.5),
        .init(color: Color(red: 0.22, green: 0.16, blue: 0.35), location: 1.0)
    ])

    // MARK: - Borders & Metallic Insets
    static let topHighlight = Color.white.opacity(0.4)
    static let bottomBorder = Color(red: 0.25, green: 0.28, blue: 0.32)
    static let privateBottomBorder = Color(red: 0.02, green: 0.02, blue: 0.03)
}
