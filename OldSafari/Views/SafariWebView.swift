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

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // WKWebView is owned by SafariTab. Recreating or reloading it from
        // SwiftUI updates would destroy scroll position and navigation state.
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            // OldOS Safari did not expose a separate popup window. Keep
            // target=_blank/window.open navigation inside the current page.
            if navigationAction.targetFrame == nil,
               let url = navigationAction.request.url {
                webView.load(URLRequest(url: url))
            }
            return nil
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard
                let url = navigationAction.request.url,
                let scheme = url.scheme?.lowercased()
            else {
                decisionHandler(.allow)
                return
            }

            let webHandledSchemes: Set<String> = [
                "http", "https", "about", "blob", "data", "file"
            ]

            if !webHandledSchemes.contains(scheme) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation?,
            withError error: Error
        ) {
            // NSURLErrorCancelled (-999) is expected for interrupted loads.
            // WKWebView has no useful UI state to expose for it.
        }
    }
}
