import Combine
import Foundation
import UIKit
import WebKit

/// One entry of a tab's WebKit back/forward list, used by the long press
/// history preview on the toolbar arrows.
struct SafariNavigationItem: Identifiable {
    let id = UUID()
    let title: String
    let host: String
    let item: WKBackForwardListItem
}

/// One browser tab backed by a single WKWebView. WebKit remains the source
/// of truth for navigation state; KVO/Combine republishes it to SwiftUI.
final class SafariTab: Identifiable, ObservableObject, Equatable {

    let id = UUID()
    let webView: WKWebView
    let isPrivate: Bool
    let createdAt = Date()

    @Published private(set) var title: String = ""
    @Published private(set) var url: URL?
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var estimatedProgress: Double = 0
    @Published private(set) var canGoBack: Bool = false
    @Published private(set) var canGoForward: Bool = false
    @Published private(set) var isSecure: Bool = false
    @Published var isRequestingDesktopSite: Bool = false

    /// Reader Mode. `readerAvailable` reflects whether the page carries enough
    /// article-like markup for the Reader script to render something usable;
    /// `isReaderActive` is toggled by the toolbar.
    @Published private(set) var readerAvailable: Bool = false
    @Published private(set) var isReaderActive: Bool = false

    /// Content blocker toggle mirrors Safari's per-site Content Blockers.
    /// Persisted separately per host.
    @Published var isContentBlockerEnabled: Bool = SafariTab.defaultBlockerEnabled

    var onFinishedLoading: ((SafariTab) -> Void)?

    private var cancellables = Set<AnyCancellable>()

    private static let desktopUserAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " +
        "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"

    private static var defaultBlockerEnabled: Bool {
        UserDefaults.standard.object(forKey: "OldSafari.ContentBlocker") as? Bool ?? true
    }

    /// A restored page keeps its URL but does not hit the network until the
    /// browser actually mounts its web view, so a cold launch with eight open
    /// pages costs one request instead of eight.
    private var pendingURL: URL?

    init(url: URL?, isPrivate: Bool, deferLoad: Bool = false) {
        self.isPrivate = isPrivate

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = isPrivate ? .nonPersistent() : .default()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = true

        // Never lock the web content (or its keyboard, selection handles and
        // context menus) to a fixed appearance. Both Normal and Private mode
        // only theme the custom Safari chrome drawn by this app; the actual
        // page content and every system-provided control must keep following
        // the device's own Light/Dark Mode setting, exactly like the current
        // Safari does.
        webView.overrideUserInterfaceStyle = .unspecified

        // Do not spoof a fixed historical iOS version. WebKit's native UA
        // tracks the installed OS and prevents modern sites such as Google
        // from serving incompatible markup or feature-detection results.
        webView.customUserAgent = nil

        self.webView = webView

        // Inject the blob download bridge so pages that stream files via
        // `URL.createObjectURL` (Google Drive export, GitHub archive links,
        // Wikipedia PDFs) surface through WKDownload the same way normal
        // Content-Disposition responses do.
        injectBlobDownloadShim(into: webView)

        observeWebView()

        if let url {
            // Always defer, unconditionally: `activateIfNeeded()` is the
            // only code path allowed to call `webView.load()` for an
            // initial URL, and it is only ever invoked from
            // `SafariWebView.makeUIView` — which sets both
            // `navigationDelegate` and `uiDelegate` BEFORE calling it.
            // Calling `.load()` synchronously here, inside the
            // initializer, used to race ahead of those delegate
            // assignments (which only happen on a LATER SwiftUI render
            // pass, after `tabs.append(tab)` schedules a UI update), so
            // the tab's very first navigation — every tab opened via
            // `window.open()` / target="_blank", i.e. exactly the
            // "Download IPA" flow — could proceed with no delegate at
            // all, silently skipping every download/scheme/MIME check
            // for that one request.
            pendingURL = url
            self.url = url
            self.isSecure = url.scheme?.lowercased() == "https"
        }
    }

