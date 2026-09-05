import SwiftUI

struct SafariRootView: View {
    @StateObject private var store = SafariTabStore()

    @State private var showTabs = false
    @State private var showLibrary = false
    @State private var showShare = false

    var body: some View {
        GeometryReader { geometry in
            if let tab = store.selected {
                ZStack(alignment: .top) {
                    pageContent(for: tab)
                        .id(tab.id)
                        .ignoresSafeArea()

                    VStack(spacing: 0) {
                        chrome(for: tab, topInset: geometry.safeAreaInsets.top)
                        Spacer(minLength: 0)
                        SafariToolbar(
                            tab: tab,
                            isPrivate: tab.isPrivate,
                            tabCount: store.visibleTabs.count,
                            bottomInset: geometry.safeAreaInsets.bottom,
                            onTabs: { withAnimation(.easeOut(duration: 0.18)) { showTabs = true } },
                            onLibrary: { withAnimation(.easeOut(duration: 0.18)) { showLibrary = true } },
                            onShare: { withAnimation(.easeOut(duration: 0.18)) { showShare = true } }
                        )
                    }
                    .ignoresSafeArea()

                    // Custom full-screen overlays deliberately stay in the same
                    // view tree as the selected WKWebView. No NavigationStack or
                    // sheet owns the selection, so changing pages cannot display
                    // a stale tab after dismissing Pages/Library/Share.
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
                .preferredColorScheme(tab.isPrivate ? .dark : .light)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
            }
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
