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

    /// Local mirror of `SafariAddressBar`'s own `progress` state, fed here
    /// by `download.progress` instead of `tab.estimatedProgress`. Kept as
    /// its own `@State` — rather than reading `download.progress` directly
    /// in the view body — for the exact same reason the address bar does
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

    /// MANIACALLY faithful port of `SafariAddressBar`'s own loading
    /// treatment — reused verbatim, value for value:
    /// - Same base fill: `theme.fieldFill`.
    /// - Same progress fill: `theme.progressGradient` with `.brightness(0.1)`,
    ///   sliding left to right as the value advances.
    /// - Same clip shape: `RoundedRectangle(cornerRadius: 6)`.
    /// - Same inner shadow: `OldOSInnerShadow(radius: 1.8, offset: (0, 1),
    ///   intensity: 0.5)`.
    /// - Same outline: `theme.fieldStroke` at `lineWidth: 0.65`.
    /// - Same easing: `.linear(duration: 0.2)` on every advance.
    ///
    /// The only intentional addition is the live percentage readout inside
    /// the bar — the address bar has no use for one (a URL has no numeric
    /// "percent"), but it was explicitly requested for downloads. Height is
    /// 22pt rather than the address field's 32pt because the row's fixed
    /// layout has no room for a full-height field without inflating every
    /// row in the list; every other parameter (color, radius, stroke
    /// weight, shadow) stays byte-for-byte identical to the address bar.
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

            // Live percentage, updated in lockstep with the plate itself —
            // "mostrare la percentuale progressiva del download all'interno
            // della barra", exactly as requested.
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
            // Catch up instantly if the row appears mid-download (e.g. the
            // Downloads panel is opened after a download already started),
            // exactly like the address bar's own `showsPlate` catch-up on
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
            OldOSDownloadIconButton(kind: .cancel, theme: theme, action: onCancel)
        case .completed:
            HStack(spacing: 7) {
                OldOSDownloadIconButton(kind: .folder, theme: theme, action: onOpen)
                OldOSDownloadIconButton(kind: .share, theme: theme, action: onShare)
                OldOSDownloadIconButton(kind: .trash, theme: theme, action: onDelete)
            }
        case .failed, .cancelled:
            OldOSDownloadIconButton(kind: .trash, theme: theme, action: onDelete)
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

/// Icon button matching OldOSRectangleButton's chrome (glossy gradient,
/// recessed bevel, dark hairline border) so the 3 actions look identical to
/// every other iOS 6 button in the app.
///
/// UNCHANGED from the corrected baseline: this is the glossy button-chrome
/// version (`oldOSInnerShadowBackground`, `oldOSButtonGradient`) — the one
/// that renders correctly. A previous edit had regressed this back to an
/// older, flat, chrome-less variant while grafting in the download progress
/// bar, which is what corrupted the glyphs' appearance. This pass restores
/// exactly this implementation and touches nothing else about it.
private struct OldOSDownloadIconButton: View {
    enum Kind { case folder, share, trash, cancel }

    let kind: Kind
    let theme: OldOSSafariTheme
    let action: () -> Void

    private var buttonType: OldOSButtonType {
        kind == .trash || kind == .cancel ? .red : theme.secondaryButton
    }

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            OldOSDownloadGlyph(kind: kind, color: .white)
                .frame(width: 24, height: 24)
                .frame(width: 32, height: 32)
                .oldOSInnerShadowBackground(
                    RoundedRectangle(cornerRadius: 5.5),
                    oldOSButtonGradient(buttonType),
                    radius: 0.8,
                    offset: CGPoint(x: 0, y: 0.6),
                    intensity: 0.7
                )
                .oldOSStrokeRoundedRectangle(5.5, Color.black.opacity(0.35), lineWidth: 0.5)
                .shadow(color: Color.white.opacity(0.28), radius: 0, x: 0, y: 0.8)
                .contentShape(RoundedRectangle(cornerRadius: 5.5))
        }
        .buttonStyle(.plain)
    }
}

