import SwiftUI

/// Full-screen Safari shell. The page is laid out *between* the legacy top
/// chrome and bottom toolbar instead of being rendered behind them. This keeps
/// the browser immersive while preserving the physical geometry of classic
/// Safari: top chrome -> web content -> bottom navigation bar.
struct SafariRootView: View {
    @StateObject private var store = SafariTabStore()

    @State private var showTabs = false
    @State private var showLibrary = false
    @State private var showShare = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let tab = store.selected {
                    VStack(spacing: 0) {
                        // The status-bar inset belongs to Safari's chrome, not
                        // to the web page. Consequently the first web pixel
                        // begins immediately below the URL/search controls.
                        chrome(for: tab, topInset: geometry.safeAreaInsets.top)
                            .id("chrome-\(tab.id.uuidString)")
                            .zIndex(2)

                        pageContent(for: tab)
                            .id("page-\(tab.id.uuidString)")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipped()
                            .background(tab.isPrivate ? Color.black : Color.white)
                            .zIndex(1)

                        SafariToolbar(
                            tab: tab,
                            isPrivate: tab.isPrivate,
                            tabCount: store.visibleTabs.count,
                            bottomInset: geometry.safeAreaInsets.bottom,
                            onTabs: { withAnimation(.easeOut(duration: 0.18)) { showTabs = true } },
                            onLibrary: { withAnimation(.easeOut(duration: 0.18)) { showLibrary = true } },
                            onShare: { withAnimation(.easeOut(duration: 0.18)) { showShare = true } }
                        )
                        .zIndex(2)
                    }
                    .ignoresSafeArea()
                    .preferredColorScheme(tab.isPrivate ? .dark : .light)

                    // These are intentionally overlays rather than sheets so
                    // Pages, Bookmarks/History and Share all operate on the
                    // same UUID-selected SafariTab and retain the full-screen
                    // browser underneath them.
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
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .animation(.easeOut(duration: 0.18), value: showTabs)
            .animation(.easeOut(duration: 0.18), value: showLibrary)
            .animation(.easeOut(duration: 0.18), value: showShare)
        }
    }

    @ViewBuilder
    private func pageContent(for tab: SafariTab) -> some View {
        if tab.url == nil {
            SafariStartPageView(store: store, tab: tab)
        } else {
            SafariWebView(tab: tab)
        }
    }

    private func chrome(for tab: SafariTab, topInset: CGFloat) -> some View {
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
