import Combine
import Foundation

/// Single source of truth for the browsing session: every open tab
/// (regular or private), the selected tab, bookmarks and history.
final class SafariTabStore: ObservableObject {

    @Published var tabs: [SafariTab] = []
    @Published var selectedID: UUID?
    @Published var isPrivateMode: Bool = false

    @Published var bookmarks: [SafariBookmark] = SafariBookmark.load() {
        didSet { SafariBookmark.save(bookmarks) }
    }
    @Published var history: [SafariHistoryEntry] = SafariHistoryEntry.load() {
        didSet { SafariHistoryEntry.save(history) }
    }

    /// Only the tabs belonging to the currently active mode (regular vs.
    /// private), matching how Safari's tab switcher separates the two.
    var visibleTabs: [SafariTab] {
        tabs.filter { $0.isPrivate == isPrivateMode }
    }

    var selected: SafariTab? {
        if let selectedID, let match = tabs.first(where: { $0.id == selectedID }), match.isPrivate == isPrivateMode {
            return match
        }
        return visibleTabs.first
    }

    init() {
        addTab()
    }

    // MARK: - Tab management

    @discardableResult
    func addTab(url: URL? = nil) -> SafariTab {
        let tab = SafariTab(url: url, isPrivate: isPrivateMode)
        tab.onFinishedLoading = { [weak self] finished in
            self?.recordHistoryIfNeeded(for: finished)
        }
        tabs.append(tab)
        selectedID = tab.id
        return tab
    }

    func close(_ tab: SafariTab) {
        let siblings = tabs.filter { $0.isPrivate == tab.isPrivate }
        let wasSelected = tab.id == selectedID

        tabs.removeAll { $0.id == tab.id }

        if siblings.count <= 1 {
            // Always keep at least one tab per mode, like Safari does.
            let replacement = addTab()
            selectedID = replacement.id
            return
        }

        if wasSelected {
            selectedID = visibleTabs.last?.id
        }
    }

    func select(_ tab: SafariTab) {
        selectedID = tab.id
    }

    func togglePrivateMode() {
        isPrivateMode.toggle()
        if visibleTabs.isEmpty {
            addTab()
        } else {
            selectedID = visibleTabs.last?.id
        }
    }

    // MARK: - Bookmarks

    func addBookmark(title: String, url: String) {
        guard !url.isEmpty else { return }
        guard !bookmarks.contains(where: { $0.url == url }) else { return }
        bookmarks.append(SafariBookmark(title: title.isEmpty ? url : title, url: url))
    }

    func removeBookmarks(at offsets: IndexSet) {
        bookmarks.remove(atOffsets: offsets)
    }

    // MARK: - History

    private func recordHistoryIfNeeded(for tab: SafariTab) {
        guard !tab.isPrivate, let url = tab.url else { return }
        let entry = SafariHistoryEntry(
            title: tab.title.isEmpty ? url.absoluteString : tab.title,
            url: url.absoluteString
        )
        history.insert(entry, at: 0)
    }

    func removeHistory(at offsets: IndexSet, in group: [SafariHistoryEntry]) {
        let idsToRemove = Set(offsets.map { group[$0].id })
        history.removeAll { idsToRemove.contains($0.id) }
    }

    func clearHistory() {
        history.removeAll()
    }
}
