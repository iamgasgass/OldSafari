import Foundation
import Combine
import WebKit

/// One download tracked by the browser, from `WKDownload` start through
/// completion or failure. Retained (via the store) for the whole session so the
/// Downloads sheet can show progress, offer Cancel / Open / Share, and reveal
/// items in the Files app, mirroring what recent Safari does — with the app's
/// iOS 6 chrome instead of the modern popover.
final class SafariDownload: NSObject, ObservableObject, Identifiable {

    enum State: Equatable {
        case running
        case completed(URL)
        case failed(String)
        case cancelled
    }

    let id = UUID()
    let sourceURL: URL
    let suggestedFilename: String
    let startedAt: Date

    @Published private(set) var state: State = .running
    @Published private(set) var bytesReceived: Int64 = 0
    @Published private(set) var bytesExpected: Int64 = 0

    /// Live WKDownload handle, kept only while the download is running so we
    /// can honour Cancel from the UI.
    fileprivate weak var download: WKDownload?

    /// Where the downloaded file lives once it has finished, under the app's
    /// container (`Documents/Downloads/...`). Persistent across launches.
    private(set) var destinationURL: URL?

    init(sourceURL: URL, suggestedFilename: String) {
        self.sourceURL = sourceURL
        self.suggestedFilename = suggestedFilename
        self.startedAt = Date()
    }

    var progress: Double {
        guard bytesExpected > 0 else { return 0 }
        return min(1, max(0, Double(bytesReceived) / Double(bytesExpected)))
    }

    var isRunning: Bool {
        if case .running = state { return true }
        return false
    }

    var completedURL: URL? {
        if case let .completed(url) = state { return url }
        return nil
    }

    var failureMessage: String? {
        if case let .failed(reason) = state { return reason }
        return nil
    }

    // MARK: Progress bookkeeping (fed by SafariDownloadManager KVO)

    func updateProgress(received: Int64, expected: Int64) {
        DispatchQueue.main.async {
            self.bytesReceived = received
            self.bytesExpected = expected
            self.objectWillChange.send()
        }
    }

    func markCompleted(at url: URL) {
        DispatchQueue.main.async {
            self.destinationURL = url
            self.state = .completed(url)
            self.download = nil
        }
    }

    func markFailed(_ reason: String) {
        DispatchQueue.main.async {
            self.state = .failed(reason)
            self.download = nil
        }
    }

    func markCancelled() {
        DispatchQueue.main.async {
            self.state = .cancelled
            self.download = nil
        }
    }

    func cancel() {
        download?.cancel { _ in }
        markCancelled()
    }

    // MARK: Helpers

    /// Human-readable "1.2 MB of 4.7 MB" style status line.
    var statusText: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file

        switch state {
        case .running:
            if bytesExpected > 0 {
                return "\(formatter.string(fromByteCount: bytesReceived)) of \(formatter.string(fromByteCount: bytesExpected))"
            }
            return bytesReceived > 0
                ? formatter.string(fromByteCount: bytesReceived)
                : "Starting\u{2026}"
        case .completed:
            return formatter.string(fromByteCount: max(bytesReceived, bytesExpected))
        case .cancelled:
            return "Cancelled"
        case .failed(let reason):
            return reason
        }
    }
}

extension SafariDownload {
    /// Convenience for wiring the live WKDownload after `init`.
    func attach(_ download: WKDownload) {
        self.download = download
    }
}