    /// Called when the web view is mounted for the first time.
    func activateIfNeeded() {
        guard let pendingURL else { return }
        self.pendingURL = nil
        webView.load(URLRequest(url: pendingURL))
    }

    static func == (lhs: SafariTab, rhs: SafariTab) -> Bool {
        lhs.id == rhs.id
    }

    private func observeWebView() {
        webView.publisher(for: \.title)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.title = $0 ?? "" }
            .store(in: &cancellables)

        webView.publisher(for: \.url)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newURL in
                guard let self else { return }
                // A restored page has a URL before WebKit does; do not let the
                // initial nil from the observer wipe it.
                if newURL == nil, self.pendingURL != nil { return }
                self.url = newURL
                self.isSecure = newURL?.scheme?.lowercased() == "https"
                // Reset per-page state.
                self.readerAvailable = false
                self.isReaderActive = false
            }
            .store(in: &cancellables)

        webView.publisher(for: \.estimatedProgress)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.estimatedProgress = $0 }
            .store(in: &cancellables)

        webView.publisher(for: \.canGoBack)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.canGoBack = $0 }
            .store(in: &cancellables)

        webView.publisher(for: \.canGoForward)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.canGoForward = $0 }
            .store(in: &cancellables)

        webView.publisher(for: \.isLoading)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] loading in
                guard let self else { return }
                self.isLoading = loading

                if !loading, self.url != nil {
                    self.detectReaderAvailability()
                    self.onFinishedLoading?(self)
                    NotificationCenter.default.post(
                        name: .oldSafariURLChanged,
                        object: nil
                    )
                }
            }
            .store(in: &cancellables)
    }

    /// Most recent first, like the modern Safari long press menu.
    var backItems: [SafariNavigationItem] {
        webView.backForwardList.backList.reversed().map(Self.navigationItem)
    }

    var forwardItems: [SafariNavigationItem] {
        webView.backForwardList.forwardList.map(Self.navigationItem)
    }

    private static func navigationItem(_ item: WKBackForwardListItem) -> SafariNavigationItem {
        let title = item.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let host = item.url.host ?? item.url.absoluteString
        return SafariNavigationItem(
            title: title.isEmpty ? host : title,
            host: host,
            item: item
        )
    }

    func go(to entry: SafariNavigationItem) {
        webView.go(to: entry.item)
    }

    func load(_ url: URL) {
        webView.load(URLRequest(url: url))
    }

    func reload() {
        webView.reload()
    }

    func stop() {
        webView.stopLoading()
    }

    func goBack() {
        webView.goBack()
    }

    func goForward() {
        webView.goForward()
    }

    func toggleDesktopSite() {
        isRequestingDesktopSite.toggle()
        webView.customUserAgent = isRequestingDesktopSite ? Self.desktopUserAgent : nil
        webView.reload()
    }

    func findOnPage() {
        if #available(iOS 16.0, *) {
            webView.findInteraction?.presentFindNavigator(showingReplace: false)
        }
    }

    // MARK: - Reader Mode

    /// Very compact Readability-style detector. Runs after page load and sets
    /// `readerAvailable` so the address bar can offer the Reader glyph.
    private func detectReaderAvailability() {
        let script = """
        (function() {
            const candidates = document.querySelectorAll('article, [role="article"], main, [itemprop="articleBody"]');
            let best = null; let bestLen = 0;
            for (const c of candidates) {
                const t = (c.innerText || '').length;
                if (t > bestLen) { best = c; bestLen = t; }
            }
            if (!best) {
                const ps = document.querySelectorAll('p');
                let sum = 0;
                for (const p of ps) sum += (p.innerText || '').length;
                if (sum > 1400) return true;
                return false;
            }
            return bestLen > 900;
        })();
        """
        webView.evaluateJavaScript(script) { [weak self] result, _ in
            guard let self else { return }
            let available = (result as? Bool) ?? false
            DispatchQueue.main.async {
                self.readerAvailable = available
            }
        }
    }

    func toggleReader() {
        if isReaderActive {
            reload()
            isReaderActive = false
        } else {
            enterReader()
        }
        NotificationCenter.default.post(name: .oldSafariReaderChanged, object: nil)
    }

    private func enterReader() {
        // A minimal reader: pick the largest article-ish node, extract its
        // text and headings, then paint them on a warm off-white sheet with
        // the app's Helvetica Neue face. Not the full Reader engine, but
        // exactly what iOS 6 Safari's Reader gave the user.
        let script = """
        (function() {
            function pickArticle() {
                const cands = document.querySelectorAll('article, [role="article"], main, [itemprop="articleBody"]');
                let best = null; let bestLen = 0;
                cands.forEach(c => {
                    const t = (c.innerText || '').length;
                    if (t > bestLen) { best = c; bestLen = t; }
                });
                if (best) return best;
                let node = null; let max = 0;
                document.querySelectorAll('div, section').forEach(d => {
                    const t = (d.innerText || '').length;
                    if (t > max) { max = t; node = d; }
                });
                return node || document.body;
            }
            const root = pickArticle();
            const title = document.title || '';
            const html = root ? root.innerHTML : document.body.innerHTML;
            return { title: title, html: html };
        })();
        """
        webView.evaluateJavaScript(script) { [weak self] result, _ in
            guard let self,
                  let dict = result as? [String: Any],
                  let html = dict["html"] as? String
            else { return }

            let title = (dict["title"] as? String) ?? "Reader"
            let doc = SafariTab.readerDocument(title: title, body: html)
            let base = self.webView.url
            DispatchQueue.main.async {
                self.webView.loadHTMLString(doc, baseURL: base)
                self.isReaderActive = true
            }
        }
    }

    private static func readerDocument(title: String, body: String) -> String {
        let escapedTitle = title
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
        return """
        <!doctype html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>\(escapedTitle)</title>
        <style>
        body { font-family: -apple-system, "HelveticaNeue", sans-serif; background: #f7f3ea; color: #1c1c1e; padding: 20px; line-height: 1.5; font-size: 19px; }
        h1 { font-size: 26px; margin-bottom: 12px; }
        img { max-width: 100%; height: auto; }
        </style>
        </head>
        <body>
        <h1>\(escapedTitle)</h1>
        \(body)
        </body>
        </html>
        """
    }

    // MARK: - Blob download shim

    /// Pages that use `URL.createObjectURL(blob)` to trigger downloads bypass
    /// WKDownload because WebKit will not schedule a network request for a
    /// blob URL. This shim rewrites those anchors so the blob is base64
    /// encoded and shipped through the app via the `oldsafari-download://`
    /// URL scheme, which the navigation delegate turns back into a real file.
    private func injectBlobDownloadShim(into webView: WKWebView) {
        let source = """
        (function() {
            document.addEventListener('click', function(event) {
                let a = event.target.closest && event.target.closest('a');
                if (!a) return;
                const href = a.getAttribute('href') || '';
                const hasDownload = a.hasAttribute('download');
                if (!hasDownload) return;
                if (!href.startsWith('blob:') && !href.startsWith('data:')) return;

                event.preventDefault();
                const name = a.getAttribute('download') || 'download';

                fetch(href).then(r => r.blob()).then(blob => {
                    const reader = new FileReader();
                    reader.onload = function() {
                        const payload = String(reader.result || '').split(',')[1] || '';
                        const target = 'oldsafari-download://save?name=' +
                            encodeURIComponent(name) + '&data=' + encodeURIComponent(payload);
                        window.location = target;
                    };
                    reader.readAsDataURL(blob);
                }).catch(function() {});
            }, true);
        })();
        """
        let script = WKUserScript(
            source: source,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        webView.configuration.userContentController.addUserScript(script)
    }
}
