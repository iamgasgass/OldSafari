import SwiftUI

public struct AddressBarView: View {
    @Binding var urlText: String
    @Binding var isLoading: Bool
    @Binding var progress: Double
    var isPrivate: Bool
    var onCommit: () -> Void
    var onReloadOrStop: () -> Void
    
    @FocusState private var isFocused: Bool

    public var body: some View {
        ZStack(alignment: .leading) {
            // Container background with inner shadow box
            RoundedRectangle(cornerRadius: 5)
                .fill(isPrivate ? Color(red: 0.12, green: 0.13, blue: 0.15) : Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.black.opacity(0.55), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.3), radius: 1, x: 0, y: 1)
            
            // iOS 6 Pixel-Perfect Loading Progress Fill
            if isLoading && progress > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(iOS6Theme.progressGradient)
                            .frame(width: max(10, geo.size.width * CGFloat(progress)))
                        
                        // Glass glossy sheen line across the top half of progress bar
                        VStack {
                            Rectangle()
                                .fill(Color.white.opacity(0.35))
                                .frame(width: max(10, geo.size.width * CGFloat(progress)), height: geo.size.height * 0.48)
                            Spacer()
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                .padding(1)
                .animation(.easeOut(duration: 0.25), value: progress)
            }
            
            // Input TextField and Reload/Stop Button
            HStack(spacing: 4) {
                // Lock icon if SSL
                if urlText.hasPrefix("https://") {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(isPrivate ? Color.gray : Color.gray)
                        .padding(.leading, 6)
                }
                
                TextField("Cerca o inserisci un indirizzo", text: $urlText, onCommit: {
                    isFocused = false
                    onCommit()
                })
                .focused($isFocused)
                .font(.system(size: 13, weight: .regular, design: .default))
                .foregroundColor(isPrivate ? .white : .black)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .keyboardType(.URL)
                .padding(.leading, urlText.hasPrefix("https://") ? 0 : 8)
                
                Spacer()
                
                // Clear button when focused and typing
                if isFocused && !urlText.isEmpty {
                    Button(action: { urlText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(isPrivate ? .gray : Color(red: 0.5, green: 0.5, blue: 0.55))
                    }
                    .padding(.trailing, 4)
                }
                
                // Reload / Stop Button inside URL Field (iOS 6 Style)
                Button(action: onReloadOrStop) {
                    Image(systemName: isLoading ? "xmark" : "arrow.clockwise")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(isPrivate ? Color.white.opacity(0.8) : Color(red: 0.3, green: 0.3, blue: 0.35))
                        .frame(width: 24, height: 24)
                }
                .padding(.trailing, 4)
            }
        }
        .frame(height: 28)
    }
}
