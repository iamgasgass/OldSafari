import Foundation

public struct BookmarkItem: Identifiable, Codable, Equatable {
    public var id: UUID
    public var title: String
    public var url: String
    public var dateAdded: Date
    public var isFolder: Bool
    public var parentId: UUID?
    
    public init(id: UUID = UUID(), title: String, url: String, dateAdded: Date = Date(), isFolder: Bool = false, parentId: UUID? = nil) {
        self.id = id
        self.title = title
        self.url = url
        self.dateAdded = dateAdded
        self.isFolder = isFolder
        self.parentId = parentId
    }
}

public struct HistoryItem: Identifiable, Codable, Equatable {
    public var id: UUID
    public var title: String
    public var url: String
    public var dateVisited: Date
    
    public init(id: UUID = UUID(), title: String, url: String, dateVisited: Date = Date()) {
        self.id = id
        self.title = title
        self.url = url
        self.dateVisited = dateVisited
    }
}

public class SafariDataManager: ObservableObject {
    public static let shared = SafariDataManager()
    
    @Published public var bookmarks: [BookmarkItem] = [] {
        didSet { saveBookmarks() }
    }
    @Published public var history: [HistoryItem] = [] {
        didSet { saveHistory() }
    }
    
    private let bookmarksKey = "OldSafari_Bookmarks_v2"
    private let historyKey = "OldSafari_History_v2"
    
    init() {
        loadBookmarks()
        loadHistory()
        if bookmarks.isEmpty {
            setupDefaultBookmarks()
        }
    }
    
    private func setupDefaultBookmarks() {
        bookmarks = [
            BookmarkItem(title: "Apple", url: "https://www.apple.com"),
            BookmarkItem(title: "Google", url: "https://www.google.com"),
            BookmarkItem(title: "OldOS Project", url: "https://github.com/zzanehip/The-OldOS-Project"),
            BookmarkItem(title: "OldSafari Repo", url: "https://github.com/iamgasgass/OldSafari")
        ]
    }
    
    public func addBookmark(title: String, url: String) {
        let newB = BookmarkItem(title: title.isEmpty ? url : title, url: url)
        bookmarks.append(newB)
    }
    
    public func addHistory(title: String, url: String) {
        guard !url.isEmpty && url != "about:blank" else { return }
        let newH = HistoryItem(title: title.isEmpty ? url : title, url: url)
        if let first = history.first, first.url == url {
            return
        }
        history.insert(newH, at: 0)
        if history.count > 200 {
            history.removeLast()
        }
    }
    
    public func clearHistory() {
        history.removeAll()
    }
    
    private func saveBookmarks() {
        if let encoded = try? JSONEncoder().encode(bookmarks) {
            UserDefaults.standard.set(encoded, forKey: bookmarksKey)
        }
    }
    
    private func loadBookmarks() {
        if let data = UserDefaults.standard.data(forKey: bookmarksKey),
           let decoded = try? JSONDecoder().decode([BookmarkItem].self, from: data) {
            bookmarks = decoded
        }
    }
    
    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(encoded, forKey: historyKey)
        }
    }
    
    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let decoded = try? JSONDecoder().decode([HistoryItem].self, from: data) {
            history = decoded
        }
    }
}