/// Glifi ridisegnati "maniacalmente" fedeli allo stile iOS 6: tratti pieni
/// e spessi (non sottili come SF Symbols), forme geometriche semplici e
/// simmetriche entro un riquadro 24x24 con margine costante di 3pt su ogni
/// lato (area utile 18x18), esattamente come i glifi UIToolbar dell'epoca.
///
/// UNCHANGED from the corrected baseline — identical geometry, untouched.
private struct OldOSDownloadGlyph: View {
    let kind: OldOSDownloadIconButton.Kind
    let color: Color

    var body: some View {
        Canvas { context, size in
            let stroke = color
            var path = Path()
            // Riquadro utile centrato 18x18 dentro una canvas 24x24.
            let m: CGFloat = 3
            let w = size.width - m
            let h = size.height - m

            switch kind {
            case .folder:
                // Cartella classica: corpo + linguetta superiore, forma
                // simmetrica rispetto al centro orizzontale.
                path.move(to: CGPoint(x: m, y: m + 3))
                path.addLine(to: CGPoint(x: m + 6, y: m + 3))
                path.addLine(to: CGPoint(x: m + 8, y: m + 5.5))
                path.addLine(to: CGPoint(x: w, y: m + 5.5))
                path.addLine(to: CGPoint(x: w, y: h))
                path.addLine(to: CGPoint(x: m, y: h))
                path.closeSubpath()
                context.stroke(
                    path,
                    with: .color(stroke),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )

            case .share:
                // L'iconica "action" glyph di iOS 6: un riquadro aperto in
                // alto con una freccia che ne esce verso l'alto — il glifo
                // di condivisione/azione più riconoscibile dell'epoca.
                let midX = (m + w) / 2
                let boxTop = m + 9
                path.move(to: CGPoint(x: m, y: boxTop))
                path.addLine(to: CGPoint(x: m, y: h))
                path.addLine(to: CGPoint(x: w, y: h))
                path.addLine(to: CGPoint(x: w, y: boxTop))
                context.stroke(
                    path,
                    with: .color(stroke),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )

                var arrow = Path()
                arrow.move(to: CGPoint(x: midX, y: h - 5))
                arrow.addLine(to: CGPoint(x: midX, y: m))
                arrow.move(to: CGPoint(x: midX - 4, y: m + 4))
                arrow.addLine(to: CGPoint(x: midX, y: m))
                arrow.addLine(to: CGPoint(x: midX + 4, y: m + 4))
                context.stroke(
                    arrow,
                    with: .color(stroke),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )

            case .trash:
                // Cestino classico: coperchio + maniglia + corpo con 3
                // linee verticali interne, come l'icona iOS 6 originale.
                let bodyTop = m + 5
                path.addRoundedRect(
                    in: CGRect(x: m + 1, y: bodyTop, width: w - m - 2, height: h - bodyTop),
                    cornerSize: CGSize(width: 1.5, height: 1.5)
                )
                path.move(to: CGPoint(x: m - 0.5, y: bodyTop))
                path.addLine(to: CGPoint(x: w + 0.5, y: bodyTop))
                path.move(to: CGPoint(x: m + 6, y: bodyTop))
                path.addLine(to: CGPoint(x: m + 7, y: m + 1))
                path.addLine(to: CGPoint(x: w - 7, y: m + 1))
                path.addLine(to: CGPoint(x: w - 6, y: bodyTop))
                context.stroke(
                    path,
                    with: .color(stroke),
                    style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
                )

                var lines = Path()
                let innerTop = bodyTop + 3
                let innerBottom = h - 3
                for i in 0..<3 {
                    let x = m + 4 + CGFloat(i) * ((w - m - 8) / 2)
                    lines.move(to: CGPoint(x: x, y: innerTop))
                    lines.addLine(to: CGPoint(x: x, y: innerBottom))
                }
                context.stroke(
                    lines,
                    with: .color(stroke),
                    style: StrokeStyle(lineWidth: 1.2, lineCap: .round)
                )

            case .cancel:
                path.move(to: CGPoint(x: m + 1, y: m + 1))
                path.addLine(to: CGPoint(x: w - 1, y: h - 1))
                path.move(to: CGPoint(x: w - 1, y: m + 1))
                path.addLine(to: CGPoint(x: m + 1, y: h - 1))
                context.stroke(
                    path,
                    with: .color(stroke),
                    style: StrokeStyle(lineWidth: 2.2, lineCap: .round)
                )
            }
        }
    }
}
