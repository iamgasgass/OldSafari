import Combine
import Foundation
import WebKit

/// One browser tab. Wraps a single `WKWebView` and republishes its
/// KVO-observable properties (`title`, `url`, `isLoading`,
/// `estimatedProgress`, `canGoBack`, `canGoForward`) as `@Published`
/// values so SwiftUI views update live without any manual polling.
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

    /// Called once a top-level navigation finishes, so the tab store
    /// can append a History entry without this type knowing about History.
    var onFinishedLoading: ((SafariTab) -> Void)?

    private var cancellables = Set<AnyCancellable>()
    private static let mobileUserAgent =
        "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 " +
        "(KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
    private static let desktopUserAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 " +
        "(KHTML, like Gecko) Version/18.0 Safari/605.1.15"

    init(url: URL?, isPrivate: Bool) {
        self.isPrivate = isPrivate

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = isPrivate ? .nonPersistent() : .default()
        configuration.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = true
        webView.customUserAgent = Self.mobileUserAgent
        self.webView = webView

        observeWebView()

        if let url {
            webView.load(URLRequest(url: url))
        }
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
                self?.url = newURL
                self?.isSecure = newURL?.scheme?.lowercased() == "https"
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
                    NotificationCenter.default.post(name: .oldSafariURLChanged, object: nil)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Navigation

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

    /// Toggles between the mobile and desktop user agent, then reloads —
    /// mirroring the modern Safari "Request Desktop Website" action.
    func toggleDesktopSite() {
        isRequestingDesktopSite.toggle()
        webView.customUserAgent = isRequestingDesktopSite ? Self.desktopUserAgent : Self.mobileUserAgent
        webView.reload()
    }

    /// Presents the system Find-on-Page UI (native since iOS 16).
    func findOnPage() {
        if #available(iOS 16.0, *) {
            webView.findInteraction?.presentFindNavigator(showingReplace: false)
        }
    }
}
