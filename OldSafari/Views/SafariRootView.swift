import SwiftUI
import UIKit

/// Full-screen Safari shell.  The chrome geometry is OldOS' (60pt title bar,
/// 45pt toolbar) but it is laid out against the real device safe areas so the
/// browser stays edge to edge instead of being letterboxed into a 320x480 frame.
struct SafariRootView: View {
    @StateObject private var store = SafariTabStore()
    @StateObject private var safeArea = OldOSSafeArea()

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
    }

    private var theme: OldOSSafariTheme {
        OldOSSafariTheme.theme(isPrivate: store.isPrivateMode)
    }
}

private struct SafariSelectedTabView: View {
    @ObservedObject var store: SafariTabStore
    @ObservedObject var tab: SafariTab

    let theme: OldOSSafariTheme
    let topInset: CGFloat
    let bottomInset: CGFloat

    @Binding var showTabs: Bool
    @Binding var showLibrary: Bool
    @Binding var showShare: Bool

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

            if showShare {
                SafariActionsView(
                    store: store,
                    tab: tab,
                    theme: theme,
                    topInset: topInset,
                    bottomInset: bottomInset,
                    onClose: {
                        withAnimation(.linear(duration: 0.25)) { showShare = false }
                    }
                )
                .transition(.move(edge: .bottom))
                .zIndex(30)
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
                    SafariWebView(tab: tab)
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
                onBack: { tab.goBack() },
                onForward: { tab.goForward() },
                onShare: { withAnimation(.linear(duration: 0.25)) { showShare = true } },
                onBookmarks: { withAnimation(.linear(duration: 0.25)) { showLibrary = true } },
                onTabs: { withAnimation(.linear(duration: 0.25)) { showTabs = true } }
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
                onSearch: search
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
