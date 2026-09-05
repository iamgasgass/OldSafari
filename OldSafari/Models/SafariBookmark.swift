import Foundation

struct SafariBookmark: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var url: String

    init(id: UUID = UUID(), title: String, url: String) {
        self.id = id
        self.title = title
        self.url = url
    }

    private static let key = "OldSafari.Bookmarks"

    static func load() -> [SafariBookmark] {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let value = try? JSONDecoder().decode([SafariBookmark].self, from: data)
        else {
            return SafariBookmark.defaults
        }
        return value
    }

    static func save(_ value: [SafariBookmark]) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    /// A small starter set so the Bookmarks / Start Page aren't empty
    /// on first launch, matching the friendly-defaults feel of stock Safari.
    static let defaults: [SafariBookmark] = [
        SafariBookmark(title: "Google", url: "https://www.google.com"),
        SafariBookmark(title: "Apple", url: "https://www.apple.com"),
        SafariBookmark(title: "Wikipedia", url: "https://www.wikipedia.org")
    ]
}
