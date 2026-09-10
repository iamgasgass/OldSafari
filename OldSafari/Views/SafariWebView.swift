import SwiftUI
import UIKit
import WebKit
import Photos

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

        let controller = webView.configuration.userContentController
        controller.removeScriptMessageHandler(forName: "oldSafariContextMenu")
        controller.add(context.coordinator, name: "oldSafariContextMenu")
        controller.addUserScript(
            WKUserScript(
                source: "(function() {\n    if (window.__oldSafariContextMenuInstalled) return;\n    window.__oldSafariContextMenuInstalled = true;\n    document.addEventListener(\"contextmenu\", function(event) {\n        var node = event.target;\n        if (!node) return;\n        var image = node.closest ? node.closest(\"img\") : null;\n        if (!image) {\n            window.webkit.messageHandlers.oldSafariContextMenu.postMessage({src: null});\n            return;\n        }\n        var src = image.currentSrc || image.src || image.getAttribute(\"src\") || \"\";\n        window.webkit.messageHandlers.oldSafariContextMenu.postMessage({src: src});\n    }, true);\n})();",
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: false
            )
        )

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

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        weak var webView: WKWebView?
        var onOpenInNewTab: ((URL) -> Void)?
        private var contextMenuImageURL: URL?

        @objc func handleRefresh(_ control: UIRefreshControl) {
            webView?.reload()
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == "oldSafariContextMenu" else { return }
            if let payload = message.body as? [String: Any],
               let raw = payload["src"] as? String,
               !raw.isEmpty,
               let url = URL(string: raw) {
                contextMenuImageURL = url
            } else {
                contextMenuImageURL = nil
            }
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

            // Custom scheme used by the blob download shim in SafariTab.
            // The URL carries `?name=...&data=<base64>` and we materialise it
            // as a real file under the app's Downloads directory.
            if scheme == "oldsafari-download" {
                handleBlobDownload(url: url)
                decisionHandler(.cancel)
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

        // MARK: Download detection

        /// The response phase is where WebKit tells us the MIME type and
        /// headers. Anything the browser cannot render inline (attachment,
        /// unknown MIME, application/octet-stream) is redirected to the
        /// download machinery, exactly like the current Safari does.
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationResponse: WKNavigationResponse,
            decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
        ) {
            guard let response = navigationResponse.response as? HTTPURLResponse,
                  let requestURL = response.url
            else {
                decisionHandler(.allow)
                return
            }

            let disposition = (response.value(forHTTPHeaderField: "Content-Disposition") ?? "").lowercased()
            let mime = (response.mimeType ?? "").lowercased()

            let isAttachment = disposition.contains("attachment")
            let notRenderable = !navigationResponse.canShowMIMEType
            let downloadishMIME = mime == "application/octet-stream"
                || mime.hasPrefix("application/zip")
                || mime.hasPrefix("application/pdf") && isAttachment
                || mime.hasPrefix("application/x-")
                || mime.hasPrefix("application/vnd")
                || mime.hasPrefix("audio/")
                || mime.hasPrefix("video/") && isAttachment

            if isAttachment || notRenderable || downloadishMIME {
                let suggested = filenameHint(response: response, url: requestURL)

                // Modern Safari always confirms with the user before a
                // download actually starts. The previous implementation
                // skipped straight to `decisionHandler(.download)`, so files
                // started downloading silently and immediately — no alert,
                // no way to cancel. We now show the classic iOS 6 styled
                // confirmation first, and only call `.download` if the user
                // taps "Download".
                presentOldOSAlert(
                    title: requestURL.host,
                    message: "Do you want to download \"\(suggested)\"?",
                    buttons: [("Cancel", .cancel), ("Download", .default)]
                ) { [weak self] _, index in
                    guard index == 1 else {
                        decisionHandler(.cancel)
                        return
                    }
                    self?.pendingHint = (suggested, requestURL)
                    decisionHandler(.download)
                }
                return
            }

            decisionHandler(.allow)
        }

        /// Filled in from `decidePolicyFor:navigationResponse:` so we can
        /// carry the suggested filename into `didBecome`.
        private var pendingHint: (String, URL)?

        func webView(
            _ webView: WKWebView,
            navigationAction: WKNavigationAction,
            didBecome download: WKDownload
        ) {
            let source = navigationAction.request.url ?? URL(string: "about:blank")!
            _ = SafariDownloadManager.shared.startDownload(
                source: source,
                suggestedFilename: source.lastPathComponent,
                using: download
            )
            NotificationCenter.default.post(
                name: .oldSafariDownloadStarted,
                object: nil
            )
        }

        func webView(
            _ webView: WKWebView,
            navigationResponse: WKNavigationResponse,
            didBecome download: WKDownload
        ) {
            let hint = pendingHint
            pendingHint = nil

            let filename = hint?.0
                ?? navigationResponse.response.suggestedFilename
                ?? "download"
            let source = hint?.1
                ?? navigationResponse.response.url
                ?? URL(string: "about:blank")!

            _ = SafariDownloadManager.shared.startDownload(
                source: source,
                suggestedFilename: filename,
                using: download
            )
            NotificationCenter.default.post(
                name: .oldSafariDownloadStarted,
                object: nil
            )
        }

        private func filenameHint(response: HTTPURLResponse, url: URL) -> String {
            if let suggested = response.suggestedFilename, !suggested.isEmpty {
                return suggested
            }
            if !url.lastPathComponent.isEmpty {
                return url.lastPathComponent
            }
            return "download"
        }

        // MARK: Blob download bridge

        private func handleBlobDownload(url: URL) {
            guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let items = comps.queryItems
            else { return }

            let name = items.first(where: { $0.name == "name" })?.value ?? "download"
            let payload = items.first(where: { $0.name == "data" })?.value ?? ""
            guard let data = Data(base64Encoded: payload) else { return }

            let base = (try? FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )) ?? URL(fileURLWithPath: NSTemporaryDirectory())
            let folder = base.appendingPathComponent("Downloads", isDirectory: true)
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

            let sanitized = name.replacingOccurrences(of: "/", with: "_")
            var destination = folder.appendingPathComponent(sanitized)
            var counter = 1
            let stem = (sanitized as NSString).deletingPathExtension
            let ext = (sanitized as NSString).pathExtension
            while FileManager.default.fileExists(atPath: destination.path) {
                counter += 1
                let composed = ext.isEmpty ? "\(stem) (\(counter))" : "\(stem) (\(counter)).\(ext)"
                destination = folder.appendingPathComponent(composed)
            }

            do {
                try data.write(to: destination)
                let entry = SafariDownload(
                    sourceURL: url,
                    suggestedFilename: destination.lastPathComponent
                )
                entry.updateProgress(
                    received: Int64(data.count),
                    expected: Int64(data.count)
                )
                entry.markCompleted(at: destination)
                DispatchQueue.main.async {
                    SafariDownloadManager.shared.register(entry)
                    NotificationCenter.default.post(
                        name: .oldSafariDownloadStarted,
                        object: nil
                    )
                }
            } catch {
                // Silently ignore; the shim is best-effort by nature.
            }
        }

        // MARK: Navigation failures

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

        private func presentOldOSAlert(
            title: String?,
            message: String,
            buttons: [(String, OldOSJavaScriptAlertController.ButtonKind)],
            textField: String? = nil,
            completion: @escaping (String?, Int) -> Void
        ) {
            guard let controller = webView?.window?.rootViewController else {
                completion(textField, 0)
                return
            }

            var presenter = controller
            while let presented = presenter.presentedViewController {
                presenter = presented
            }

            let alert = OldOSJavaScriptAlertController(
                title: title,
                message: message,
                buttons: buttons,
                text: textField
            ) { [weak presenter] value, index in
                // WKWebView's completion handler must be called before the
                // presentation controller is torn down. Doing it here also
                // guarantees it is invoked exactly once.
                completion(value, index)
                presenter?.dismiss(animated: true)
            }

            alert.modalPresentationStyle = .overFullScreen
            alert.modalTransitionStyle = .crossDissolve
            alert.view.backgroundColor = .clear
            presenter.present(alert, animated: true)
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptAlertPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping () -> Void
        ) {
            presentOldOSAlert(
                title: frame.request.url?.host,
                message: message,
                buttons: [("OK", .default)]
            ) { _, _ in completionHandler() }
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptConfirmPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping (Bool) -> Void
        ) {
            presentOldOSAlert(
                title: frame.request.url?.host,
                message: message,
                buttons: [("Cancel", .cancel), ("OK", .default)]
            ) { _, index in completionHandler(index == 1) }
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptTextInputPanelWithPrompt prompt: String,
            defaultText: String?,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping (String?) -> Void
        ) {
            presentOldOSAlert(
                title: frame.request.url?.host,
                message: prompt,
                buttons: [("Cancel", .cancel), ("OK", .default)],
                textField: defaultText
            ) { value, index in
                completionHandler(index == 1 ? value : nil)
            }
        }

        // MARK: Long press on a link

        func webView(
            _ webView: WKWebView,
            contextMenuConfigurationForElement elementInfo: WKContextMenuElementInfo,
            completionHandler: @escaping (UIContextMenuConfiguration?) -> Void
        ) {
            let linkURL = elementInfo.linkURL
            let imageURL = contextMenuImageURL
            contextMenuImageURL = nil

            guard linkURL != nil || imageURL != nil else {
                completionHandler(nil)
                return
            }

            let configuration = UIContextMenuConfiguration(
                identifier: nil,
                previewProvider: nil
            ) { [weak self] _ in
                var actions: [UIAction] = []

                if let imageURL {
                    let saveImage = UIAction(
                        title: "Save Image",
                        image: UIImage(systemName: "square.and.arrow.down")
                    ) { [weak self] _ in
                        self?.saveImageToPhotos(imageURL)
                    }
                    actions.append(saveImage)
                }

                if let linkURL {
                    let open = UIAction(
                        title: "Open",
                        image: UIImage(systemName: "safari")
                    ) { _ in
                        webView.load(URLRequest(url: linkURL))
                    }

                    let newTab = UIAction(
                        title: "Open in New Page",
                        image: UIImage(systemName: "plus.square.on.square")
                    ) { [weak self] _ in
                        self?.onOpenInNewTab?(linkURL)
                    }

                    let copy = UIAction(
                        title: "Copy Link",
                        image: UIImage(systemName: "doc.on.doc")
                    ) { _ in
                        UIPasteboard.general.url = linkURL
                    }

                    let download = UIAction(
                        title: "Download Linked File",
                        image: UIImage(systemName: "arrow.down.circle")
                    ) { _ in
                        webView.load(URLRequest(url: linkURL))
                    }

                    actions.append(contentsOf: [open])
                    if self?.onOpenInNewTab != nil { actions.append(newTab) }
                    actions.append(contentsOf: [copy, download])

                    let share = UIAction(
                        title: "Share…",
                        image: UIImage(systemName: "square.and.arrow.up")
                    ) { _ in
                        let controller = UIActivityViewController(
                            activityItems: [linkURL],
                            applicationActivities: nil
                        )
                        controller.overrideUserInterfaceStyle = .unspecified
                        controller.popoverPresentationController?.sourceView = webView
                        webView.window?.rootViewController?.present(controller, animated: true)
                    }
                    actions.append(share)
                }

                return UIMenu(title: imageURL != nil ? "Image" : (linkURL?.absoluteString ?? ""), children: actions)
            }

            completionHandler(configuration)
        }

        /// WKContextMenuElementInfo supplies the resolved image URL, but does
        /// not itself save anything. Fetch it as binary data, create a UIImage,
        /// then use the Photos add-only API. This fixes "Save Image" on sites
        /// such as Google Images without depending on WebKit's temporary cache.
        private func saveImageToPhotos(_ url: URL) {
            let request = URLRequest(
                url: url,
                cachePolicy: .reloadIgnoringLocalCacheData,
                timeoutInterval: 30
            )

            URLSession.shared.dataTask(with: request) { data, response, error in
                guard
                    error == nil,
                    let data,
                    let image = UIImage(data: data)
                else { return }

                PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                    guard status == .authorized || status == .limited else { return }

                    PHPhotoLibrary.shared().performChanges {
                        PHAssetChangeRequest.creationRequestForAsset(from: image)
                    } completionHandler: { _, _ in }
                }
            }.resume()
        }

    }
}


