import Foundation
import Combine
import UIKit
import WebKit

/// Central owner of every browser download. WKWebView asks this object what to
/// do when a navigation resolves to a downloadable response, and it in turn
/// creates a `SafariDownload`, wires progress reporting and posts the file
/// under the app container so the Downloads sheet can reveal / share it later.
final class SafariDownloadManager: NSObject, ObservableObject {

    static let shared = SafariDownloadManager()

    @Published private(set) var downloads: [SafariDownload] = []

    /// Presented by SafariRootView when the user opts to review the queue.
    @Published var showDownloadsPanel: Bool = false

    /// Broadcast whenever a new download starts, so the toolbar chrome can
    /// pulse to hint that Downloads has new content.
    let didStartDownload = PassthroughSubject<SafariDownload, Never>()

    private var kvoTokens: [ObjectIdentifier: [NSKeyValueObservation]] = [:]

    private lazy var downloadsDirectory: URL = {
        let base = (try? FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? URL(fileURLWithPath: NSTemporaryDirectory())

        let folder = base.appendingPathComponent("Downloads", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: folder,
            withIntermediateDirectories: true
        )
        return folder
    }()

    // MARK: Public

    /// Called by SafariTab when the navigation policy says the response is a
    /// file the browser cannot render inline (Content-Disposition attachment,
    /// application/octet-stream, unsupported MIME, etc.).
    @discardableResult
    func startDownload(
        source: URL,
        suggestedFilename: String?,
        using download: WKDownload
    ) -> SafariDownload {
        let name = (suggestedFilename?.isEmpty == false ? suggestedFilename! : source.lastPathComponent)
        let entry = SafariDownload(sourceURL: source, suggestedFilename: name)
        entry.attach(download)

        DispatchQueue.main.async {
            self.downloads.insert(entry, at: 0)
            self.didStartDownload.send(entry)
        }
        download.delegate = self
        observeProgress(of: download, for: entry)

        return entry
    }

    func removeDownload(id: UUID) {
        if let index = downloads.firstIndex(where: { $0.id == id }) {
            let entry = downloads[index]
            entry.cancel()
            if let url = entry.destinationURL {
                try? FileManager.default.removeItem(at: url)
            }
            downloads.remove(at: index)
        }
    }

    func clearFinished() {
        downloads.removeAll { !$0.isRunning }
    }

    /// External-write API for callers that already produced a `SafariDownload`
    /// (e.g. Save PDF to Files, blob-URL shim). Keeps `downloads` `private(set)`
    /// so the list can only be mutated through the manager.
    func register(_ entry: SafariDownload) {
        DispatchQueue.main.async {
            self.downloads.insert(entry, at: 0)
            self.didStartDownload.send(entry)
        }
    }

    var runningCount: Int {
        downloads.filter { $0.isRunning }.count
    }

    // MARK: KVO

    private func observeProgress(of download: WKDownload, for entry: SafariDownload) {
        // WKDownload exposes a Foundation `Progress` via its `progress`
        // property. KVO on `completedUnitCount` / `totalUnitCount` gives us
        // the two numbers the UI wants without polling.
        let progress = download.progress
        let received = progress.observe(\.completedUnitCount, options: [.initial, .new]) { [weak entry] progress, _ in
            entry?.updateProgress(
                received: progress.completedUnitCount,
                expected: max(progress.totalUnitCount, 0)
            )
        }
        let expected = progress.observe(\.totalUnitCount, options: [.initial, .new]) { [weak entry] progress, _ in
            entry?.updateProgress(
                received: progress.completedUnitCount,
                expected: max(progress.totalUnitCount, 0)
            )
        }
        kvoTokens[ObjectIdentifier(download)] = [received, expected]
    }

    private func stopObserving(_ download: WKDownload) {
        kvoTokens[ObjectIdentifier(download)] = nil
    }

    // MARK: Filesystem

    /// Pick a non-colliding path under `Downloads/`, respecting the suggested
    /// filename WebKit gave us.
    private func uniqueDestination(for suggested: String) -> URL {
        let sanitized = suggested
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")

        let stem = (sanitized as NSString).deletingPathExtension
        let ext = (sanitized as NSString).pathExtension

        var candidate = downloadsDirectory.appendingPathComponent(sanitized)
        var counter = 1
        while FileManager.default.fileExists(atPath: candidate.path) {
            counter += 1
            let composed = ext.isEmpty
                ? "\(stem) (\(counter))"
                : "\(stem) (\(counter)).\(ext)"
            candidate = downloadsDirectory.appendingPathComponent(composed)
        }
        return candidate
    }
}

// MARK: - WKDownloadDelegate

extension SafariDownloadManager: WKDownloadDelegate {

    func download(
        _ download: WKDownload,
        decideDestinationUsing response: URLResponse,
        suggestedFilename: String
    ) async -> URL? {
        // Match the entry we created when the download started. It may not
        // have been posted to the main queue yet, so fall back to WKDownload
        // identity.
        let entry = await MainActor.run {
            self.downloads.first(where: { $0.download === download })
        }

        let name = entry?.suggestedFilename.isEmpty == false
            ? entry!.suggestedFilename
            : suggestedFilename

        return uniqueDestination(for: name)
    }

    func downloadDidFinish(_ download: WKDownload) {
        if let entry = downloads.first(where: { $0.download === download }) {
            // The destination we handed WebKit becomes the completed URL.
            let progress = download.progress
            entry.updateProgress(
                received: progress.completedUnitCount,
                expected: progress.totalUnitCount
            )
            if let path = destinationURL(for: entry) {
                entry.markCompleted(at: path)
            } else {
                entry.markCompleted(at: downloadsDirectory)
            }
        }
        stopObserving(download)
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        if let entry = downloads.first(where: { $0.download === download }) {
            let ns = error as NSError
            let text: String
            if ns.code == NSUserCancelledError {
                entry.markCancelled()
                stopObserving(download)
                return
            }
            text = ns.localizedDescription.isEmpty ? "Download failed" : ns.localizedDescription
            entry.markFailed(text)
        }
        stopObserving(download)
    }

    private func destinationURL(for entry: SafariDownload) -> URL? {
        // Walk the Downloads directory looking for the file we just wrote.
        // Cheap because the folder is small and only inspected once per
        // finished download.
        let items = (try? FileManager.default.contentsOfDirectory(
            at: downloadsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        )) ?? []

        let target = items.first(where: { $0.lastPathComponent == entry.suggestedFilename })
        if let target { return target }

        // Fall back to the newest file in the folder.
        return items.sorted { lhs, rhs in
            let l = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let r = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return l > r
        }.first
    }
}
