import SwiftUI
import UIKit

/// iOS 6-style sheet listing every download tracked by SafariDownloadManager.
/// Rows show progress while running, offer Cancel, and once finished expose
/// Open, Share and Delete — mirroring the affordances the modern Safari
/// popover ships today, but painted with the app's brushed-aluminium chrome.
struct SafariDownloadsView: View {
    @ObservedObject var manager: SafariDownloadManager
    let theme: OldOSSafariTheme
    let topInset: CGFloat
    let bottomInset: CGFloat
    let onClose: () -> Void

    @State private var confirmClearAll = false
    @State private var pendingShareURL: URL?

    var body: some View {
        ZStack {
            theme.listBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                LinearGradient(oldOS: theme.barGradient).frame(height: topInset)

                OldOSTitleBar(
                    title: "Downloads",
                    theme: theme,
                    leading: manager.downloads.isEmpty
                        ? nil
                        : OldOSBarButton("Clear", type: theme.secondaryButton) {
                            withAnimation(.linear(duration: 0.2)) { confirmClearAll = true }
                        },
                    trailing: OldOSBarButton("Done", type: .blue, action: onClose)
                )

                if manager.downloads.isEmpty {
                    empty
                } else {
                    list
                }

                Spacer(minLength: 0)
            }

            if confirmClearAll {
                OldOSActionSheet(
                    theme: theme,
                    buttons: [
                        OldOSSheetButton(title: "Clear Finished", destructive: true) {
                            withAnimation(.linear(duration: 0.2)) {
                                manager.clearFinished()
                                confirmClearAll = false
                            }
                        }
                    ],
                    heightFraction: 0.3,
                    bottomInset: bottomInset,
                    onCancel: { withAnimation(.linear(duration: 0.2)) { confirmClearAll = false } }
                )
                .transition(.move(edge: .bottom))
                .zIndex(5)
            }
        }
        .ignoresSafeArea()
        .sheet(item: Binding(
            get: { pendingShareURL.map(ShareURL.init) },
            set: { pendingShareURL = $0?.url }
        )) { wrapper in
            SystemShare(items: [wrapper.url])
        }
    }

    private var empty: some View {
        VStack(spacing: 6) {
            Text("No Downloads")
                .font(OldOSFont.bold(18))
                .foregroundColor(theme.listRowText)
            Text("Files you download from web pages appear here.")
                .font(OldOSFont.regular(14))
                .foregroundColor(theme.listRowDetail)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var list: some View {
        OldOSPlainList {
            ForEach(manager.downloads) { download in
                DownloadRow(
                    download: download,
                    theme: theme,
                    onCancel: { download.cancel() },
                    onOpen: { openInFiles(download) },
                    onShare: {
                        if let url = download.completedURL { pendingShareURL = url }
                    },
                    onDelete: {
                        withAnimation(.linear(duration: 0.2)) {
                            manager.removeDownload(id: download.id)
                        }
                    }
                )
            }
        }
        .background(
            ZStack {
                theme.listBackground
                OldOSTableFiller(theme: theme)
            }
        )
    }

    /// Reveal the file in the Files app by opening a `shareddocuments://`
    /// URL that targets the app's Downloads folder. If Files cannot handle
    /// the request the share sheet is offered as a fallback.
    private func openInFiles(_ download: SafariDownload) {
        guard let url = download.completedURL else { return }
        let path = url.path.replacingOccurrences(of: "/private", with: "")
        if let shared = URL(string: "shareddocuments://\(path)") {
            UIApplication.shared.open(shared, options: [:]) { success in
                if !success { self.pendingShareURL = url }
            }
        } else {
            pendingShareURL = url
        }
    }
}

private struct ShareURL: Identifiable {
    let url: URL
    var id: URL { url }
}

private struct SystemShare: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let c = UIActivityViewController(activityItems: items, applicationActivities: nil)
        // Follow the device Light/Dark Mode, same as everywhere else.
        c.overrideUserInterfaceStyle = .unspecified
        return c
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Row

private struct DownloadRow: View {
    @ObservedObject var download: SafariDownload
    let theme: OldOSSafariTheme
    let onCancel: () -> Void
    let onOpen: () -> Void
    let onShare: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                iconTile

                VStack(alignment: .leading, spacing: 3) {
                    Text(download.suggestedFilename)
                        .font(OldOSFont.bold(15))
                        .foregroundColor(theme.listRowText)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Text(download.sourceURL.host ?? download.sourceURL.absoluteString)
                        .font(OldOSFont.regular(11))
                        .foregroundColor(theme.listRowDetail)
                        .lineLimit(1)

                    if download.isRunning {
                        progressStrip
                    }

                    Text(download.statusText)
                        .font(OldOSFont.regular(11))
                        .foregroundColor(theme.listRowDetail)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                trailingButtons
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Rectangle()
                .fill(theme.listSeparator)
                .frame(height: 0.95)
        }
    }

    private var iconTile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(LinearGradient(oldOS: theme.barGradient))
                .frame(width: 38, height: 44)
                .oldOSStrokeRoundedRectangle(6, theme.barHairline, lineWidth: 0.5)

            Image(systemName: symbol(for: download.suggestedFilename))
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.35), radius: 0, x: 0, y: -1)
        }
    }

    private var progressStrip: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(theme.listSeparator.opacity(0.6))
                Capsule()
                    .fill(LinearGradient(oldOS: theme.progressGradient))
                    .frame(width: geometry.size.width * CGFloat(download.progress))
                    .animation(.linear(duration: 0.2), value: download.progress)
            }
        }
        .frame(height: 4)
        .padding(.top, 3)
        .padding(.trailing, 4)
    }

    @ViewBuilder
    private var trailingButtons: some View {
        switch download.state {
        case .running:
            iconButton(system: "xmark", tint: .oldOS(189, 20, 33), action: onCancel)
        case .completed:
            HStack(spacing: 8) {
                iconButton(system: "folder", tint: theme.listRowText, action: onOpen)
                iconButton(system: "square.and.arrow.up", tint: theme.listRowText, action: onShare)
                iconButton(system: "trash", tint: .oldOS(189, 20, 33), action: onDelete)
            }
        case .failed, .cancelled:
            iconButton(system: "trash", tint: .oldOS(189, 20, 33), action: onDelete)
        }
    }

    private func iconButton(system: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            Image(systemName: system)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 30, height: 30)
                .background(
                    Circle().fill(theme.cardFill.opacity(0.001))
                )
        }
        .buttonStyle(.plain)
    }

    private func symbol(for name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf": return "doc.richtext"
        case "zip", "gz", "tar", "7z", "rar": return "archivebox"
        case "png", "jpg", "jpeg", "gif", "heic", "webp": return "photo"
        case "mp4", "mov", "m4v", "webm": return "film"
        case "mp3", "m4a", "wav", "aac", "flac": return "music.note"
        case "doc", "docx", "pages": return "doc.text"
        case "xls", "xlsx", "numbers": return "tablecells"
        case "ppt", "pptx", "key": return "chart.bar.doc.horizontal"
        case "ipa", "app": return "app.badge"
        default: return "arrow.down.doc"
        }
    }
}