/// A small, self-contained recreation of the iOS 6 JavaScript alert surface.
/// It intentionally does not use UIAlertController: that control adopts the
/// current iOS visual language and therefore cannot reproduce the old Safari
/// alert chrome.
final class OldOSJavaScriptAlertController: UIViewController {

    enum ButtonKind {
        case `default`
        case cancel
    }

    private let alertTitle: String?
    private let message: String
    private let buttons: [(String, ButtonKind)]
    private let initialText: String?
    private let completion: (String?, Int) -> Void
    private var didFinish = false
    private weak var input: UITextField?

    private let card = UIView()
    private let cardGradient = CAGradientLayer()
    private var topHighlightLayer: CAGradientLayer?
    private var rimLayer: CAShapeLayer?
    private var buttonGradients: [(CAGradientLayer, CAGradientLayer)] = []
    private var buttonContainers: [UIView] = []

    init(
        title: String?,
        message: String,
        buttons: [(String, ButtonKind)],
        text: String?,
        completion: @escaping (String?, Int) -> Void
    ) {
        self.alertTitle = title
        self.message = message
        self.buttons = buttons
        self.initialText = text
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()

        // IMPORTANT: this controller is presented with `.overFullScreen` and
        // its own `view.backgroundColor` set to `.clear` by the presenter,
        // so the root `view` never paints a solid background — only the
        // `scrim` (dimming layer) and the `card` (the actual alert) do. If
        // `view.backgroundColor` were ever left at the default `.white`,
        // the whole screen would flash solid white before/behind the alert,
        // which is exactly the "interamente bianco" symptom being fixed.
        view.backgroundColor = .clear

        let scrim = UIView()
        scrim.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        scrim.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrim)
        NSLayoutConstraint.activate([
            scrim.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrim.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrim.topAnchor.constraint(equalTo: view.topAnchor),
            scrim.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        let shadowContainer = UIView()
        shadowContainer.translatesAutoresizingMaskIntoConstraints = false
        shadowContainer.layer.shadowColor = UIColor.black.cgColor
        shadowContainer.layer.shadowOpacity = 0.6
        shadowContainer.layer.shadowRadius = 14
        shadowContainer.layer.shadowOffset = CGSize(width: 0, height: 8)
        view.addSubview(shadowContainer)

        let width = min(UIScreen.main.bounds.width - 56, 270)
        NSLayoutConstraint.activate([
            shadowContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shadowContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            shadowContainer.widthAnchor.constraint(equalToConstant: width)
        ])

        // The card MUST NOT have a plain `backgroundColor` — the entire
        // surface is painted by `cardGradient` (a CAGradientLayer inserted
        // at index 0). Setting a `backgroundColor` on top of a gradient
        // sublayer is harmless as long as the gradient layer's frame is
        // correctly sized in `viewDidLayoutSubviews`; leaving the gradient
        // frame at `.zero` (a bug in an earlier revision of this file) is
        // what caused the card to render as a flat, undecorated white/blank
        // rectangle instead of the navy chrome from the reference photo.
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = .clear
        card.layer.cornerRadius = 13
        card.layer.masksToBounds = true
        card.layer.borderWidth = 1
        card.layer.borderColor = UIColor(white: 0.05, alpha: 0.9).cgColor
        shadowContainer.addSubview(card)
        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: shadowContainer.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: shadowContainer.trailingAnchor),
            card.topAnchor.constraint(equalTo: shadowContainer.topAnchor),
            card.bottomAnchor.constraint(equalTo: shadowContainer.bottomAnchor)
        ])

        // Vertical navy-blue gradient sampled from the "Data Isolation"
        // reference photo: light blue-gray at the top fading to dark navy
        // at the bottom, as one continuous ramp (not a hard two-tone split).
        cardGradient.colors = [
            UIColor(red: 126 / 255, green: 138 / 255, blue: 163 / 255, alpha: 1).cgColor,
            UIColor(red: 79 / 255,  green: 95 / 255,  blue: 130 / 255, alpha: 1).cgColor,
            UIColor(red: 40 / 255,  green: 55 / 255,  blue: 92 / 255,  alpha: 1).cgColor,
            UIColor(red: 33 / 255,  green: 48 / 255,  blue: 89 / 255,  alpha: 1).cgColor
        ]
        cardGradient.locations = [0, 0.18, 0.55, 1.0]
        card.layer.insertSublayer(cardGradient, at: 0)

        let topHighlight = CAGradientLayer()
        topHighlight.colors = [
            UIColor.white.withAlphaComponent(0.38).cgColor,
            UIColor.white.withAlphaComponent(0.0).cgColor
        ]
        card.layer.insertSublayer(topHighlight, above: cardGradient)
        self.topHighlightLayer = topHighlight

        // Thin light "rim" just inside the dark outer border — the subtle
        // double-edge glassy look visible in the reference photo.
        let rim = CAShapeLayer()
        rim.fillColor = UIColor.clear.cgColor
        rim.strokeColor = UIColor.white.withAlphaComponent(0.3).cgColor
        rim.lineWidth = 1
        card.layer.addSublayer(rim)
        self.rimLayer = rim

        let outerStack = UIStackView()
        outerStack.axis = .vertical
        outerStack.spacing = 0
        outerStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(outerStack)
        NSLayoutConstraint.activate([
            outerStack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            outerStack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            outerStack.topAnchor.constraint(equalTo: card.topAnchor),
            outerStack.bottomAnchor.constraint(equalTo: card.bottomAnchor)
        ])

        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 6
        textStack.isLayoutMarginsRelativeArrangement = true
        textStack.layoutMargins = UIEdgeInsets(top: 18, left: 16, bottom: 16, right: 16)
        outerStack.addArrangedSubview(textStack)

        let titleLabel = UILabel()
        titleLabel.text = alertTitle?.isEmpty == false ? alertTitle : "Safari"
        titleLabel.textAlignment = .center
        titleLabel.font = UIFont(name: "HelveticaNeue-Bold", size: 17) ?? .boldSystemFont(ofSize: 17)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 2
        titleLabel.backgroundColor = .clear
        titleLabel.layer.shadowColor = UIColor.black.withAlphaComponent(0.55).cgColor
        titleLabel.layer.shadowOffset = CGSize(width: 0, height: 1)
        titleLabel.layer.shadowOpacity = 1
        titleLabel.layer.shadowRadius = 0
        titleLabel.layer.shouldRasterize = true
        titleLabel.layer.rasterizationScale = UIScreen.main.scale
        textStack.addArrangedSubview(titleLabel)

        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.textAlignment = .center
        messageLabel.font = UIFont(name: "HelveticaNeue", size: 14) ?? .systemFont(ofSize: 14)
        messageLabel.textColor = .white
        messageLabel.numberOfLines = 0
        messageLabel.lineBreakMode = .byWordWrapping
        messageLabel.backgroundColor = .clear
        messageLabel.layer.shadowColor = UIColor.black.withAlphaComponent(0.5).cgColor
        messageLabel.layer.shadowOffset = CGSize(width: 0, height: 1)
        messageLabel.layer.shadowOpacity = 1
        messageLabel.layer.shadowRadius = 0
        messageLabel.layer.shouldRasterize = true
        messageLabel.layer.rasterizationScale = UIScreen.main.scale
        textStack.addArrangedSubview(messageLabel)

        if let initialText {
            let field = UITextField()
            field.text = initialText
            field.font = UIFont(name: "HelveticaNeue", size: 15)
            field.textColor = .black
            field.backgroundColor = .white
            field.layer.cornerRadius = 6
            field.layer.borderWidth = 1
            field.layer.borderColor = UIColor(white: 0.25, alpha: 1).cgColor
            field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 7, height: 1))
            field.leftViewMode = .always
            field.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 7, height: 1))
            field.rightViewMode = .always
            field.heightAnchor.constraint(equalToConstant: 32).isActive = true
            field.translatesAutoresizingMaskIntoConstraints = false
            textStack.setCustomSpacing(10, after: messageLabel)
            textStack.addArrangedSubview(field)
            input = field
        }

        let hDivider = UIView()
        hDivider.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        hDivider.translatesAutoresizingMaskIntoConstraints = false
        hDivider.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale).isActive = true
        outerStack.addArrangedSubview(hDivider)

        let buttonRow = UIStackView()
        buttonRow.axis = .horizontal
        buttonRow.spacing = 8
        buttonRow.distribution = .fillEqually
        buttonRow.isLayoutMarginsRelativeArrangement = true
        buttonRow.layoutMargins = UIEdgeInsets(top: 10, left: 10, bottom: 12, right: 10)
        buttonRow.translatesAutoresizingMaskIntoConstraints = false
        outerStack.addArrangedSubview(buttonRow)
        buttonRow.heightAnchor.constraint(equalToConstant: 66).isActive = true

        for (index, item) in buttons.enumerated() {
            let (pill, gradient, highlight) = makePillButton(title: item.0, tag: index)
            buttonRow.addArrangedSubview(pill)
            buttonContainers.append(pill)
            buttonGradients.append((gradient, highlight))
        }
    }

    /// Separate rounded "pill" buttons, each with its own lighter gradient
    /// and gloss highlight — this is what the reference photo actually
    /// shows for "Don't Allow" / "OK" (two distinct buttons with visible
    /// gaps and their own chrome), not a single borderless strip.
    private func makePillButton(title: String, tag: Int) -> (UIView, CAGradientLayer, CAGradientLayer) {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = .clear
        container.layer.cornerRadius = 8
        container.layer.masksToBounds = true
        container.layer.borderWidth = 1 / UIScreen.main.scale
        container.layer.borderColor = UIColor(white: 0.02, alpha: 0.85).cgColor

        let gradient = CAGradientLayer()
        gradient.colors = [
            UIColor(red: 173 / 255, green: 181 / 255, blue: 199 / 255, alpha: 1).cgColor,
            UIColor(red: 130 / 255, green: 141 / 255, blue: 164 / 255, alpha: 1).cgColor,
            UIColor(red: 96 / 255,  green: 108 / 255, blue: 136 / 255, alpha: 1).cgColor,
            UIColor(red: 72 / 255,  green: 85 / 255,  blue: 116 / 255, alpha: 1).cgColor
        ]
        gradient.locations = [0, 0.42, 0.43, 1.0]
        container.layer.insertSublayer(gradient, at: 0)

        let highlight = CAGradientLayer()
        highlight.colors = [
            UIColor.white.withAlphaComponent(0.45).cgColor,
            UIColor.white.withAlphaComponent(0.0).cgColor
        ]
        container.layer.insertSublayer(highlight, above: gradient)

        let button = UIButton(type: .custom)
        button.tag = tag
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont(name: "HelveticaNeue-Bold", size: 18) ?? .boldSystemFont(ofSize: 18)
        button.setTitleColor(.white, for: .normal)
        button.setTitleColor(UIColor.white.withAlphaComponent(0.55), for: .highlighted)
        button.backgroundColor = .clear
        button.titleLabel?.layer.shadowColor = UIColor.black.withAlphaComponent(0.6).cgColor
        button.titleLabel?.layer.shadowOffset = CGSize(width: 0, height: 1)
        button.titleLabel?.layer.shadowOpacity = 1
        button.titleLabel?.layer.shadowRadius = 0
        button.titleLabel?.layer.shouldRasterize = true
        button.titleLabel?.layer.rasterizationScale = UIScreen.main.scale
        button.addTarget(self, action: #selector(handleButton(_:)), for: .touchUpInside)
        button.addTarget(self, action: #selector(handlePillHighlight(_:)), for: [.touchDown, .touchDragEnter])
        button.addTarget(self, action: #selector(handlePillUnhighlight(_:)), for: [.touchDragExit, .touchCancel, .touchUpInside, .touchUpOutside])
        button.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(button)
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            button.topAnchor.constraint(equalTo: container.topAnchor),
            button.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return (container, gradient, highlight)
    }

    @objc private func handlePillHighlight(_ sender: UIButton) {
        sender.superview?.layer.opacity = 0.7
    }

    @objc private func handlePillUnhighlight(_ sender: UIButton) {
        sender.superview?.layer.opacity = 1.0
    }

    // All CAGradientLayer/CAShapeLayer frames are set here rather than at
    // creation time, because at `viewDidLoad` the card and button views
    // have zero size (Auto Layout has not resolved yet). Forgetting this
    // step — or setting frames only once instead of on every layout pass —
    // is precisely what makes a gradient-backed view render as a flat,
    // undecorated blank/white rectangle: the gradient layer exists but has
    // no area to actually paint.
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        cardGradient.frame = card.bounds
        topHighlightLayer?.frame = CGRect(
            x: 0, y: 0,
            width: card.bounds.width,
            height: min(card.bounds.height * 0.42, 42)
        )
        rimLayer?.frame = card.bounds
        rimLayer?.path = UIBezierPath(
            roundedRect: card.bounds.insetBy(dx: 1.5, dy: 1.5),
            cornerRadius: 11.5
        ).cgPath

        for (index, container) in buttonContainers.enumerated() {
            let (gradient, highlight) = buttonGradients[index]
            gradient.frame = container.bounds
            highlight.frame = CGRect(
                x: 0, y: 0,
                width: container.bounds.width,
                height: container.bounds.height * 0.5
            )
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        input?.becomeFirstResponder()
    }

    @objc private func handleButton(_ sender: UIButton) {
        finish(index: sender.tag)
    }

    private func finish(index: Int) {
        guard !didFinish else { return }
        didFinish = true
        completion(input?.text, index)
    }
}
