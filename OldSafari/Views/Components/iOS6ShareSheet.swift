import SwiftUI

struct iOS6ShareSheet: View {
    @ObservedObject var state: SafariState
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    state.showShareSheet = false
                }
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 10) {
                    Text(state.pageTitle.isEmpty ? state.currentURLString : state.pageTitle)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: .black, radius: 1, x: 0, y: 1)
                        .lineLimit(1)
                        .padding(.top, 10)
                        .padding(.horizontal, 10)
                    
                    VStack(spacing: 8) {
                        Button("Add Bookmark") {
                            if let url = URL(string: state.currentURLString) {
                                state.bookmarks.append(url)
                            }
                            state.showShareSheet = false
                        }
                        .buttonStyle(iOS6ActionSheetButtonStyle(isCancel: false))
                        
                        Button("Add to Reading List") {
                            state.showShareSheet = false
                        }
                        .buttonStyle(iOS6ActionSheetButtonStyle(isCancel: false))
                        
                        Button("Add to Home Screen") {
                            state.showShareSheet = false
                        }
                        .buttonStyle(iOS6ActionSheetButtonStyle(isCancel: false))
                        
                        Button("Copy Link") {
                            UIPasteboard.general.string = state.currentURLString
                            state.showShareSheet = false
                        }
                        .buttonStyle(iOS6ActionSheetButtonStyle(isCancel: false))
                        
                        Button("Cancel") {
                            state.showShareSheet = false
                        }
                        .buttonStyle(iOS6ActionSheetButtonStyle(isCancel: true))
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
                .background(
                    ZStack {
                        // iOS 6 Classic Action Sheet Translucent Dark Linen/Glass
                        Color(red: 0.12, green: 0.14, blue: 0.18).opacity(0.95)
                        
                        VStack {
                            Rectangle()
                                .fill(Color.white.opacity(0.3))
                                .frame(height: 1)
                            Spacer()
                        }
                    }
                )
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.black, lineWidth: 1)
                )
                .padding(.horizontal, 10)
                .padding(.bottom, 15)
            }
        }
    }
}

struct iOS6ActionSheetButtonStyle: ButtonStyle {
    var isCancel: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.white)
            .shadow(color: .black.opacity(0.8), radius: 0, x: 0, y: -1)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(
                ZStack {
                    LinearGradient(
                        gradient: isCancel
                        ? Gradient(stops: [
                            .init(color: Color(red: 0.45, green: 0.15, blue: 0.15), location: 0.0),
                            .init(color: Color(red: 0.25, green: 0.05, blue: 0.05), location: 0.5),
                            .init(color: Color(red: 0.15, green: 0.02, blue: 0.02), location: 0.51),
                            .init(color: Color(red: 0.22, green: 0.05, blue: 0.05), location: 1.0)
                        ])
                        : Gradient(stops: [
                            .init(color: Color(red: 0.42, green: 0.45, blue: 0.50), location: 0.0),
                            .init(color: Color(red: 0.25, green: 0.28, blue: 0.33), location: 0.5),
                            .init(color: Color(red: 0.15, green: 0.18, blue: 0.22), location: 0.51),
                            .init(color: Color(red: 0.22, green: 0.25, blue: 0.30), location: 1.0)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.black, lineWidth: 1)
                }
            )
            .cornerRadius(6)
            .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
            .opacity(configuration.isPressed ? 0.6 : 1.0)
    }
}
