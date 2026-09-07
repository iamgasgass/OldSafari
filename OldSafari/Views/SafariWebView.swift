import SwiftUI
import UIKit
import WebKit

struct SafariWebView: UIViewRepresentable {
    @ObservedObject var tab: SafariTab

    /// Set by the browser chrome so a long press on a link can open it in a
    /// new page, the way the current Safari does.
    var onOpenInNewTab: ((URL) -> Void)? = nil

    func makeUIView(context: Context) -> WKWebView {
        let webView = tab.webView
        tab.activateIfNeeded()
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator

        if #available(iOS 16.0, *) {
            webView.isFindInteractionEnabled = true
        }

        // Swipe navigation and interactive keyboard dismissal make the browser
        // feel native on modern hardware without touching the iOS 6 chrome.
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = true
        webView.scrollView.keyboardDismissMode = .interactive
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.scrollsToTop = true

        // Pull to refresh, like the current Safari. Guarded because the same
        // WKWebView is also mounted by the tab switcher.
        context.coordinator.webView = webView
        context.coordinator.onOpenInNewTab = onOpenInNewTab
        if webView.scrollView.refreshControl == nil {
            let control = UIRefreshControl()
            control.addTarget(
                context.coordinator,
                action: #selector(Coordinator.handleRefresh(_:)),
                for: .valueChanged
            )
            webView.scrollView.refreshControl = control
        }

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // WKWebView is owned by SafariTab. Recreating or reloading it from
        // SwiftUI updates would destroy scroll position and navigation state.
        context.coordinator.onOpenInNewTab = onOpenInNewTab
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        weak var webView: WKWebView?
        var onOpenInNewTab: ((URL) -> Void)?

        @objc func handleRefresh(_ control: UIRefreshControl) {
            webView?.reload()
        }

        func webView(
            _ webView: WKWebView,
            didFinish navigation: WKNavigation?
        ) {
            webView.scrollView.refreshControl?.endRefreshing()
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            // target="_blank" / window.open: hand the link to a new page when
            // the browser chrome offers one, otherwise keep it in this page.
            if navigationAction.targetFrame == nil,
               let url = navigationAction.request.url {
                if let onOpenInNewTab {
                    onOpenInNewTab(url)
                } else {
                    webView.load(URLRequest(url: url))
                }
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
            webView.scrollView.refreshControl?.endRefreshing()
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation?,
            withError error: Error
        ) {
            webView.scrollView.refreshControl?.endRefreshing()
        }

        // MARK: JavaScript panels

        private func present(_ alert: UIAlertController, from webView: WKWebView) {
            guard let controller = webView.window?.rootViewController else { return }
            var top = controller
            while let presented = top.presentedViewController { top = presented }
            // System alerts always follow the device's Light/Dark Mode
            // setting, in both Normal and Private browsing.
            alert.overrideUserInterfaceStyle = .unspecified
            top.present(alert, animated: true)
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptAlertPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping () -> Void
        ) {
            let alert = UIAlertController(
                title: frame.request.url?.host,
                message: message,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                completionHandler()
            })
            present(alert, from: webView)
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptConfirmPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping (Bool) -> Void
        ) {
            let alert = UIAlertController(
                title: frame.request.url?.host,
                message: message,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                completionHandler(false)
            })
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                completionHandler(true)
            })
            present(alert, from: webView)
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptTextInputPanelWithPrompt prompt: String,
            defaultText: String?,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping (String?) -> Void
        ) {
            let alert = UIAlertController(
                title: frame.request.url?.host,
                message: prompt,
                preferredStyle: .alert
            )
            alert.addTextField { $0.text = defaultText }
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                completionHandler(nil)
            })
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                completionHandler(alert.textFields?.first?.text)
            })
            present(alert, from: webView)
        }

        // MARK: Long press on a link

        func webView(
            _ webView: WKWebView,
            contextMenuConfigurationForElement elementInfo: WKContextMenuElementInfo,
            completionHandler: @escaping (UIContextMenuConfiguration?) -> Void
        ) {
            guard let url = elementInfo.linkURL else {
                completionHandler(nil)
                return
            }

            let configuration = UIContextMenuConfiguration(
                identifier: nil,
                previewProvider: nil
            ) { [weak self] _ in
                let open = UIAction(
                    title: "Open",
                    image: UIImage(systemName: "safari")
                ) { _ in
                    webView.load(URLRequest(url: url))
                }

                let newTab = UIAction(
                    title: "Open in New Page",
                    image: UIImage(systemName: "plus.square.on.square")
                ) { _ in
                    self?.onOpenInNewTab?(url)
                }

                let copy = UIAction(
                    title: "Copy Link",
                    image: UIImage(systemName: "doc.on.doc")
                ) { _ in
                    UIPasteboard.general.url = url
                }

                let share = UIAction(
                    title: "Share\u{2026}",
                    image: UIImage(systemName: "square.and.arrow.up")
                ) { _ in
                    let controller = UIActivityViewController(
                        activityItems: [url],
                        applicationActivities: nil
                    )
                    // The native share sheet always matches the system
                    // appearance, in both Normal and Private browsing.
                    controller.overrideUserInterfaceStyle = .unspecified
                    controller.popoverPresentationController?.sourceView = webView
                    webView.window?.rootViewController?.present(controller, animated: true)
                }

                var actions = [open, copy, share]
                if self?.onOpenInNewTab != nil {
                    actions.insert(newTab, at: 1)
                }
                return UIMenu(title: url.absoluteString, children: actions)
            }

            completionHandler(configuration)
        }
    }
}
