import SwiftUI

struct iOS6ButtonStyle: ButtonStyle {
    var isPrivate: Bool = false
    var isActive: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .bold))
            .foregroundColor(
                isActive
                ? Color(red: 0.2, green: 0.55, blue: 0.95)
                : (isPrivate ? Color.white.opacity(0.9) : Color(red: 0.22, green: 0.27, blue: 0.33))
            )
            .shadow(
                color: isPrivate ? Color.black.opacity(0.9) : Color.white.opacity(0.7),
                radius: 0,
                x: 0,
                y: configuration.isPressed ? 0 : 1
            )
            .opacity(configuration.isPressed ? 0.4 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}
