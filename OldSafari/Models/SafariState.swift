import SwiftUI
import WebKit

class SafariState: ObservableObject {
    @Published var currentURLString: String = "https://www.google.com"
    @Published var pageTitle: String = "Google"
    @Published var isLoading: Bool = false
    @Published var estimatedProgress: Double = 0.0
    
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    
    @Published var isPrivateMode: Bool = false
    @Published var isFullScreen: Bool = false
    @Published var activeTabCount: Int = 1
    
    @Published var showBookmarks: Bool = false
    @Published var showShareSheet: Bool = false
    
    @Published var history: [URL] = []
    @Published var bookmarks: [URL] = [
        URL(string: "https://www.apple.com")!,
        URL(string: "https://www.google.com")!,
        URL(string: "http://github.com/iamgasgass/OldSafari")!
    ]
    
    var webView: WKWebView?
}
