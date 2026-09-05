import SwiftUI

struct iOS6ShareSheet: View {
    @ObservedObject var state: SafariState
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    state.showShareSheet = false
                }
            
            VStack(spacing: 10) {
                Spacer()
                
                VStack(spacing: 8) {
                    Text("Condividi o Aggiungi")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.top, 8)
                    
                    Button("Aggiungi a Segnalibri") {
                        if let url = URL(string: state.currentURLString) {
                            state.bookmarks.append(url)
                        }
                        state.showShareSheet = false
                    }
                    .buttonStyle(iOS6ActionSheetButtonStyle(isCancel: false))
                    
                    Button("Copia Link") {
                        UIPasteboard.general.string = state.currentURLString
                        state.showShareSheet = false
                    }
                    .buttonStyle(iOS6ActionSheetButtonStyle(isCancel: false))
                    
                    Button("Annulla") {
                        state.showShareSheet = false
                    }
                    .buttonStyle(iOS6ActionSheetButtonStyle(isCancel: true))
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(white: 0.15).opacity(0.95))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.2), lineWidth: 1))
                )
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
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
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(
                LinearGradient(
                    gradient: isCancel ? Gradient(colors: [Color(red: 0.5, green: 0.1, blue: 0.1), Color(red: 0.3, green: 0.0, blue: 0.0)]) : Gradient(colors: [Color(white: 0.35), Color(white: 0.20)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.black, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}
