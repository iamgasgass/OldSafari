import SwiftUI

// MARK: - iOS 6 Colors & Gradients
public struct iOS6Theme {
    // Normal Mode Navigation Bar Gradient
    public static let navBarGradientNormal = LinearGradient(
        gradient: Gradient(stops: [
            .init(color: Color(red: 0.82, green: 0.85, blue: 0.88), location: 0.0),
            .init(color: Color(red: 0.68, green: 0.72, blue: 0.76), location: 0.5),
            .init(color: Color(red: 0.60, green: 0.64, blue: 0.69), location: 0.51),
            .init(color: Color(red: 0.65, green: 0.70, blue: 0.75), location: 1.0)
        ]),
        startPoint: .top,
        endPoint: .bottom
    )
    
    // Private Browsing Mode Navigation Bar Gradient (Dark Metallic / Charcoal)
    public static let navBarGradientPrivate = LinearGradient(
        gradient: Gradient(stops: [
            .init(color: Color(red: 0.28, green: 0.30, blue: 0.34), location: 0.0),
            .init(color: Color(red: 0.18, green: 0.20, blue: 0.23), location: 0.5),
            .init(color: Color(red: 0.12, green: 0.13, blue: 0.16), location: 0.51),
            .init(color: Color(red: 0.16, green: 0.18, blue: 0.21), location: 1.0)
        ]),
        startPoint: .top,
        endPoint: .bottom
    )
    
    // Bottom Toolbar Metallic Background Normal
    public static let toolbarGradientNormal = LinearGradient(
        gradient: Gradient(stops: [
            .init(color: Color(red: 0.85, green: 0.87, blue: 0.90), location: 0.0),
            .init(color: Color(red: 0.70, green: 0.74, blue: 0.78), location: 0.49),
            .init(color: Color(red: 0.62, green: 0.66, blue: 0.71), location: 0.50),
            .init(color: Color(red: 0.66, green: 0.70, blue: 0.75), location: 1.0)
        ]),
        startPoint: .top,
        endPoint: .bottom
    )
    
    // Bottom Toolbar Metallic Background Private
    public static let toolbarGradientPrivate = LinearGradient(
        gradient: Gradient(stops: [
            .init(color: Color(red: 0.25, green: 0.27, blue: 0.30), location: 0.0),
            .init(color: Color(red: 0.16, green: 0.18, blue: 0.20), location: 0.49),
            .init(color: Color(red: 0.10, green: 0.11, blue: 0.13), location: 0.50),
            .init(color: Color(red: 0.14, green: 0.15, blue: 0.18), location: 1.0)
        ]),
        startPoint: .top,
        endPoint: .bottom
    )

    // iOS 6 Progress Fill Gradient (Glossy Blue)
    public static let progressGradient = LinearGradient(
        gradient: Gradient(stops: [
            .init(color: Color(red: 0.78, green: 0.87, blue: 0.98), location: 0.0),
            .init(color: Color(red: 0.42, green: 0.65, blue: 0.94), location: 0.48),
            .init(color: Color(red: 0.22, green: 0.48, blue: 0.88), location: 0.49),
            .init(color: Color(red: 0.30, green: 0.56, blue: 0.92), location: 1.0)
        ]),
        startPoint: .top,
        endPoint: .bottom
    )
    
    // Action Sheet Gradient iOS 6
    public static let actionSheetBackground = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 0.18, green: 0.20, blue: 0.24).opacity(0.95),
            Color(red: 0.08, green: 0.09, blue: 0.12).opacity(0.98)
        ]),
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - iOS 6 Custom Button Shapes & Styles
public struct iOS6NavBackButtonShape: Shape {
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let cornerRadius: CGFloat = 4.0
        let arrowWidth: CGFloat = 13.0
        
        path.move(to: CGPoint(x: arrowWidth, y: 0))
        path.addLine(to: CGPoint(x: rect.width - cornerRadius, y: 0))
        path.addArc(center: CGPoint(x: rect.width - cornerRadius, y: cornerRadius), radius: cornerRadius, startAngle: Angle(degrees: -90), endAngle: Angle(degrees: 0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.width, y: rect.height - cornerRadius))
        path.addArc(center: CGPoint(x: rect.width - cornerRadius, y: rect.height - cornerRadius), radius: cornerRadius, startAngle: Angle(degrees: 0), endAngle: Angle(degrees: 90), clockwise: false)
        path.addLine(to: CGPoint(x: arrowWidth, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height / 2))
        path.closeSubpath()
        return path
    }
}

public struct iOS6ButtonStyle: ButtonStyle {
    var isPrivate: Bool = false
    var isBlue: Bool = false
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                ZStack {
                    if isBlue {
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color(red: 0.55, green: 0.72, blue: 0.95), location: 0.0),
                                .init(color: Color(red: 0.25, green: 0.50, blue: 0.88), location: 0.49),
                                .init(color: Color(red: 0.10, green: 0.38, blue: 0.82), location: 0.50),
                                .init(color: Color(red: 0.18, green: 0.46, blue: 0.86), location: 1.0)
                            ]),
                            startPoint: .top, endPoint: .bottom
                        )
                    } else if isPrivate {
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color(red: 0.40, green: 0.42, blue: 0.46), location: 0.0),
                                .init(color: Color(red: 0.22, green: 0.24, blue: 0.28), location: 0.49),
                                .init(color: Color(red: 0.14, green: 0.16, blue: 0.19), location: 0.50),
                                .init(color: Color(red: 0.18, green: 0.20, blue: 0.23), location: 1.0)
                            ]),
                            startPoint: .top, endPoint: .bottom
                        )
                    } else {
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color(red: 0.58, green: 0.62, blue: 0.67), location: 0.0),
                                .init(color: Color(red: 0.38, green: 0.42, blue: 0.47), location: 0.49),
                                .init(color: Color(red: 0.28, green: 0.31, blue: 0.36), location: 0.50),
                                .init(color: Color(red: 0.32, green: 0.36, blue: 0.41), location: 1.0)
                            ]),
                            startPoint: .top, endPoint: .bottom
                        )
                    }
                }
            )
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.black.opacity(0.6), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.3), radius: 1, x: 0, y: 1)
            .opacity(configuration.isPressed ? 0.75 : 1.0)
    }
}

// MARK: - iOS 6 Linen Background View Modifier
public struct iOS6LinenBackground: ViewModifier {
    var isPrivate: Bool
    
    public func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    if isPrivate {
                        Color(red: 0.10, green: 0.11, blue: 0.13)
                    } else {
                        Color(red: 0.85, green: 0.87, blue: 0.90)
                    }
                }
                .edgesIgnoringSafeArea(.all)
            )
    }
}

extension View {
    public func ios6LinenBackground(isPrivate: Bool) -> some View {
        self.modifier(iOS6LinenBackground(isPrivate: isPrivate))
    }
}
