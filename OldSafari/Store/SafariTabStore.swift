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
            let replacement = SafariTab(url: nil, isPrivate: tab.isPrivate)
            replacement.onFinishedLoading = { [weak self] finished in
                self?.recordHistoryIfNeeded(for: finished)
            }
            tabs.append(replacement)

            if tab.isPrivate == isPrivateMode {
                selectedID = replacement.id
            }
            return
        }

        if wasSelected {
            let remaining = tabs.filter { $0.isPrivate == tab.isPrivate }
            selectedID = remaining.last?.id
        }
    }

    func select(_ tab: SafariTab) {
        selectedID = tab.id
        if tab.isPrivate != isPrivateMode {
            isPrivateMode = tab.isPrivate
        }
    }

    func togglePrivateMode() {
        isPrivateMode.toggle()

        if visibleTabs.isEmpty {
            addTab()
        } else {
            selectedID = visibleTabs.last?.id
        }
    }

    func addBookmark(title: String, url: String) {
        guard !url.isEmpty else { return }
        guard !bookmarks.contains(where: { $0.url == url }) else { return }

        bookmarks.append(
            SafariBookmark(
                title: title.isEmpty ? url : title,
                url: url
            )
        )
    }

    func removeBookmarks(at offsets: IndexSet) {
        bookmarks.remove(atOffsets: offsets)
    }

    private func recordHistoryIfNeeded(for tab: SafariTab) {
        guard !tab.isPrivate, let url = tab.url else { return }
        guard let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else { return }

        let normalizedURL = url.absoluteString

        // Avoid flooding history on reloads and repeated WebKit isLoading
        // transitions for the same top-level URL.
        if let first = history.first,
           first.url == normalizedURL,
           first.title == (tab.title.isEmpty ? normalizedURL : tab.title) {
            return
        }

        let entry = SafariHistoryEntry(
            title: tab.title.isEmpty ? normalizedURL : tab.title,
            url: normalizedURL
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
