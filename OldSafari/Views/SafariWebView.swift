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
                source: """
                (function() {
                  if (window.__oldSafariContextMenuInstalled) return;
                  window.__oldSafariContextMenuInstalled = true;
                  window.__oldSafariLastImageSrc = null;

                  function resolveImage(x, y) {
                    var node = document.elementFromPoint(x, y);
                    if (!node) return null;
                    var image = node.closest ? node.closest('img') : null;
                    if (!image) return null;
                    return image.currentSrc || image.src || image.getAttribute('src') || null;
                  }

                  function report(src) {
                    window.__oldSafariLastImageSrc = src;
                    try {
                      window.webkit.messageHandlers.oldSafariContextMenu.postMessage({src: src});
                    } catch (e) {}
                  }

                  document.addEventListener('touchstart', function(event) {
                    var t = event.touches && event.touches[0];
                    if (!t) return;
                    report(resolveImage(t.clientX, t.clientY));
                  }, true);

                  document.addEventListener('contextmenu', function(event) {
                    var node = event.target;
                    var image = node && node.closest ? node.closest('img') : null;
                    if (image) {
                      report(image.currentSrc || image.src || image.getAttribute('src') || null);
                    }
                  }, true);
                })();
                """,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: false
            )
        )

        if #available(iOS 16.0, *) {
            webView.isFindInteractionEnabled = true
        }

        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = true
        webView.scrollView.keyboardDismissMode = .interactive
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.scrollsToTop = true

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
                let host = requestURL.host ?? "this server"

                presentOldOSAlert(
                    title: "Safari",
                    message: "Do you want to download \"\(suggested)\" from \"\(host)\"?",
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
            NotificationCenter.default.post(name: .oldSafariDownloadStarted, object: nil)
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
            NotificationCenter.default.post(name: .oldSafariDownloadStarted, object: nil)
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
                entry.updateProgress(received: Int64(data.count), expected: Int64(data.count))
                entry.markCompleted(at: destination)
                DispatchQueue.main.async {
                    SafariDownloadManager.shared.register(entry)
                    NotificationCenter.default.post(name: .oldSafariDownloadStarted, object: nil)
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
            let pageURL = webView.url

            webView.evaluateJavaScript("window.__oldSafariLastImageSrc || ''") { [weak self] result, _ in
                guard let self else {
                    completionHandler(nil)
                    return
                }
                let pulled = (result as? String).flatMap { $0.isEmpty ? nil : URL(string: $0) }
                let imageURL = pulled ?? self.contextMenuImageURL
                self.contextMenuImageURL = nil

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

/// A small, self-contained recreation of the classic iOS (pre-iOS 7)
/// UIAlertView surface — replica fedele della foto "Data Isolation".
///
/// Struttura, dall'esterno all'interno:
/// 1. `shadowContainer` (non clippato): proietta l'ombra portata morbida
///    sullo sfondo scurito — nella foto l'alert "galleggia" visibilmente,
///    dettaglio che le versioni precedenti omettevano del tutto.
/// 2. `card` (clippato, angoli arrotondati): contiene il gradiente blu
///    continuo + il doppio bordo (anello scuro esterno + filo chiaro
///    interno, il tipico "rim" vetroso di quello stile).
/// 3. Testo (titolo/messaggio) con ombra incisa sotto, poi una linea
///    orizzontale, poi la striscia pulsanti unica (non pillole separate)
///    divisa da una linea verticale — mostra lo stesso sfondo della card,
///    nessun chrome proprio.
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

    private let shadowContainer = UIView()
    private let card = UIView()
    private let innerRim = CALayer()
    private let cardGradient = CAGradientLayer()
    private var topHighlightLayer: CAGradientLayer?

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
        scrim.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        scrim.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrim)
        NSLayoutConstraint.activate([
            scrim.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrim.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrim.topAnchor.constraint(equalTo: view.topAnchor),
            scrim.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Contenitore ombra: NON clippa, così l'ombra portata di `card` non
        // viene tagliata via dal masksToBounds usato per gli angoli tondi.
        shadowContainer.translatesAutoresizingMaskIntoConstraints = false
        shadowContainer.layer.shadowColor = UIColor.black.cgColor
        shadowContainer.layer.shadowOpacity = 0.55
        shadowContainer.layer.shadowRadius = 14
        shadowContainer.layer.shadowOffset = CGSize(width: 0, height: 8)
        view.addSubview(shadowContainer)

        let width = min(UIScreen.main.bounds.width - 56, 270)
        NSLayoutConstraint.activate([
            shadowContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shadowContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            shadowContainer.widthAnchor.constraint(equalToConstant: width)
        ])

        card.translatesAutoresizingMaskIntoConstraints = false
        card.layer.cornerRadius = 13
        card.layer.masksToBounds = true
        card.layer.borderWidth = 1
        card.layer.borderColor = UIColor(white: 0.04, alpha: 0.95).cgColor
        shadowContainer.addSubview(card)
        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: shadowContainer.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: shadowContainer.trailingAnchor),
            card.topAnchor.constraint(equalTo: shadowContainer.topAnchor),
            card.bottomAnchor.constraint(equalTo: shadowContainer.bottomAnchor)
        ])

        cardGradient.colors = [
            UIColor(red: 108 / 255, green: 138 / 255, blue: 182 / 255, alpha: 1).cgColor,
            UIColor(red: 66 / 255, green: 96 / 255, blue: 146 / 255, alpha: 1).cgColor,
            UIColor(red: 52 / 255, green: 80 / 255, blue: 128 / 255, alpha: 1).cgColor,
            UIColor(red: 34 / 255, green: 58 / 255, blue: 98 / 255, alpha: 1).cgColor
        ]
        cardGradient.locations = [0, 0.45, 0.46, 1.0]
        card.layer.insertSublayer(cardGradient, at: 0)

        // Anello chiaro interno (1px, inset di 1pt) — il "rim" vetroso che
        // nella foto rende il bordo a doppio contorno (scuro fuori, chiaro
        // appena dentro) invece di una linea singola piatta.
        innerRim.borderWidth = 1
        innerRim.borderColor = UIColor.white.withAlphaComponent(0.35).cgColor
        innerRim.cornerRadius = 12
        card.layer.addSublayer(innerRim)

        let topHighlight = CAGradientLayer()
        topHighlight.colors = [
            UIColor.white.withAlphaComponent(0.5).cgColor,
            UIColor.white.withAlphaComponent(0.0).cgColor
        ]
        card.layer.insertSublayer(topHighlight, above: cardGradient)
        self.topHighlightLayer = topHighlight

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
            textStack.setCustomSpacing(10, after: messageLabel)
            textStack.addArrangedSubview(field)
            input = field
        }

        let hDivider = UIView()
        hDivider.backgroundColor = UIColor(red: 18 / 255, green: 30 / 255, blue: 52 / 255, alpha: 0.9)
        hDivider.translatesAutoresizingMaskIntoConstraints = false
        hDivider.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale).isActive = true
        outerStack.addArrangedSubview(hDivider)

        let buttonRow = UIStackView()
        buttonRow.axis = .horizontal
        buttonRow.spacing = 0
        buttonRow.distribution = .fillEqually
        buttonRow.translatesAutoresizingMaskIntoConstraints = false
        outerStack.addArrangedSubview(buttonRow)
        buttonRow.heightAnchor.constraint(equalToConstant: 44).isActive = true

        for (index, item) in buttons.enumerated() {
            if index > 0 {
                let vDivider = UIView()
                vDivider.backgroundColor = UIColor(red: 18 / 255, green: 30 / 255, blue: 52 / 255, alpha: 0.9)
                vDivider.translatesAutoresizingMaskIntoConstraints = false
                vDivider.widthAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale).isActive = true
                buttonRow.addArrangedSubview(vDivider)
            }
            let button = makeFlatButton(title: item.0, tag: index)
            buttonRow.addArrangedSubview(button)
        }
    }

    private func makeFlatButton(title: String, tag: Int) -> UIButton {
        let button = UIButton(type: .custom)
        button.tag = tag
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont(name: "HelveticaNeue-Bold", size: 18) ?? .boldSystemFont(ofSize: 18)
        button.setTitleColor(.white, for: .normal)
        button.setTitleColor(UIColor.white.withAlphaComponent(0.55), for: .highlighted)
        button.titleLabel?.layer.shadowColor = UIColor.black.withAlphaComponent(0.6).cgColor
        button.titleLabel?.layer.shadowOffset = CGSize(width: 0, height: 1)
        button.titleLabel?.layer.shadowOpacity = 1
        button.titleLabel?.layer.shadowRadius = 0
        button.titleLabel?.layer.shouldRasterize = true
        button.titleLabel?.layer.rasterizationScale = UIScreen.main.scale
        button.backgroundColor = .clear
        button.addTarget(self, action: #selector(handleButton(_:)), for: .touchUpInside)
        return button
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        cardGradient.frame = card.bounds
        topHighlightLayer?.frame = CGRect(
            x: 0, y: 0,
            width: card.bounds.width,
            height: min(card.bounds.height * 0.42, 42)
        )
        innerRim.frame = card.bounds.insetBy(dx: 1, dy: 1)
        shadowContainer.layer.shadowPath = UIBezierPath(
            roundedRect: shadowContainer.bounds,
            cornerRadius: 13
        ).cgPath
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
