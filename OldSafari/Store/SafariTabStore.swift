import Combine
import Foundation

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

    var visibleTabs: [SafariTab] {
        tabs.filter { $0.isPrivate == isPrivateMode }
    }

    /// Selection is ID based and is always reconciled against the currently
    /// visible tab set. This is the important part of the Pages -> Library ->
    /// ShareSheet fix: overlays never cache a WKWebView or a stale array index.
    var selected: SafariTab? {
        if let selectedID,
           let match = tabs.first(where: { $0.id == selectedID }),
           match.isPrivate == isPrivateMode {
            return match
        }
        return visibleTabs.first
    }

    init() {
        addTab()
    }

    @discardableResult
    func addTab(url: URL? = nil) -> SafariTab {
        if visibleTabs.count >= 8 {
            return selected ?? tabs.first!
        }
        let tab = SafariTab(url: url, isPrivate: isPrivateMode)
        attachCallbacks(to: tab)
        tabs.append(tab)
        selectedID = tab.id
        return tab
    }

    func close(_ tab: SafariTab) {
        let wasSelected = tab.id == selectedID
        let visibleBefore = visibleTabs

        tabs.removeAll { $0.id == tab.id }

        // Safari keeps at least one page in each mode. If the last visible page
        // is closed, create a blank replacement and make it selected immediately.
        if visibleBefore.count <= 1 {
            let replacement = SafariTab(url: nil, isPrivate: tab.isPrivate)
            attachCallbacks(to: replacement)
            tabs.append(replacement)
            if tab.isPrivate == isPrivateMode {
                selectedID = replacement.id
            }
            return
        }

        if wasSelected {
            // Select the page adjacent to the closed one. Prefer the previous
            // page, falling back to the last remaining page.
            let remaining = tabs.filter { $0.isPrivate == tab.isPrivate }
            if let oldIndex = visibleBefore.firstIndex(where: { $0.id == tab.id }) {
                let replacementIndex = max(0, min(oldIndex - 1, remaining.count - 1))
                selectedID = remaining[replacementIndex].id
            } else {
                selectedID = remaining.last?.id
            }
        }
    }

    func select(_ tab: SafariTab) {
        guard tabs.contains(where: { $0.id == tab.id }) else { return }
        selectedID = tab.id
        if tab.isPrivate != isPrivateMode {
            isPrivateMode = tab.isPrivate
        }
    }

    func togglePrivateMode() {
        isPrivateMode.toggle()
        if visibleTabs.isEmpty {
            addTab()
        } else if let current = selected, current.isPrivate == isPrivateMode {
            selectedID = current.id
        } else {
            selectedID = visibleTabs.last?.id
        }
    }

    func addBookmark(title: String, url: String) {
        guard !url.isEmpty, !bookmarks.contains(where: { $0.url == url }) else { return }
        bookmarks.append(SafariBookmark(title: title.isEmpty ? url : title, url: url))
    }

    func removeBookmarks(at offsets: IndexSet) {
        bookmarks.remove(atOffsets: offsets)
    }

    private func attachCallbacks(to tab: SafariTab) {
        tab.onFinishedLoading = { [weak self] finished in
            self?.recordHistoryIfNeeded(for: finished)
        }
    }

    private func recordHistoryIfNeeded(for tab: SafariTab) {
        guard !tab.isPrivate, let url = tab.url else { return }
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return }

        let normalizedURL = url.absoluteString
        let normalizedTitle = tab.title.isEmpty ? normalizedURL : tab.title

        if let first = history.first, first.url == normalizedURL, first.title == normalizedTitle {
            return
        }

        history.insert(SafariHistoryEntry(title: normalizedTitle, url: normalizedURL), at: 0)
    }

    func removeHistory(at offsets: IndexSet, in group: [SafariHistoryEntry]) {
        let idsToRemove = Set(offsets.map { group[$0].id })
        history.removeAll { idsToRemove.contains($0.id) }
    }

    func clearHistory() {
        history.removeAll()
    }
}
