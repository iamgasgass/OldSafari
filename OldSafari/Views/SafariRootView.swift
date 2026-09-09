import SwiftUI
import UIKit

/// Full-screen Safari shell.  The chrome geometry is OldOS' (60pt title bar,
/// 45pt toolbar) but it is laid out against the real device safe areas so the
/// browser stays edge to edge instead of being letterboxed into a 320x480 frame.
struct SafariRootView: View {
    @StateObject private var store = SafariTabStore()
    @StateObject private var safeArea = OldOSSafeArea()
    @ObservedObject private var downloads = SafariDownloadManager.shared

    @State private var showTabs = false
    @State private var showLibrary = false
    @State private var showShare = false

    var body: some View {
        GeometryReader { geometry in
            let topInset = max(geometry.safeAreaInsets.top, safeArea.insets.top)
            let bottomInset = max(geometry.safeAreaInsets.bottom, safeArea.insets.bottom)

            ZStack {
                theme.appBackground.ignoresSafeArea()

                if let tab = store.selected {
                    SafariSelectedTabView(
                        store: store,
                        downloads: downloads,
                        tab: tab,
                        theme: theme,
                        topInset: topInset,
                        bottomInset: bottomInset,
                        showTabs: $showTabs,
                        showLibrary: $showLibrary,
                        showShare: $showShare
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear { safeArea.refresh() }
        }
        .ignoresSafeArea()
        .statusBarHidden(false)
        // Never force a global appearance on the SwiftUI hierarchy: the
        // system chrome (keyboard, context menus, native share sheet, text
        // selection handles, alerts) must always follow the device's own
        // Light/Dark Mode setting, in Normal and Private browsing alike.
        .preferredColorScheme(nil)
    }

    private var theme: OldOSSafariTheme {
        OldOSSafariTheme.theme(isPrivate: store.isPrivateMode)
    }
}

private struct SafariSelectedTabView: View {
    @ObservedObject var store: SafariTabStore
    @ObservedObject var downloads: SafariDownloadManager
    @ObservedObject var tab: SafariTab

    let theme: OldOSSafariTheme
    let topInset: CGFloat
    let bottomInset: CGFloat

    @Binding var showTabs: Bool
    @Binding var showLibrary: Bool
    @Binding var showShare: Bool

    @State private var historyRequest: SafariHistoryRequest?
    @State private var showPageActions = false
    @State private var editingField: SafariSearchField?
    @State private var urlText: String = ""
    @State private var googleText: String = ""

    var body: some View {
        ZStack {
            if showTabs {
                SafariTabsView(
                    store: store,
                    theme: theme,
                    topInset: topInset,
                    bottomInset: bottomInset,
                    onClose: {
                        withAnimation(.linear(duration: 0.25)) { showTabs = false }
                    }
                )
                .transition(.opacity)
                .zIndex(10)
            } else {
                browser
                    .zIndex(1)
            }

            if showLibrary {
                SafariLibraryView(
                    store: store,
                    theme: theme,
                    topInset: topInset,
                    bottomInset: bottomInset,
                    onClose: {
                        withAnimation(.linear(duration: 0.25)) { showLibrary = false }
                    }
                )
                .transition(.move(edge: .bottom))
                .zIndex(20)
            }

            if let historyRequest {
                SafariHistoryPreviewPanel(
                    theme: theme,
                    request: historyRequest,
                    liftFromBottom: bottomInset + 51,
                    onSelect: { entry in
                        tab.go(to: entry)
                        withAnimation(.easeOut(duration: 0.18)) { self.historyRequest = nil }
                    },
                    onDismiss: {
                        withAnimation(.easeOut(duration: 0.18)) { self.historyRequest = nil }
                    }
                )
                .transition(
                    .scale(scale: 0.9, anchor: .bottom).combined(with: .opacity)
                )
                .zIndex(25)
            }

            if showPageActions {
                OldOSActionSheet(
                    theme: theme,
                    buttons: [
                        OldOSSheetButton(title: "New Page") {
                            withAnimation(.linear(duration: 0.2)) { showPageActions = false }
                            store.addTab()
                        },
                        OldOSSheetButton(title: "Close This Page") {
                            withAnimation(.linear(duration: 0.2)) { showPageActions = false }
                            store.close(tab)
                        },
                        OldOSSheetButton(title: "Close All Pages", destructive: true) {
                            withAnimation(.linear(duration: 0.2)) { showPageActions = false }
                            store.closeAll()
                        }
                    ],
                    bottomInset: bottomInset,
                    onCancel: {
                        withAnimation(.linear(duration: 0.2)) { showPageActions = false }
                    }
                )
                .transition(.move(edge: .bottom))
                .zIndex(28)
            }

            if showShare {
                SafariActionsView(
                    store: store,
                    tab: tab,
                    downloads: downloads,
                    theme: theme,
                    topInset: topInset,
                    bottomInset: bottomInset,
                    onClose: {
                        withAnimation(.linear(duration: 0.25)) { showShare = false }
                    },
                    onShowDownloads: {
                        withAnimation(.linear(duration: 0.25)) { showShare = false }
                        // Give the share sheet a beat to slide off before the
                        // Downloads panel slides on, otherwise the two curtains
                        // step on each other's animations.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                            withAnimation(.linear(duration: 0.25)) {
                                downloads.showDownloadsPanel = true
                            }
                        }
                    }
                )
                .transition(.move(edge: .bottom))
                .zIndex(30)
            }

            if downloads.showDownloadsPanel {
                SafariDownloadsView(
                    manager: downloads,
                    theme: theme,
                    topInset: topInset,
                    bottomInset: bottomInset,
                    onClose: {
                        withAnimation(.linear(duration: 0.25)) {
                            downloads.showDownloadsPanel = false
                        }
                    }
                )
                .transition(.move(edge: .bottom))
                .zIndex(40)
            }
        }
        .onAppear { syncURLText() }
        .onChange(of: tab.id) { _ in
            editingField = nil
            syncURLText()
        }
        .onReceive(tab.$url) { _ in
            if editingField == nil { syncURLText() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .oldSafariDownloadStarted)) { _ in
            // Auto-reveal the panel the first time a download begins so users
            // discover it, exactly like recent Safari does the first time.
            if UserDefaults.standard.bool(forKey: "OldSafari.SeenDownloadsPanel") == false {
                UserDefaults.standard.set(true, forKey: "OldSafari.SeenDownloadsPanel")
                withAnimation(.linear(duration: 0.25)) {
                    downloads.showDownloadsPanel = true
                }
            }
        }
    }

    private func presentHistory(title: String, items: [SafariNavigationItem], anchor: CGFloat) {
        guard !items.isEmpty else { return }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
            historyRequest = SafariHistoryRequest(
                title: title,
                items: Array(items.prefix(12)),
                anchor: anchor
            )
        }
    }

