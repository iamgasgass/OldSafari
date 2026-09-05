import SwiftUI

struct iOS6ButtonStyle: ButtonStyle {
    var isPrivate: Bool = false
    var isActive: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(
                isActive ? .blue : (isPrivate ? Color.white : Color(red: 0.2, green: 0.25, blue: 0.3))
            )
            .shadow(color: isPrivate ? .black : .white.opacity(0.8), x: 0, y: 1)
            .opacity(configuration.isPressed ? 0.5 : 1.0)
    }
}
