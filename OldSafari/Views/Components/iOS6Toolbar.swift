import SwiftUI

struct iOS6Toolbar: View {
    @ObservedObject var state: SafariState
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: state.isPrivateMode ? iOS6Theme.privateBottomBarGradient : iOS6Theme.bottomBarGradient,
                startPoint: .top,
                endPoint: .bottom
            )
            .overlay(
                VStack {
                    Rectangle()
                        .fill(Color.black.opacity(0.5))
                        .frame(height: 1)
                    Spacer()
                }
            )
            
            HStack {
                Spacer()
                
                Button(action: { state.webView?.goBack() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .bold))
                }
                .disabled(!state.canGoBack)
                .buttonStyle(iOS6ButtonStyle(isPrivate: state.isPrivateMode))
                
                Spacer()
                
                Button(action: { state.webView?.goForward() }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .bold))
                }
                .disabled(!state.canGoForward)
                .buttonStyle(iOS6ButtonStyle(isPrivate: state.isPrivateMode))
                
                Spacer()
                
                Button(action: { state.showShareSheet.toggle() }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18, weight: .bold))
                }
                .buttonStyle(iOS6ButtonStyle(isPrivate: state.isPrivateMode))
                
                Spacer()
                
                Button(action: { state.showBookmarks.toggle() }) {
                    Image(systemName: "book.fill")
                        .font(.system(size: 18, weight: .bold))
                }
                .buttonStyle(iOS6ButtonStyle(isPrivate: state.isPrivateMode))
                
                Spacer()
                
                Button(action: { state.isPrivateMode.toggle() }) {
                    Image(systemName: state.isPrivateMode ? "eyeglasses" : "square.on.square")
                        .font(.system(size: 18, weight: .bold))
                }
                .buttonStyle(iOS6ButtonStyle(isPrivate: state.isPrivateMode, isActive: state.isPrivateMode))
                
                Spacer()
            }
        }
        .frame(height: 44)
    }
}
