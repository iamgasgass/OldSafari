import Foundation

struct SafariHistoryEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let url: String
    let visitedAt: Date

    init(id: UUID = UUID(), title: String, url: String, visitedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.url = url
        self.visitedAt = visitedAt
    }

    private static let key = "OldSafari.History"
    private static let maxEntries = 500

    static func load() -> [SafariHistoryEntry] {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let value = try? JSONDecoder().decode([SafariHistoryEntry].self, from: data)
        else {
            return []
        }
        return value
    }

    static func save(_ value: [SafariHistoryEntry]) {
        let trimmed = Array(value.prefix(maxEntries))
        guard let data = try? JSONEncoder().encode(trimmed) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    /// Groups entries by calendar day, newest day first, matching the
    /// classic Safari History list layout ("Today", "Yesterday", ...).
    static func grouped(_ entries: [SafariHistoryEntry]) -> [(label: String, entries: [SafariHistoryEntry])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry.visitedAt)
        }
        let sortedKeys = grouped.keys.sorted(by: >)
        let formatter = DateFormatter()
        formatter.dateStyle = .full

        return sortedKeys.map { day in
            let label: String
            if calendar.isDateInToday(day) {
                label = "Today"
            } else if calendar.isDateInYesterday(day) {
                label = "Yesterday"
            } else {
                label = formatter.string(from: day)
            }
            let dayEntries = (grouped[day] ?? []).sorted { $0.visitedAt > $1.visitedAt }
            return (label, dayEntries)
        }
    }
}
