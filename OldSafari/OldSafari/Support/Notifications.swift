import Foundation

extension Notification.Name {
    /// Posted when the front-most tab's URL changes so lightweight
    /// observers (haptics, analytics-free logging, etc.) can react
    /// without holding a strong reference to the tab itself.
    static let oldSafariURLChanged = Notification.Name("OldSafariURLChanged")
}
