import SwiftUI
import UIKit
import WebKit

struct SafariWebView: UIViewRepresentable {
    @ObservedObject var tab: SafariTab

    func makeUIView(context: Context) -> WKWebView {
        let webView = tab.webView
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        if #available(iOS 16.0, *) {
            webView.isFindInteractionEnabled = true
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        /// Same-tab navigation for target="_blank" links / window.open,
        /// since this browser intentionally has no separate popup windows.
        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
                webView.load(URLRequest(url: url))
            }
            return nil
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url, let scheme = url.scheme?.lowercased() else {
                decisionHandler(.allow)
                return
            }
            // Hand off schemes WKWebView can't itself load (tel:, mailto:,
            // facetime:, sms:, maps:, custom app schemes, App Store links…)
            // to the system, exactly like real Safari does.
            let webHandledSchemes: Set<String> = ["http", "https", "about", "blob", "data", "file"]
            if !webHandledSchemes.contains(scheme) {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation?, withError error: Error) {
            // Ignore benign "frame load interrupted" (-999) from fast
            // back/forward taps; anything else could still be surfaced later.
        }
    }
}
