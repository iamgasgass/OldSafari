import SwiftUI

public struct iOS6Toolbar: View {
    var canGoBack: Bool
    var canGoForward: Bool
    var isPrivate: Bool
    var tabCount: Int
    var onBack: () -> Void
    var onForward: () -> Void
    var onShare: () -> Void
    var onBookmarks: () -> Void
    var onTabs: () -> Void

    public var body: some View {
        VStack(spacing: 0) {
            // Top highlight border line
            Rectangle()
                .fill(isPrivate ? Color.white.opacity(0.12) : Color.white.opacity(0.45))
                .frame(height: 1)
            
            HStack {
                Spacer()
                // Back Button
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(canGoBack ? (isPrivate ? .white : Color(red: 0.15, green: 0.18, blue: 0.22)) : Color.gray.opacity(0.4))
                        .shadow(color: canGoBack ? Color.white.opacity(0.4) : Color.clear, radius: 0, x: 0, y: 1)
                }
                .disabled(!canGoBack)
                
                Spacer()
                // Forward Button
                Button(action: onForward) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(canGoForward ? (isPrivate ? .white : Color(red: 0.15, green: 0.18, blue: 0.22)) : Color.gray.opacity(0.4))
                        .shadow(color: canGoForward ? Color.white.opacity(0.4) : Color.clear, radius: 0, x: 0, y: 1)
                }
                .disabled(!canGoForward)
                
                Spacer()
                // Share Button (iOS 6 Action Icon)
                Button(action: onShare) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(isPrivate ? .white : Color(red: 0.15, green: 0.18, blue: 0.22))
                        .shadow(color: Color.white.opacity(0.4), radius: 0, x: 0, y: 1)
                }
                
                Spacer()
                // Bookmarks Button
                Button(action: onBookmarks) {
                    Image(systemName: "book")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(isPrivate ? .white : Color(red: 0.15, green: 0.18, blue: 0.22))
                        .shadow(color: Color.white.opacity(0.4), radius: 0, x: 0, y: 1)
                }
                
                Spacer()
                // Tabs / Pages Button with badge
                Button(action: onTabs) {
                    ZStack {
                        Image(systemName: "square.on.square")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(isPrivate ? .white : Color(red: 0.15, green: 0.18, blue: 0.22))
                        
                        Text("\(tabCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(isPrivate ? Color.black : Color.white)
                            .offset(x: 1, y: 1)
                    }
                    .shadow(color: Color.white.opacity(0.4), radius: 0, x: 0, y: 1)
                }
                Spacer()
            }
            .frame(height: 43)
            .background(isPrivate ? iOS6Theme.toolbarGradientPrivate : iOS6Theme.toolbarGradientNormal)
            
            // Bottom border line
            Rectangle()
                .fill(Color.black.opacity(0.7))
                .frame(height: 1)
        }
    }
}
