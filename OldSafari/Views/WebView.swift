import SwiftUI
import WebKit

public struct SafariWebView: UIViewRepresentable {
    @Binding var urlString: String
    @Binding var isLoading: Bool
    @Binding var progress: Double
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var pageTitle: String
    var isPrivate: Bool

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        if isPrivate {
            config.websiteDataStore = .nonPersistent()
        }
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        
        // iOS 6 User Agent
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 6_1_3 like Mac OS X) AppleWebKit/536.26 (KHTML, like Gecko) Version/6.0 Mobile/10B329 Safari/8536.25"
        
        context.coordinator.setupObservers(for: webView)
        
        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        }
        
        return webView
    }

    public func updateUIView(_ uiView: WKWebView, context: Context) {
        if let currentURL = uiView.url?.absoluteString, currentURL != urlString, let newURL = URL(string: urlString) {
            uiView.load(URLRequest(url: newURL))
        }
    }

    public class Coordinator: NSObject, WKNavigationDelegate {
        var parent: SafariWebView
        var progressObserver: NSKeyValueObservation?
        var titleObserver: NSKeyValueObservation?
        var urlObserver: NSKeyValueObservation?

        init(_ parent: SafariWebView) {
            self.parent = parent
        }

        func setupObservers(for webView: WKWebView) {
            progressObserver = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] wv, _ in
                DispatchQueue.main.async {
                    self?.parent.progress = wv.estimatedProgress
                }
            }
            
            titleObserver = webView.observe(\.title, options: [.new]) { [weak self] wv, _ in
                DispatchQueue.main.async {
                    if let t = wv.title {
                        self?.parent.pageTitle = t
                    }
                }
            }
            
            urlObserver = webView.observe(\.url, options: [.new]) { [weak self] wv, _ in
                DispatchQueue.main.async {
                    if let url = wv.url?.absoluteString {
                        self?.parent.urlString = url
                        SafariDataManager.shared.addHistory(title: wv.title ?? url, url: url)
                    }
                    self?.parent.canGoBack = wv.canGoBack
                    self?.parent.canGoForward = wv.canGoForward
                }
            }
        }

        public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
                self.parent.progress = 0.1
            }
        }

        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.progress = 1.0
                if let url = webView.url?.absoluteString {
                    self.parent.urlString = url
                }
            }
        }

        public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }
    }
}
