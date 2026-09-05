import SwiftUI

public struct iOS6ActionSheet: View {
    @Binding var isPresented: Bool
    var isPrivate: Bool
    var pageTitle: String
    var pageURL: String
    var onAddBookmark: () -> Void
    var onAddToHomeScreen: () -> Void
    var onCopyLink: () -> Void

    public var body: some View {
        ZStack(alignment: .bottom) {
            // Darkened scrim backdrop
            if isPresented {
                Color.black.opacity(0.55)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.2)) {
                            isPresented = false
                        }
                    }
                    .transition(.opacity)
                
                VStack(spacing: 12) {
                    // Title section
                    if !pageTitle.isEmpty {
                        Text(pageTitle)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .padding(.top, 8)
                            .shadow(color: .black, radius: 1, x: 0, y: 1)
                    }
                    
                    VStack(spacing: 10) {
                        // Action: Add Bookmark
                        Button(action: {
                            onAddBookmark()
                            withAnimation { isPresented = false }
                        }) {
                            Text("Aggiungi a Segnalibri")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(stops: [
                                            .init(color: Color(red: 0.40, green: 0.44, blue: 0.50), location: 0.0),
                                            .init(color: Color(red: 0.20, green: 0.24, blue: 0.30), location: 0.49),
                                            .init(color: Color(red: 0.10, green: 0.12, blue: 0.16), location: 0.50),
                                            .init(color: Color(red: 0.15, green: 0.18, blue: 0.22), location: 1.0)
                                        ]),
                                        startPoint: .top, endPoint: .bottom
                                    )
                                )
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.black.opacity(0.8), lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                        }
                        
                        // Action: Copy Link
                        Button(action: {
                            onCopyLink()
                            withAnimation { isPresented = false }
                        }) {
                            Text("Copia Link")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(stops: [
                                            .init(color: Color(red: 0.40, green: 0.44, blue: 0.50), location: 0.0),
                                            .init(color: Color(red: 0.20, green: 0.24, blue: 0.30), location: 0.49),
                                            .init(color: Color(red: 0.10, green: 0.12, blue: 0.16), location: 0.50),
                                            .init(color: Color(red: 0.15, green: 0.18, blue: 0.22), location: 1.0)
                                        ]),
                                        startPoint: .top, endPoint: .bottom
                                    )
                                )
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.black.opacity(0.8), lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                        }
                        
                        // Action: Cancel (Dark Glossy Button)
                        Button(action: {
                            withAnimation { isPresented = false }
                        }) {
                            Text("Annulla")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(stops: [
                                            .init(color: Color(red: 0.28, green: 0.30, blue: 0.34), location: 0.0),
                                            .init(color: Color(red: 0.15, green: 0.16, blue: 0.18), location: 0.49),
                                            .init(color: Color(red: 0.05, green: 0.06, blue: 0.08), location: 0.50),
                                            .init(color: Color(red: 0.08, green: 0.09, blue: 0.11), location: 1.0)
                                        ]),
                                        startPoint: .top, endPoint: .bottom
                                    )
                                )
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.black.opacity(0.9), lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                        }
                    }
                }
                .padding(16)
                .background(iOS6Theme.actionSheetBackground)
                .cornerRadius(12, corners: [.topLeft, .topRight])
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.8), radius: 10, x: 0, y: -4)
                .transition(.move(edge: .bottom))
            }
        }
    }
}

// Extension to allow specific corner rounding
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCorner(radius: radius, corners: corners) )
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
