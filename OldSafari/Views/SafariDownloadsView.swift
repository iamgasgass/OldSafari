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
        .background(theme.listBackground)
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
}

// MARK: - Row

private struct DownloadRow: View {
    @ObservedObject var download: SafariDownload
    let theme: OldOSSafariTheme
    let onCancel: () -> Void
    let onOpen: () -> Void
    let onShare: () -> Void
    let onDelete: () -> Void

    /// Local mirror of the address bar's `progress` state, fed by
    /// `download.progress` instead of `tab.estimatedProgress`. Kept as its
    /// own `@State` — rather than reading `download.progress` directly in
    /// the view body — for the exact same reason `SafariAddressBar` does
    /// it this way: it gives `withAnimation` a discrete value to animate
    /// *to*, so the fill genuinely glides between updates instead of
    /// snapping on every KVO tick from `WKDownload`.
    @State private var plateProgress: Double = 0

    private var clampedPlateProgress: CGFloat {
        CGFloat(min(max(plateProgress, 0), 1))
    }

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

                        Text(download.statusText)
                            .font(OldOSFont.regular(11))
                            .foregroundColor(theme.listRowDetail)
                            .lineLimit(1)
                    }
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

    /// Maniacally faithful port of `SafariAddressBar`'s loading treatment:
    /// same `theme.fieldFill` base, same `theme.progressGradient` with
    /// `.brightness(0.1)` sliding left to right, same
    /// `RoundedRectangle(cornerRadius: 6)` clip, the identical
    /// `OldOSInnerShadow` (radius 1.8, offset (0, 1), intensity 0.5), and
    /// the identical `theme.fieldStroke` outline at `lineWidth: 0.65`.
    /// Height is 22pt rather than the address field's 32pt because the
    /// download row's fixed layout has no room for a full-height field —
    /// every color, corner radius, stroke weight and shadow parameter
    /// stays byte-for-byte identical to the address bar's own values. The
    /// live percentage readout is the one addition, since a URL has no
    /// numeric "percent" to show but a download explicitly does.
    private var progressStrip: some View {
        ZStack(alignment: .trailing) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle().fill(theme.fieldFill)

                    LinearGradient(oldOS: theme.progressGradient)
                        .brightness(0.1)
                        .frame(width: geometry.size.width * clampedPlateProgress)
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            OldOSInnerShadow(
                shape: RoundedRectangle(cornerRadius: 6),
                fill: Color.clear,
                radius: 1.8,
                offset: CGPoint(x: 0, y: 1),
                intensity: 0.5
            )
            .oldOSStrokeRoundedRectangle(6, theme.fieldStroke, lineWidth: 0.65)

            Text("\(Int((clampedPlateProgress * 100).rounded()))%")
                .font(OldOSFont.bold(10))
                .foregroundColor(theme.fieldTextIdle)
                .shadow(color: Color.black.opacity(0.35), radius: 0, x: 0, y: 1)
                .padding(.trailing, 6)
        }
        .frame(height: 22)
        .padding(.leading, 2.5)
        .padding(.trailing, 1)
        .padding(.top, 2)
        .onAppear {
            // Catch up instantly if the row appears mid-download, exactly
            // like the address bar's own `showsPlate` catch-up on
            // `tab.$isLoading`.
            plateProgress = max(download.progress, 0.06)
        }
        .onChange(of: download.progress) { value in
            // Identical easing to SafariAddressBar's own progress updates:
            // `.linear(duration: 0.2)` on every advance, never a hard snap.
            withAnimation(.linear(duration: 0.2)) { plateProgress = value }
        }
    }

    @ViewBuilder
    private var trailingButtons: some View {
        switch download.state {
        case .running:
            OldOSDownloadIconButton(kind: .cancel, action: onCancel)
        case .completed:
            HStack(spacing: 8) {
                OldOSDownloadIconButton(kind: .folder, action: onOpen)
                OldOSDownloadIconButton(kind: .share, action: onShare)
                OldOSDownloadIconButton(kind: .trash, action: onDelete)
            }
        case .failed, .cancelled:
            OldOSDownloadIconButton(kind: .trash, action: onDelete)
        }
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

/// MANIACAL FIX — "quello dimenticato": every other button in this app
/// (`OldOSRectangleButton` — Done, Clear, Cancel, the action-sheet
/// buttons…) is a glossy, beveled rounded-rect painted with
/// `oldOSButtonGradient(_:)` and `oldOSInnerShadowBackground(...)`. The
/// previous revision of these three download-row icons skipped that chrome
/// entirely and drew a bare, backgroundless line-art glyph — which is why
/// the "before" screenshot shows flat black/red outlines with no button
/// plate behind them at all, instead of the solid blue/red glossy squares
/// every other actionable control in the app already has. This reuses the
/// EXACT same primitives, same corner radius family, same shadow
/// parameters, same button-press feedback — folder and share use `.blue`
/// (identical to the "Done" button and `primaryButton`), trash and cancel
/// use `.red` (identical to every other destructive control in the app,
/// e.g. `shareCancelInner`). The glyph itself is unchanged (still the
/// hand-drawn Canvas path at the correct 24×24 design size), just now
/// rendered in white on top of its own colored plate instead of floating
/// on the bare row background.
private struct OldOSDownloadIconButton: View {
    enum Kind { case folder, share, trash, cancel }

    let kind: Kind
    let action: () -> Void

    private var buttonType: OldOSButtonType {
        switch kind {
        case .trash, .cancel: return .red
        case .folder, .share: return .blue
        }
    }

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            OldOSDownloadGlyph(kind: kind, color: .white)
                .frame(width: 18, height: 18)
                .shadow(color: Color.black.opacity(0.35), radius: 0, x: 0, y: -1)
        }
        .frame(width: 32, height: 32)
        .oldOSInnerShadowBackground(
            RoundedRectangle(cornerRadius: 6),
            oldOSButtonGradient(buttonType),
            radius: 0.8,
            offset: CGPoint(x: 0, y: 0.6),
            intensity: 0.7
        )
        .shadow(color: Color.white.opacity(0.28), radius: 0, x: 0, y: 0.8)
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

private struct OldOSDownloadGlyph: View {
    let kind: OldOSDownloadIconButton.Kind
    let color: Color

    var body: some View {
        Canvas { context, size in
            let stroke = color
            var path = Path()
            let w = size.width
            let h = size.height

            switch kind {
            case .folder:
                path.move(to: CGPoint(x: 2, y: 7))
                path.addLine(to: CGPoint(x: 9, y: 7))
                path.addLine(to: CGPoint(x: 11, y: 9))
                path.addLine(to: CGPoint(x: w - 2, y: 9))
                path.addLine(to: CGPoint(x: w - 2, y: h - 4))
                path.addLine(to: CGPoint(x: 2, y: h - 4))
                path.closeSubpath()
                context.stroke(
                    path,
                    with: .color(stroke),
                    style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
                )

            case .share:
                path.move(to: CGPoint(x: 12, y: h - 3))
                path.addLine(to: CGPoint(x: 12, y: 8))
                path.move(to: CGPoint(x: 8, y: 12))
                path.addLine(to: CGPoint(x: 12, y: 8))
                path.addLine(to: CGPoint(x: 16, y: 12))
                path.move(to: CGPoint(x: 5, y: 12))
                path.addLine(to: CGPoint(x: 5, y: h - 3))
                path.addLine(to: CGPoint(x: 19, y: h - 3))
                path.addLine(to: CGPoint(x: 19, y: 12))
                context.stroke(
                    path,
                    with: .color(stroke),
                    style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
                )

            case .trash:
                path.addRoundedRect(
                    in: CGRect(x: 5, y: 6, width: 14, height: 15),
                    cornerSize: CGSize(width: 1.5, height: 1.5)
                )
                path.move(to: CGPoint(x: 3, y: 6))
                path.addLine(to: CGPoint(x: 21, y: 6))
                path.move(to: CGPoint(x: 9, y: 3))
                path.addLine(to: CGPoint(x: 15, y: 3))
                path.addLine(to: CGPoint(x: 16, y: 6))
                context.stroke(
                    path,
                    with: .color(stroke),
                    style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
                )

            case .cancel:
                path.move(to: CGPoint(x: 6, y: 6))
                path.addLine(to: CGPoint(x: 18, y: 18))
                path.move(to: CGPoint(x: 18, y: 6))
                path.addLine(to: CGPoint(x: 6, y: 18))
                context.stroke(
                    path,
                    with: .color(stroke),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
            }
        }
    }
}
