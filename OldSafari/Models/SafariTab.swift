import Combine
import Foundation
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

    var onFinishedLoading: ((SafariTab) -> Void)?

    private var cancellables = Set<AnyCancellable>()

    private static let desktopUserAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " +
        "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"

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

        observeWebView()

        if let url {
            if deferLoad {
                pendingURL = url
                self.url = url
                self.isSecure = url.scheme?.lowercased() == "https"
            } else {
                webView.load(URLRequest(url: url))
            }
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
}
