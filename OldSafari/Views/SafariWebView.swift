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
                source: "(function() {\n  if (window.__oldSafariContextMenuInstalled) return;\n  window.__oldSafariContextMenuInstalled = true;\n  document.addEventListener(\"contextmenu\", function(event) {\n    var node = event.target;\n    if (!node) return;\n    var image = node.closest ? node.closest(\"img\") : null;\n    if (!image) {\n      window.webkit.messageHandlers.oldSafariContextMenu.postMessage({src: null});\n      return;\n    }\n    var src = image.currentSrc || image.src || image.getAttribute(\"src\") || \"\";\n    window.webkit.messageHandlers.oldSafariContextMenu.postMessage({src: src});\n  }, true);\n})();",
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
            // The URL carries `?name=...&data=` and we materialise it
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
                || (mime.hasPrefix("application/pdf") && isAttachment)
                || mime.hasPrefix("application/x-")
                || mime.hasPrefix("application/vnd")
                || mime.hasPrefix("audio/")
                || (mime.hasPrefix("video/") && isAttachment)

            if isAttachment || notRenderable || downloadishMIME {
                let suggested = filenameHint(response: response, url: requestURL)
                // Prime the download entry so the manager can match it up
                // when WKDownload calls back. WKWebView will hand us the
                // real `WKDownload` in `navigationResponseDidBecomeDownload`.
                pendingHint = (suggested, requestURL)
                decisionHandler(.download)
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

        // MARK: Long press on a link / image

        func webView(
            _ webView: WKWebView,
            contextMenuConfigurationForElement elementInfo: WKContextMenuElementInfo,
            completionHandler: @escaping (UIContextMenuConfiguration?) -> Void
        ) {
            let linkURL = elementInfo.linkURL

            // FIX BUG "Salva immagine non salva nulla": WKContextMenuElementInfo
            // non espone l'URL dell'immagine, per cui viene intercettato via lo
            // script JS "oldSafariContextMenu" con un postMessage ASINCRONO.
            // Leggere `contextMenuImageURL` in modo sincrono, come faceva la
            // versione precedente, creava una race condition: il valore era
            // ancora nil o quello del long-press precedente nel momento esatto
            // in cui il menu veniva costruito. Ritardare la lettura di un run
            // loop dà tempo al messaggio JS di arrivare.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
                guard let self else {
                    completionHandler(nil)
                    return
                }
                let imageURL = self.contextMenuImageURL
                self.contextMenuImageURL = nil
                let pageURL = webView.url

                guard linkURL != nil || imageURL != nil else {
                    completionHandler(nil)
                    return
                }

                let configuration = UIContextMenuConfiguration(
                    identifier: nil,
                    previewProvider: nil
                ) { [weak self] _ in
                    guard let self else { return nil }
                    var actions: [UIAction] = []

                    if let imageURL {
                        let saveImage = UIAction(
                            title: "Save Image",
                            image: UIImage(systemName: "square.and.arrow.down")
                        ) { [weak self] _ in
                            self?.confirmAndSaveImage(imageURL, pageURL: pageURL)
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
                        if self.onOpenInNewTab != nil { actions.append(newTab) }
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

                    return UIMenu(
                        title: imageURL != nil ? "Image" : (linkURL?.absoluteString ?? ""),
                        children: actions
                    )
                }

                completionHandler(configuration)
            }
        }

        /// Alert di conferma in stile iOS 6, mostrato prima di scaricare
        /// davvero l'immagine — replica il comportamento del Safari moderno
        /// ma con la UI classica, riusando `presentOldOSAlert`.
        private func confirmAndSaveImage(_ url: URL, pageURL: URL?) {
            presentOldOSAlert(
                title: "Save Image",
                message: "Save this image to your Photos?",
                buttons: [("Cancel", .cancel), ("Save", .default)]
            ) { [weak self] _, index in
                guard index == 1 else { return }
                self?.saveImageToPhotos(url, referer: pageURL)
            }
        }

        /// WKContextMenuElementInfo supplies the resolved image URL, but does
        /// not itself save anything. Fetch it as binary data, create a
        /// UIImage, then use the Photos add-only API.
        ///
        /// FIX BUG: mancava l'header Referer. Molti host con hotlink-protection
        /// (Google Immagini / gstatic.com e CDN simili) rispondono 403 o corpo
        /// vuoto a richieste "nude": UIImage(data:) falliva silenziosamente e
        /// il flusso terminava senza alcun feedback. Ora impostiamo Referer +
        /// User-Agent e mostriamo un alert iOS 6 in ogni esito.
        private func saveImageToPhotos(_ url: URL, referer: URL?) {
            var request = URLRequest(
                url: url,
                cachePolicy: .reloadIgnoringLocalCacheData,
                timeoutInterval: 30
            )
            if let referer {
                request.setValue(referer.absoluteString, forHTTPHeaderField: "Referer")
            }
            request.setValue(
                "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1",
                forHTTPHeaderField: "User-Agent"
            )

            URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                guard let self else { return }

                guard
                    error == nil,
                    let http = response as? HTTPURLResponse,
                    (200...299).contains(http.statusCode),
                    let data,
                    let image = UIImage(data: data)
                else {
                    DispatchQueue.main.async {
                        self.presentOldOSAlert(
                            title: "Safari",
                            message: "The image could not be downloaded.",
                            buttons: [("OK", .default)]
                        ) { _, _ in }
                    }
                    return
                }

                PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                    DispatchQueue.main.async {
                        guard status == .authorized || status == .limited else {
                            self.presentOldOSAlert(
                                title: "Safari",
                                message: "Safari does not have permission to save to Photos. Enable it in Settings.",
                                buttons: [("OK", .default)]
                            ) { _, _ in }
                            return
                        }

                        PHPhotoLibrary.shared().performChanges {
                            PHAssetChangeRequest.creationRequestForAsset(from: image)
                        } completionHandler: { success, _ in
                            DispatchQueue.main.async {
                                self.presentOldOSAlert(
                                    title: "Safari",
                                    message: success ? "Image saved to Photos." : "The image could not be saved.",
                                    buttons: [("OK", .default)]
                                ) { _, _ in }
                            }
                        }
                    }
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

        let scrim = UIView()
        scrim.backgroundColor = UIColor.black.withAlphaComponent(0.48)
        scrim.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrim)
        NSLayoutConstraint.activate([
            scrim.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrim.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrim.topAnchor.constraint(equalTo: view.topAnchor),
            scrim.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.layer.cornerRadius = 10
        card.layer.masksToBounds = true
        card.layer.borderWidth = 1
        card.layer.borderColor = UIColor(white: 0.08, alpha: 0.85).cgColor
        card.backgroundColor = UIColor(white: 0.91, alpha: 1)
        view.addSubview(card)

        let width = min(UIScreen.main.bounds.width - 40, 280)
        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            card.widthAnchor.constraint(equalToConstant: width)
        ])

        let topGradient = CAGradientLayer()
        topGradient.colors = [
            UIColor(white: 0.98, alpha: 1).cgColor,
            UIColor(white: 0.78, alpha: 1).cgColor
        ]
        topGradient.locations = [0, 1]
        topGradient.frame = CGRect(x: 0, y: 0, width: width, height: 1)
        card.layer.addSublayer(topGradient)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            stack.topAnchor.constraint(equalTo: card.topAnchor),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor)
        ])

        let titleLabel = UILabel()
        titleLabel.text = alertTitle?.isEmpty == false ? alertTitle : "Safari"
        titleLabel.textAlignment = .center
        titleLabel.font = UIFont(name: "HelveticaNeue-Bold", size: 18) ?? .boldSystemFont(ofSize: 18)
        titleLabel.textColor = .black
        titleLabel.numberOfLines = 2
        titleLabel.setContentHuggingPriority(.required, for: .vertical)
        titleLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 36).isActive = true
        stack.addArrangedSubview(titleLabel)

        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.textAlignment = .center
        messageLabel.font = UIFont(name: "HelveticaNeue", size: 15) ?? .systemFont(ofSize: 15)
        messageLabel.textColor = UIColor(white: 0.12, alpha: 1)
        messageLabel.numberOfLines = 0
        messageLabel.lineBreakMode = .byWordWrapping
        messageLabel.layoutMargins = UIEdgeInsets(top: 0, left: 18, bottom: 10, right: 18)
        stack.addArrangedSubview(messageLabel)

        if let initialText {
            let field = UITextField()
            field.text = initialText
            field.font = UIFont(name: "HelveticaNeue", size: 15)
            field.textColor = .black
            field.backgroundColor = .white
            field.layer.cornerRadius = 6
            field.layer.borderWidth = 1
            field.layer.borderColor = UIColor(white: 0.55, alpha: 1).cgColor
            field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 7, height: 1))
            field.leftViewMode = .always
            field.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 7, height: 1))
            field.rightViewMode = .always
            field.heightAnchor.constraint(equalToConstant: 32).isActive = true
            field.translatesAutoresizingMaskIntoConstraints = false
            stack.setCustomSpacing(10, after: messageLabel)
            stack.addArrangedSubview(field)
            input = field
        }

        let separator = UIView()
        separator.backgroundColor = UIColor(white: 0.67, alpha: 1)
        separator.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale).isActive = true
        stack.addArrangedSubview(separator)

        let buttonRow = UIStackView()
        buttonRow.axis = .horizontal
        buttonRow.distribution = .fillEqually
        buttonRow.spacing = 1 / UIScreen.main.scale
        buttonRow.backgroundColor = UIColor(white: 0.67, alpha: 1)
        buttonRow.heightAnchor.constraint(equalToConstant: 44).isActive = true
        stack.addArrangedSubview(buttonRow)

        for (index, item) in buttons.enumerated() {
            let button = UIButton(type: .custom)
            button.tag = index
            button.setTitle(item.0, for: .normal)
            button.titleLabel?.font = UIFont(name: "HelveticaNeue-Bold", size: 17) ?? .boldSystemFont(ofSize: 17)
            button.setTitleColor(
                item.1 == .cancel ? UIColor(white: 0.18, alpha: 1) : UIColor(red: 0.05, green: 0.32, blue: 0.67, alpha: 1),
                for: .normal
            )
            button.backgroundColor = UIColor(white: 0.91, alpha: 1)
            button.addTarget(self, action: #selector(handleButton(_:)), for: .touchUpInside)
            buttonRow.addArrangedSubview(button)
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
