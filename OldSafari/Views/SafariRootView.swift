import SwiftUI

/// Full-screen Safari shell. The selected tab is observed by a dedicated
/// child view so WKWebView/KVO changes (URL, progress, loading, title) update
/// the chrome immediately without requiring a trip through Pages.
struct SafariRootView: View {
    @StateObject private var store = SafariTabStore()

    @State private var showTabs = false
    @State private var showLibrary = false
    @State private var showShare = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let tab = store.selected {
                    SafariSelectedTabView(
                        store: store,
                        tab: tab,
                        topInset: geometry.safeAreaInsets.top,
                        bottomInset: geometry.safeAreaInsets.bottom,
                        showTabs: $showTabs,
                        showLibrary: $showLibrary,
                        showShare: $showShare
                    )
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
        }
    }
}

/// Important: this view owns the observation of the selected SafariTab.
/// SafariRootView observes the store for selection changes; this child observes
/// the tab itself for URL/title/loading/progress changes. That closes the gap
/// where a newly loaded URL could leave the old start page visible until Pages
/// was opened and the tab was selected again.
private struct SafariSelectedTabView: View {
    @ObservedObject var store: SafariTabStore
    @ObservedObject var tab: SafariTab

    let topInset: CGFloat
    let bottomInset: CGFloat

    @Binding var showTabs: Bool
    @Binding var showLibrary: Bool
    @Binding var showShare: Bool

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                chrome
                    .id("chrome-\(tab.id.uuidString)")
                    .zIndex(2)

                // Keep the WKWebView in the actual content slot. It is never
                // positioned underneath the top chrome, while remaining
                // completely fullscreen relative to the device window.
                pageContent
                    .id("page-\(tab.id.uuidString)-\(tab.url?.absoluteString ?? "blank")")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .background(tab.isPrivate ? Color.black : Color.white)
                    .zIndex(1)

                SafariToolbar(
                    tab: tab,
                    isPrivate: tab.isPrivate,
                    tabCount: store.visibleTabs.count,
                    bottomInset: bottomInset,
                    onTabs: { withAnimation(.easeOut(duration: 0.18)) { showTabs = true } },
                    onLibrary: { withAnimation(.easeOut(duration: 0.18)) { showLibrary = true } },
                    onShare: { withAnimation(.easeOut(duration: 0.18)) { showShare = true } }
                )
                .zIndex(2)
            }
            .ignoresSafeArea()
            .preferredColorScheme(tab.isPrivate ? .dark : .light)

            if showTabs {
                SafariTabsView(store: store) {
                    withAnimation(.easeOut(duration: 0.18)) { showTabs = false }
                }
                .transition(.opacity)
                .zIndex(20)
            }

            if showLibrary {
                SafariLibraryView(store: store) {
                    withAnimation(.easeOut(duration: 0.18)) { showLibrary = false }
                }
                .transition(.move(edge: .bottom))
                .zIndex(21)
            }

            if showShare {
                SafariActionsView(store: store) {
                    withAnimation(.easeOut(duration: 0.18)) { showShare = false }
                }
                .transition(.move(edge: .bottom))
                .zIndex(22)
            }
        }
        .animation(.easeOut(duration: 0.18), value: showTabs)
        .animation(.easeOut(duration: 0.18), value: showLibrary)
        .animation(.easeOut(duration: 0.18), value: showShare)
    }

    @ViewBuilder
    private var pageContent: some View {
        // Always mount SafariWebView. This is the key dynamic-load fix: a new
        // tab can start blank and then receive a URL without replacing the
        // browser surface with a separate stale SwiftUI start-page instance.
        if tab.url == nil {
            SafariStartPageView(store: store, tab: tab)
        }
        SafariWebView(tab: tab)
            .opacity(tab.url == nil ? 0 : 1)
            .allowsHitTesting(tab.url != nil)
    }

    private var chrome: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: topInset)
            SafariSearchRow(tab: tab, isPrivate: tab.isPrivate)
            SafariProgressBar(progress: tab.estimatedProgress, isLoading: tab.isLoading)
        }
        .background(
            LinearGradient(
                colors: tab.isPrivate
                    ? [OldSafariPalette.chromeTopPrivate, OldSafariPalette.chromeBottomPrivate]
                    : [OldSafariPalette.chromeTop, OldSafariPalette.chromeBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        )
    }
}
