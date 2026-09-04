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
                        .ignoresSafeArea(edges: .bottom)

                    VStack(spacing: 0) {
                        chrome(for: tab, topInset: geometry.safeAreaInsets.top)
                        Spacer(minLength: 0)
                        SafariToolbar(
                            tab: tab,
                            isPrivate: tab.isPrivate,
                            tabCount: store.visibleTabs.count,
                            onTabs: { showTabs = true },
                            onLibrary: { showLibrary = true },
                            onShare: { showShare = true }
                        )
                        .padding(.bottom, geometry.safeAreaInsets.bottom)
                        .background(
                            (tab.isPrivate ? OldSafariPalette.chromeBottomPrivate : OldSafariPalette.chromeBottom)
                                .ignoresSafeArea(edges: .bottom)
                        )
                    }
                    .ignoresSafeArea(edges: [.top, .bottom])
                }
                .preferredColorScheme(tab.isPrivate ? .dark : .light)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .sheet(isPresented: $showTabs) {
            SafariTabsView(store: store).presentationDetents([.large])
        }
        .sheet(isPresented: $showLibrary) {
            SafariLibraryView(store: store, currentTab: store.selected)
        }
        .sheet(isPresented: $showShare) {
            if let url = store.selected?.webView.url {
                ShareSheet(items: [url])
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
            SafariAddressBar(tab: tab, isPrivate: tab.isPrivate)
            SafariProgressBar(progress: tab.estimatedProgress, isLoading: tab.isLoading)
        }
        .background(
            (tab.isPrivate ? OldSafariPalette.chromeTopPrivate : OldSafariPalette.chromeTop)
                .ignoresSafeArea(edges: .top)
        )
    }
}
