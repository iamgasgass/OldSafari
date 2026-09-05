import SwiftUI
import WebKit

struct MainSafariView: View {
    @StateObject private var state = SafariState()
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                iOS6AddressBar(state: state)
                
                WebViewWrapper(state: state)
                    .edgesIgnoringSafeArea(.horizontal)
                
                iOS6Toolbar(state: state)
            }
            .background(state.isPrivateMode ? Color.black : Color.white)
            
            if state.showShareSheet {
                iOS6ShareSheet(state: state)
            }
        }
        .sheet(isPresented: $state.showBookmarks) {
            iOS6BookmarksView(state: state)
        }
    }
}

struct WebViewWrapper: UIViewRepresentable {
    @ObservedObject var state: SafariState
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        state.webView = webView
        
        if let url = URL(string: state.currentURLString) {
            webView.load(URLRequest(url: url))
        }
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebViewWrapper
        var observation: NSKeyValueObservation?
        
        init(_ parent: WebViewWrapper) {
            self.parent = parent
            super.init()
            
            DispatchQueue.main.async {
                self.observation = self.parent.state.webView?.observe(\ .estimatedProgress, options: .new) { webView, _ in
                    self.parent.state.estimatedProgress = webView.estimatedProgress
                    self.parent.state.isLoading = webView.isLoading
                    self.parent.state.canGoBack = webView.canGoBack
                    self.parent.state.canGoForward = webView.canGoForward
                    if let urlString = webView.url?.absoluteString {
                        self.parent.state.currentURLString = urlString
                        if !self.parent.state.history.contains(where: { $0.absoluteString == urlString }), let url = webView.url {
                            self.parent.state.history.append(url)
                        }
                    }
                }
            }
        }
    }
}
