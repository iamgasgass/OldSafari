import SwiftUI

struct SafariRootView: View {
    @StateObject private var store = SafariTabStore()

    @State private var showTabs = false
    @State private var showLibrary = false
    @State private var showShare = false

    private let addressBarHeight: CGFloat = 47
    private let progressHeight: CGFloat = 2
    private let toolbarContentHeight: CGFloat = 48
    private let toolbarGestureClearance: CGFloat = 8

    var body: some View {
        GeometryReader { geometry in
            if let tab = store.selected {
                ZStack(alignment: .top) {
                    pageContent(for: tab)
                        .ignoresSafeArea()
                        // The web view remains edge-to-edge, but its content is
                        // physically displaced below the floating Safari chrome.
                        .padding(.top, geometry.safeAreaInsets.top + addressBarHeight + progressHeight)
                        .padding(.bottom, geometry.safeAreaInsets.bottom + toolbarContentHeight + toolbarGestureClearance)

                    VStack(spacing: 0) {
                        chrome(for: tab, topInset: geometry.safeAreaInsets.top)
                        Spacer(minLength: 0)
                        SafariToolbar(
                            tab: tab,
                            isPrivate: tab.isPrivate,
                            tabCount: store.visibleTabs.count,
                            bottomInset: geometry.safeAreaInsets.bottom,
                            onTabs: { showTabs = true },
                            onLibrary: { showLibrary = true },
                            onShare: { showShare = true }
                        )
                    }
                    .ignoresSafeArea()
                }
                .preferredColorScheme(tab.isPrivate ? .dark : .light)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
            }
        }
        .sheet(isPresented: $showTabs) {
            SafariTabsView(store: store)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showLibrary) {
            SafariLibraryView(store: store, currentTab: store.selected)
        }
        .sheet(isPresented: $showShare) {
            if let tab = store.selected {
                SafariActionsView(store: store, tab: tab)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
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
            SafariProgressBar(
                progress: tab.estimatedProgress,
                isLoading: tab.isLoading
            )
        }
        .background(
            chromeGradient(isPrivate: tab.isPrivate)
                .ignoresSafeArea(edges: .top)
        )
    }

    private func chromeGradient(isPrivate: Bool) -> LinearGradient {
        LinearGradient(
            colors: isPrivate
                ? [OldSafariPalette.chromeTopPrivate, OldSafariPalette.chromeBottomPrivate]
                : [OldSafariPalette.chromeTop, OldSafariPalette.chromeBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
