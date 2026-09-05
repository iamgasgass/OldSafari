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
        guard let selectedID else { return visibleTabs.first }
        return tabs.first(where: { $0.id == selectedID && $0.isPrivate == isPrivateMode }) ?? visibleTabs.first
    }

    func tab(for id: UUID?) -> SafariTab? {
        guard let id else { return nil }
        return tabs.first(where: { $0.id == id })
    }

    func select(id: UUID) {
        guard let tab = tabs.first(where: { $0.id == id }) else { return }
        select(tab)
    }

    /// Modern Safari comes back with the pages you left open; iOS 6 did the
    /// same within a session.  Only non private pages are ever written out.
    private static let sessionKey = "oldsafari.session.urls"

    init() {
        let saved = (UserDefaults.standard.array(forKey: Self.sessionKey) as? [String]) ?? []
        let restored = saved.prefix(8).compactMap { URL(string: $0) }

        if restored.isEmpty {
            addTab()
        } else {
            for url in restored { addTab(url: url, deferLoad: true) }
            selectedID = tabs.first?.id
        }
    }

    private func persistSession() {
        let urls = tabs
            .filter { !$0.isPrivate }
            .compactMap { $0.url?.absoluteString }
        UserDefaults.standard.set(Array(urls.prefix(8)), forKey: Self.sessionKey)
    }

    /// Pages button long press: wipe every page of the current mode and start
    /// over with a single blank one, the way "Close All Tabs" does today.
    func closeAll() {
        let doomed = Set(visibleTabs.map { $0.id })
        tabs.removeAll { doomed.contains($0.id) }
        selectedID = nil
        addTab()
        persistSession()
    }

    @discardableResult
    func addTab(url: URL? = nil, deferLoad: Bool = false) -> SafariTab {
        if visibleTabs.count >= 8 {
            return selected ?? tabs.first!
        }
        let tab = SafariTab(url: url, isPrivate: isPrivateMode, deferLoad: deferLoad)
        attachCallbacks(to: tab)
        tabs.append(tab)
        selectedID = tab.id
        return tab
    }

    func close(_ tab: SafariTab) {
        defer { persistSession() }
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

    func renameBookmark(id: UUID, title: String) {
        guard let index = bookmarks.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        // Keep the identity so the row does not jump while it is being edited.
        bookmarks[index].title = trimmed.isEmpty ? bookmarks[index].url : trimmed
    }

    func removeBookmark(id: UUID) {
        bookmarks.removeAll { $0.id == id }
    }

    private func attachCallbacks(to tab: SafariTab) {
        tab.onFinishedLoading = { [weak self] finished in
            self?.recordHistoryIfNeeded(for: finished)
            self?.persistSession()
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

        // Keep the persisted list bounded: iOS 6 pruned History too, and this
        // keeps the UserDefaults payload and the list rendering cheap.
        if history.count > 400 {
            history.removeLast(history.count - 400)
        }
    }

    func removeHistory(at offsets: IndexSet, in group: [SafariHistoryEntry]) {
        let idsToRemove = Set(offsets.map { group[$0].id })
        history.removeAll { idsToRemove.contains($0.id) }
    }

    func removeHistory(id: UUID) {
        history.removeAll { $0.id == id }
    }

    func clearHistory() {
        history.removeAll()
    }
}
