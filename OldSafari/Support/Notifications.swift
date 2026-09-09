import Foundation

extension Notification.Name {
    /// Posted when the selected tab finishes loading, so decorative chrome
    /// (address bar, tab dots, download hint) can settle to their idle state.
    static let oldSafariURLChanged = Notification.Name("com.iamgasgass.OldSafari.URLChanged")

    /// Posted when a new download starts. The Downloads pill on the toolbar
    /// listens for this to briefly pulse.
    static let oldSafariDownloadStarted = Notification.Name("com.iamgasgass.OldSafari.DownloadStarted")

    /// Posted whenever Reader Mode is toggled from anywhere in the app. The
    /// address bar listens for this so its Reader glyph reflects the current
    /// state without polling.
    static let oldSafariReaderChanged = Notification.Name("com.iamgasgass.OldSafari.ReaderChanged")
}
