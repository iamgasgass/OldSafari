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

    /// Where the list of *completed* downloads is persisted across app
    /// launches. Deliberately kept in Application Support rather than
    /// alongside the files themselves in `downloadsDirectory`, so this
    /// bookkeeping file never appears in any user-facing file listing
    /// (Files app document browsing, "Open In", etc.) — only the real
    /// downloaded files live under `Documents/Downloads`.
    private lazy var manifestURL: URL = {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("OldSafariDownloads.json")
    }()

    private override init() {
        super.init()
        loadPersistedDownloads()
    }

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
            persistDownloads()
        }
    }

    func clearFinished() {
        // Delete the actual files from disk first — leaving them behind
        // while only clearing the visible list would silently fill up the
        // app's document container forever.
        let finished = downloads.filter { !$0.isRunning }
        for entry in finished {
            if let url = entry.destinationURL {
                try? FileManager.default.removeItem(at: url)
            }
        }
        downloads.removeAll { !$0.isRunning }
        persistDownloads()
    }

    /// External-write API for callers that already produced a `SafariDownload`
    /// (e.g. Save PDF to Files, blob-URL shim). Keeps `downloads` `private(set)`
    /// so the list can only be mutated through the manager.
    func register(_ entry: SafariDownload) {
        DispatchQueue.main.async {
            self.downloads.insert(entry, at: 0)
            self.didStartDownload.send(entry)
            self.persistDownloads()
        }
    }

    var runningCount: Int {
        downloads.filter { $0.isRunning }.count
    }

    // MARK: Persistence

    /// Lightweight, `Codable` snapshot of one completed download. Stores
    /// only the filename (relative to `downloadsDirectory`), never an
    /// absolute path — the app's container directory can change between
    /// launches (reinstalls, iOS housekeeping, device migrations), so an
    /// absolute `URL` baked into a manifest would silently point nowhere.
    /// Reconstructing `downloadsDirectory.appendingPathComponent(filename)`
    /// at load time is what makes restoration robust across those cases.
    private struct PersistedRecord: Codable {
        let id: UUID
        let sourceURL: URL
        let filename: String
        let startedAt: Date
        let bytesReceived: Int64
    }

    /// Rewrites the on-disk manifest from the current `downloads` array,
    /// keeping ONLY entries that are both `.completed` and whose file still
    /// verifiably exists on disk right now. Running, failed, and cancelled
    /// downloads are never persisted: a `WKDownload` cannot resume across
    /// process death, and failed/cancelled entries left no file behind, so
    /// there is nothing meaningful to restore for them after a relaunch.
    private func persistDownloads() {
        let records: [PersistedRecord] = downloads.compactMap { entry in
            guard
                let destination = entry.completedURL,
                FileManager.default.fileExists(atPath: destination.path)
            else { return nil }
            return PersistedRecord(
                id: entry.id,
                sourceURL: entry.sourceURL,
                filename: destination.lastPathComponent,
                startedAt: entry.startedAt,
                bytesReceived: entry.bytesReceived
            )
        }

        do {
            let data = try JSONEncoder().encode(records)
            try data.write(to: manifestURL, options: .atomic)
        } catch {
            // Best-effort: losing the manifest only means the next launch
            // won't restore history — it never touches the files themselves.
        }
    }

    /// Restores completed downloads from the previous session, but ONLY the
    /// ones whose file is still verifiably present on disk right now — a
    /// download deleted outside the app (Files app, external cleanup, iOS
    /// storage reclamation) is silently dropped from the list rather than
    /// shown as a dead entry, exactly mirroring how modern Safari's
    /// Downloads list only ever shows files it can actually still open.
    /// Any dropped entry also triggers an immediate manifest rewrite, so
    /// the stale record does not keep being checked on every future launch.
    private func loadPersistedDownloads() {
        guard let data = try? Data(contentsOf: manifestURL),
              let records = try? JSONDecoder().decode([PersistedRecord].self, from: data)
        else { return }

        var restored: [SafariDownload] = []
        var didPruneAny = false

        for record in records {
            let path = downloadsDirectory.appendingPathComponent(record.filename)
            guard FileManager.default.fileExists(atPath: path.path) else {
                didPruneAny = true
                continue
            }
            restored.append(
                SafariDownload.restored(
                    sourceURL: record.sourceURL,
                    suggestedFilename: record.filename,
                    startedAt: record.startedAt,
                    destinationURL: path,
                    bytesReceived: record.bytesReceived
                )
            )
        }

        // Newest first, matching how live downloads are inserted
        // (`downloads.insert(entry, at: 0)`), so a relaunch never reshuffles
        // the visible order the user already saw.
        downloads = restored.sorted { $0.startedAt > $1.startedAt }

        if didPruneAny {
            persistDownloads()
        }
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

        let destination = uniqueDestination(for: name)
        entry?.setDestination(destination)
        return destination
    }

    func downloadDidFinish(_ download: WKDownload) {
        if let entry = downloads.first(where: { $0.download === download }) {
            // The destination we handed WebKit becomes the completed URL.
            let progress = download.progress
            entry.updateProgress(
                received: progress.completedUnitCount,
                expected: progress.totalUnitCount
            )
            if let path = entry.destinationURL, FileManager.default.fileExists(atPath: path.path) {
                entry.markCompleted(at: path)
            } else if let path = destinationURL(for: entry) {
                entry.markCompleted(at: path)
            } else {
                entry.markFailed("Downloaded file could not be located")
            }
            // `markCompleted`/`markFailed` schedule their own state mutation
            // on the main queue; chaining this call through the same queue
            // guarantees it runs afterward and therefore persists the
            // finished (or explicitly not-persisted, if failed) state.
            DispatchQueue.main.async { self.persistDownloads() }
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
