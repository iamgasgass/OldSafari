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

        // FIX: delegates MUST be attached before `activateIfNeeded()` can
        // ever call `webView.load()`. The previous order called
        // `activateIfNeeded()` first, so the tab's very first navigation
        // — whether restored from a saved session or opened fresh — could
        // start before `navigationDelegate`/`uiDelegate` existed, silently
        // skipping every download/scheme/MIME check below for that one
        // request. Paired with the matching fix in `SafariTab.init`
        // (which now always defers the initial load to
        // `activateIfNeeded()` instead of loading synchronously inside
        // the initializer), this guarantees a delegate is in place before
        // any request this browser makes ever leaves the device.
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        tab.activateIfNeeded()

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
            guard let url = navigationAction.request.url else { return nil }

            guard let scheme = url.scheme?.lowercased(), Self.isWebHandledScheme(scheme) else {
                if let scheme = url.scheme?.lowercased(), scheme != "about" {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
                return nil
            }

            if navigationAction.targetFrame == nil {
                if let onOpenInNewTab {
                    onOpenInNewTab(url)
                } else {
                    webView.load(URLRequest(url: url))
                }
            }
            return nil
        }

        @available(iOS 14.5, *)
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            preferences: WKWebpagePreferences,
            decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void
        ) {
            if navigationAction.shouldPerformDownload {
                decisionHandler(.download, preferences)
                return
            }

            resolveActionPolicy(for: navigationAction) { policy in
                decisionHandler(policy, preferences)
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            resolveActionPolicy(for: navigationAction, decisionHandler: decisionHandler)
        }

        private func resolveActionPolicy(
            for navigationAction: WKNavigationAction,
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

            if !Self.isWebHandledScheme(scheme) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
                decisionHandler(.cancel)
                return
            }

            let neverRenderExtensions: Set<String> = [
                "ipa", "apk", "exe", "msi", "dmg", "pkg", "deb", "appimage"
            ]
            if neverRenderExtensions.contains(url.pathExtension.lowercased()) {
                decisionHandler(.download)
                return
            }

            decisionHandler(.allow)
        }

        private static func isWebHandledScheme(_ scheme: String) -> Bool {
            ["http", "https", "about", "blob", "data", "file"].contains(scheme)
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
                || mime.hasPrefix("application/pdf") && isAttachment
                || mime.hasPrefix("application/x-")
                || mime.hasPrefix("application/vnd")
                || mime.hasPrefix("audio/")
                || mime.hasPrefix("video/") && isAttachment

            let neverRenderExtensions: Set<String> = [
                "ipa", "apk", "exe", "msi", "dmg", "pkg", "deb", "appimage"
            ]
            let downloadishExtension = neverRenderExtensions.contains(requestURL.pathExtension.lowercased())

            if isAttachment || notRenderable || downloadishMIME || downloadishExtension {
                let suggested = filenameHint(response: response, url: requestURL)

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
                }

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

                return UIMenu(title: imageURL != nil ? "Image" : (linkURL?.absoluteString ?? ""), children: actions)
            }

            completionHandler(configuration)
        }

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
    private var rimLayer: CAShapeLayer?
    private var buttonGradients: [CAGradientLayer] = []
    private var buttonContainers: [UIView] = []

    private let cardFlat = UIColor(red: 35 / 255, green: 50 / 255, blue: 91 / 255, alpha: 1)
    private let cardGlossTop = UIColor(red: 157 / 255, green: 159 / 255, blue: 174 / 255, alpha: 1)

    private let pillTop = UIColor(red: 173 / 255, green: 181 / 255, blue: 199 / 255, alpha: 1)
    private let pillMidUpper = UIColor(red: 130 / 255, green: 141 / 255, blue: 164 / 255, alpha: 1)
    private let pillMidLower = UIColor(red: 96 / 255, green: 108 / 255, blue: 136 / 255, alpha: 1)
    private let pillBottom = UIColor(red: 72 / 255, green: 85 / 255, blue: 116 / 255, alpha: 1)

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
        shadowContainer.backgroundColor = .clear
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

        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = cardFlat
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

        cardGradient.colors = [
            cardGlossTop.cgColor,
            cardFlat.cgColor,
            cardFlat.cgColor
        ]
        cardGradient.locations = [0, 0.20, 1.0]
        cardGradient.frame = CGRect(x: 0, y: 0, width: width, height: 220)
        card.layer.insertSublayer(cardGradient, at: 0)

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
        outerStack.backgroundColor = .clear
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
        textStack.backgroundColor = .clear
        textStack.isLayoutMarginsRelativeArrangement = true
        textStack.layoutMargins = UIEdgeInsets(top: 18, left: 16, bottom: 16, right: 16)
        outerStack.addArrangedSubview(textStack)

        let titleLabel = UILabel()
        titleLabel.text = alertTitle?.isEmpty == false ? alertTitle : "Safari"
        titleLabel.textAlignment = .center
        titleLabel.font = UIFont(name: "HelveticaNeue-Bold", size: 17) ?? .boldSystemFont(ofSize: 17)
        titleLabel.textColor = .white
        titleLabel.backgroundColor = .clear
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
        messageLabel.backgroundColor = .clear
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
            field.translatesAutoresizingMaskIntoConstraints = false
            textStack.setCustomSpacing(10, after: messageLabel)
            textStack.addArrangedSubview(field)
            input = field
        }

        let hDivider = UIView()
        hDivider.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        hDivider.translatesAutoresizingMaskIntoConstraints = false
        hDivider.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale).isActive = true
        outerStack.addArrangedSubview(hDivider)

        let buttonRow = UIStackView()
        buttonRow.axis = .horizontal
        buttonRow.spacing = 8
        buttonRow.distribution = .fillEqually
        buttonRow.backgroundColor = .clear
        buttonRow.isLayoutMarginsRelativeArrangement = true
        buttonRow.layoutMargins = UIEdgeInsets(top: 10, left: 10, bottom: 12, right: 10)
        buttonRow.translatesAutoresizingMaskIntoConstraints = false
        outerStack.addArrangedSubview(buttonRow)
        buttonRow.heightAnchor.constraint(equalToConstant: 66).isActive = true

        for (index, item) in buttons.enumerated() {
            let (pill, gradient) = makePillButton(title: item.0, tag: index)
            buttonRow.addArrangedSubview(pill)
            buttonContainers.append(pill)
            buttonGradients.append(gradient)
        }
    }

    private func makePillButton(title: String, tag: Int) -> (UIView, CAGradientLayer) {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = pillBottom
        container.layer.cornerRadius = 8
        container.layer.masksToBounds = true
        container.layer.borderWidth = 1 / UIScreen.main.scale
        container.layer.borderColor = UIColor(white: 0.02, alpha: 0.85).cgColor

        let gradient = CAGradientLayer()
        gradient.colors = [
            pillTop.cgColor,
            pillMidUpper.cgColor,
            pillMidLower.cgColor,
            pillBottom.cgColor
        ]
        gradient.locations = [0, 0.42, 0.43, 1.0]
        gradient.frame = CGRect(x: 0, y: 0, width: 120, height: 44)
        container.layer.insertSublayer(gradient, at: 0)

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

        return (container, gradient)
    }

    @objc private func handlePillHighlight(_ sender: UIButton) {
        sender.superview?.layer.opacity = 0.7
    }

    @objc private func handlePillUnhighlight(_ sender: UIButton) {
        sender.superview?.layer.opacity = 1.0
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        guard card.bounds.width > 0, card.bounds.height > 0 else { return }

        cardGradient.frame = card.bounds
        rimLayer?.frame = card.bounds
        rimLayer?.path = UIBezierPath(
            roundedRect: card.bounds.insetBy(dx: 1.5, dy: 1.5),
            cornerRadius: 11.5
        ).cgPath

        for (index, container) in buttonContainers.enumerated() {
            guard container.bounds.width > 0, container.bounds.height > 0 else { continue }
            buttonGradients[index].frame = container.bounds
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
