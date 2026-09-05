import SwiftUI

struct iOS6Toolbar: View {
    @ObservedObject var state: SafariState
    
    var body: some View {
        ZStack {
            // Skeuomorphic Metallic Bottom Bar
            LinearGradient(
                gradient: state.isPrivateMode ? iOS6Theme.privateBottomBarGradient : iOS6Theme.bottomBarGradient,
                startPoint: .top,
                endPoint: .bottom
            )
            .overlay(
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.black.opacity(0.6))
                        .frame(height: 1)
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 1)
                    Spacer()
                }
            )
            
            HStack {
                Spacer()
                
                // Back Button
                Button(action: { state.webView?.goBack() }) {
                    Image(systemName: "chevron.left")
                }
                .disabled(!state.canGoBack)
                .buttonStyle(iOS6ButtonStyle(isPrivate: state.isPrivateMode))
                
                Spacer()
                
                // Forward Button
                Button(action: { state.webView?.goForward() }) {
                    Image(systemName: "chevron.right")
                }
                .disabled(!state.canGoForward)
                .buttonStyle(iOS6ButtonStyle(isPrivate: state.isPrivateMode))
                
                Spacer()
                
                // Action / Share Sheet Button
                Button(action: { state.showShareSheet.toggle() }) {
                    Image(systemName: "square.and.arrow.up")
                }
                .buttonStyle(iOS6ButtonStyle(isPrivate: state.isPrivateMode))
                
                Spacer()
                
                // Bookmarks & History Button
                Button(action: { state.showBookmarks.toggle() }) {
                    Image(systemName: "book.fill")
                }
                .buttonStyle(iOS6ButtonStyle(isPrivate: state.isPrivateMode))
                
                Spacer()
                
                // Tab Manager / Private Browsing Toggle Button
                Button(action: { state.isPrivateMode.toggle() }) {
                    ZStack {
                        Image(systemName: "square.on.square")
                        if state.isPrivateMode {
                            Image(systemName: "eyeglasses")
                                .font(.system(size: 10, weight: .bold))
                                .offset(y: 1)
                        }
                    }
                }
                .buttonStyle(iOS6ButtonStyle(isPrivate: state.isPrivateMode, isActive: state.isPrivateMode))
                
                Spacer()
            }
        }
        .frame(height: 44)
    }
}