    // MARK: Browser

    private var browser: some View {
        VStack(spacing: 0) {
            chrome.zIndex(2)

            ZStack {
                theme.pageBackground

                if tab.url == nil {
                    SafariStartPageView(store: store, tab: tab, theme: theme)
                } else {
                    SafariWebView(tab: tab) { url in
                        store.addTab(url: url)
                    }
                }

                if editingField != nil {
                    theme.scrim
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.linear(duration: 0.22)) { editingField = nil }
                            oldOSHideKeyboard()
                            syncURLText()
                        }
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .zIndex(1)

            SafariToolbar(
                theme: theme,
                canGoBack: tab.canGoBack,
                canGoForward: tab.canGoForward,
                mode: .browsing,
                tabCount: store.visibleTabs.count,
                isPrivate: store.isPrivateMode,
                bottomInset: bottomInset,
                downloadCount: downloads.runningCount,
                onBack: { tab.goBack() },
                onForward: { tab.goForward() },
                onShare: { withAnimation(.linear(duration: 0.25)) { showShare = true } },
                onBookmarks: { withAnimation(.linear(duration: 0.25)) { showLibrary = true } },
                onTabs: { withAnimation(.linear(duration: 0.25)) { showTabs = true } },
                onBackHistory: {
                    presentHistory(title: "Back", items: tab.backItems, anchor: 0.1)
                },
                onForwardHistory: {
                    presentHistory(title: "Forward", items: tab.forwardItems, anchor: 0.3)
                },
                onTabsLongPress: {
                    withAnimation(.linear(duration: 0.25)) { showPageActions = true }
                },
                onDownloadsTap: {
                    withAnimation(.linear(duration: 0.25)) {
                        downloads.showDownloadsPanel = true
                    }
                }
            )
            .zIndex(2)
        }
    }

    private var chrome: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: topInset)

            SafariSearchRow(
                tab: tab,
                theme: theme,
                editingField: $editingField,
                urlText: $urlText,
                googleText: $googleText,
                onNavigate: navigate,
                onSearch: search,
                onToggleReader: { tab.toggleReader() }
            )
        }
        .background(
            LinearGradient(oldOS: theme.barGradient)
                .ignoresSafeArea(edges: .top)
        )
    }

    // MARK: Actions

    private func syncURLText() {
        urlText = tab.url?.absoluteString ?? ""
    }

    /// OldOS URL heuristics: honour an explicit scheme, promote `www.` and
    /// otherwise assume https.  Anything that clearly is not a host is handed
    /// to Google, the way iOS 6's unified behaviour ended up working.
    private func navigate(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            if let url = URL(string: trimmed) { tab.load(url) }
        } else if trimmed.contains(" ") || !trimmed.contains(".") {
            search(trimmed)
        } else if let url = URL(string: "https://\(trimmed)") {
            tab.load(url)
        }
        editingField = nil
    }

    private func search(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
        if let url = URL(string: "https://google.com/search?q=\(encoded)") {
            tab.load(url)
        }
        editingField = nil
    }
}
