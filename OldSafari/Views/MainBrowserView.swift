import SwiftUI

public struct MainBrowserView: View {
    @State private var tabs: [TabItem] = [TabItem()]
    @State private var activeTabId: UUID = UUID()
    @State private var isPrivate: Bool = false
    
    @State private var urlString: String = "https://www.google.com"
    @State private var isLoading: Bool = false
    @State private var loadProgress: Double = 0.0
    @State private var canGoBack: Bool = false
    @State private var canGoForward: Bool = false
    @State private var pageTitle: String = "Google"
    
    @State private var showBookmarks: Bool = false
    @State private var showTabsView: Bool = false
    @State private var showShareSheet: Bool = false
    
    public init() {}

    public var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Top Address Bar Area (iOS 6 Style)
                HStack(spacing: 6) {
                    AddressBarView(
                        urlText: $urlString,
                        isLoading: $isLoading,
                        progress: $loadProgress,
                        isPrivate: isPrivate,
                        onCommit: {
                            loadURL()
                        },
                        onReloadOrStop: {
                            if isLoading {
                                isLoading = false
                            } else {
                                loadURL()
                            }
                        }
                    )
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(isPrivate ? iOS6Theme.navBarGradientPrivate : iOS6Theme.navBarGradientNormal)
                .overlay(
                    VStack {
                        Spacer()
                        Rectangle()
                            .fill(Color.black.opacity(0.6))
                            .frame(height: 1)
                    }
                )

                // Full Screen WKWebView
                SafariWebView(
                    urlString: $urlString,
                    isLoading: $isLoading,
                    progress: $loadProgress,
                    canGoBack: $canGoBack,
                    canGoForward: $canGoForward,
                    pageTitle: $pageTitle,
                    isPrivate: isPrivate
                )
                .edgesIgnoringSafeArea(.horizontal)

                // Bottom Skeuomorphic Toolbar
                iOS6Toolbar(
                    canGoBack: canGoBack,
                    canGoForward: canGoForward,
                    isPrivate: isPrivate,
                    tabCount: tabs.count,
                    onBack: {
                        // Action handled via webview back
                    },
                    onForward: {
                        // Action handled via webview forward
                    },
                    onShare: {
                        withAnimation { showShareSheet = true }
                    },
                    onBookmarks: {
                        showBookmarks = true
                    },
                    onTabs: {
                        showTabsView = true
                    }
                )
            }
            .edgesIgnoringSafeArea(.bottom)

            // iOS 6 Action Sheet (Share Sheet Overlay)
            iOS6ActionSheet(
                isPresented: $showShareSheet,
                isPrivate: isPrivate,
                pageTitle: pageTitle,
                pageURL: urlString,
                onAddBookmark: {
                    SafariDataManager.shared.addBookmark(title: pageTitle, url: urlString)
                },
                onAddToHomeScreen: {
                    // Placeholder for PWA / Home screen shortcut
                },
                onCopyLink: {
                    UIPasteboard.general.string = urlString
                }
            )
        }
        .sheet(isPresented: $showBookmarks) {
            BookmarksHistoryView(isPrivate: isPrivate) { selectedURL in
                self.urlString = selectedURL
                self.loadURL()
            }
        }
        .sheet(isPresented: $showTabsView) {
            TabsView(
                tabs: $tabs,
                activeTabId: $activeTabId,
                isPrivate: $isPrivate,
                onNewTab: {
                    let newT = TabItem(isPrivate: isPrivate)
                    tabs.append(newT)
                    activeTabId = newT.id
                    urlString = "https://www.google.com"
                },
                onClose: {
                    showTabsView = false
                }
            )
        }
        .onAppear {
            if let first = tabs.first {
                activeTabId = first.id
            }
        }
    }

    private func loadURL() {
        var formatted = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if formatted.isEmpty { return }
        
        if !formatted.contains(".") && !formatted.hasPrefix("http") {
            if let query = formatted.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                formatted = "https://www.google.com/search?q=\(query)"
            }
        } else if !formatted.hasPrefix("http://") && !formatted.hasPrefix("https://") {
            formatted = "https://" + formatted
        }
        urlString = formatted
    }
}
