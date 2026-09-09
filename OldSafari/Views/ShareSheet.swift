import SwiftUI
import SafariServices
import UIKit
import UniformTypeIdentifiers
import WebKit

// MARK: - iOS 6 action sheet

/// A single row of an OldOS/iOS 6 action sheet.
struct OldOSSheetButton: Identifiable {
    let id = UUID()
    let title: String
    var destructive: Bool = false
    let action: () -> Void
}

/// OldOS `share_view`: a 30pt brushed strip, a translucent charcoal body and
/// double-bevelled 50pt buttons.  Reused for every action sheet in the app so
/// Clear History and Share look like they came from the same 2012 binary.
struct OldOSActionSheet: View {
    let theme: OldOSSafariTheme
    let buttons: [OldOSSheetButton]
    var cancelTitle: String = "Cancel"
    /// Optional minimum height, kept for the sheets that were tuned by hand.
    var heightFraction: CGFloat = 0
    var bottomInset: CGFloat = 0
    let onCancel: () -> Void

    /// 30pt strip + 28pt top padding + 50pt rows + cancel button + insets.
    private func sheetHeight(for available: CGFloat) -> CGFloat {
        let rows = CGFloat(buttons.count)
        let content = 30 + 18 + rows * 55 + 50 + 25 + bottomInset
        let minimum = available * heightFraction
        return min(max(content, minimum), available * 0.94)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                theme.scrim.opacity(0.45)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { onCancel() }

                ZStack {
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(LinearGradient(oldOS: theme.shareStrip))
                            .oldOSInnerShadowBottom(color: Color.white.opacity(0.98), radius: 0.1)
                            .oldOSBorder(width: 1, edges: [.top], color: .black)
                            .frame(height: 30)

                        Rectangle().fill(LinearGradient(oldOS: theme.shareBody))
                    }

                    // Buttons scroll when there are too many for the sheet
                    // height, so extending the action list never clips rows
                    // off the top of the sheet.
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            ForEach(Array(buttons.enumerated()), id: \.element.id) { index, button in
                                sheetButton(
                                    title: button.title,
                                    destructive: button.destructive,
                                    action: button.action
                                )
                                .padding(.top, index == 0 ? 18 : 2.5)
                                .padding(.bottom, 2.5)
                            }
                        }
                    }
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        cancelButton
                            .padding(.bottom, 25 + bottomInset)
                            .background(LinearGradient(oldOS: theme.shareBody))
                    }
                }
                .frame(height: sheetHeight(for: geometry.size.height))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
    }

    private func sheetButton(title: String, destructive: Bool, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(LinearGradient(oldOS: theme.shareButtonOuterStroke), lineWidth: 0.5)
                    )
                    .oldOSInnerShadowBackground(
                        RoundedRectangle(cornerRadius: 12),
                        LinearGradient(oldOS: [theme.shareButtonBase, theme.shareButtonBase]),
                        radius: 5.0 / 3.0,
                        offset: CGPoint(x: 0, y: 1.0 / 3.0),
                        intensity: 1
                    )

                RoundedRectangle(cornerRadius: 9)
                    .fill(LinearGradient(oldOS: theme.shareButtonInner))
                    .oldOSAddBorder(LinearGradient(oldOS: theme.shareButtonBorder), width: 0.4, cornerRadius: 9)
                    .padding(3)

                Text(title)
                    .font(OldOSFont.bold(18))
                    .foregroundColor(destructive ? .oldOS(189, 20, 33) : theme.shareButtonText)
                    .shadow(color: theme.shareButtonTextShadow, radius: 0, x: 0, y: theme.shareButtonTextShadowY)
                    .lineLimit(1)
            }
            .padding([.leading, .trailing], 25)
            .frame(minHeight: 50, maxHeight: 50)
        }
        .buttonStyle(.plain)
    }

    private var cancelButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onCancel()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(LinearGradient(oldOS: theme.shareButtonOuterStroke), lineWidth: 0.5)
                    )
                    .oldOSInnerShadowBackground(
                        RoundedRectangle(cornerRadius: 12),
                        LinearGradient(oldOS: [theme.shareButtonBase, theme.shareButtonBase]),
                        radius: 5.0 / 3.0,
                        offset: CGPoint(x: 0, y: 1.0 / 3.0),
                        intensity: 1
                    )

                RoundedRectangle(cornerRadius: 9)
                    .fill(LinearGradient(oldOS: theme.shareCancelInner))
                    .oldOSAddBorder(LinearGradient(oldOS: theme.shareCancelBorder), width: 0.4, cornerRadius: 9)
                    .padding(3)

                Text(cancelTitle)
                    .font(OldOSFont.bold(18))
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.9), radius: 0, x: 0, y: -0.9)
            }
            .padding([.leading, .trailing], 25)
            .frame(minHeight: 50, maxHeight: 50)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Share sheet

/// The Safari action sheet, wired to real behaviour where iOS allows it.
struct SafariActionsView: View {
    @ObservedObject var store: SafariTabStore
    @ObservedObject var tab: SafariTab
    @ObservedObject var downloads: SafariDownloadManager
    let theme: OldOSSafariTheme
    let topInset: CGFloat
    let bottomInset: CGFloat
    let onClose: () -> Void
    let onShowDownloads: () -> Void

    @State private var showAddBookmark = false
    @State private var showExporter = false
    @State private var exporterURL: URL?
    @State private var bookmarkTitle = ""

    private var currentURL: URL? { tab.url }

    /// The share sheet used to be a fixed 8-button strip, but the app now
    /// mirrors the modern-Safari roster: Reader, Reading List, Save PDF, and
    /// Downloads have all been added. The list is assembled here so absent
    /// affordances (Reader off pages that aren't articles, Downloads when
    /// nothing has ever been downloaded) don't waste a row.
    private var actionButtons: [OldOSSheetButton] {
        var buttons: [OldOSSheetButton] = []

        buttons.append(OldOSSheetButton(title: "Add Bookmark") {
            bookmarkTitle = tab.title.isEmpty ? (currentURL?.host ?? "Untitled") : tab.title
            withAnimation(.linear(duration: 0.25)) { showAddBookmark = true }
        })

        buttons.append(OldOSSheetButton(title: "Add to Reading List") { addToReadingList() })
        buttons.append(OldOSSheetButton(title: "Add to Home Screen") { addToHomeScreen() })
        buttons.append(OldOSSheetButton(title: "Mail Link to this Page") { mailLink() })
        buttons.append(OldOSSheetButton(title: "Copy") { copyLink() })

        if tab.readerAvailable {
            buttons.append(OldOSSheetButton(
                title: tab.isReaderActive ? "Hide Reader" : "Show Reader"
            ) { toggleReader() })
        }

        buttons.append(OldOSSheetButton(title: "Find on Page") { findOnPage() })
        buttons.append(OldOSSheetButton(
            title: tab.isRequestingDesktopSite ? "Request Mobile Site" : "Request Desktop Site"
        ) { requestDesktopSite() })

        buttons.append(OldOSSheetButton(title: "Save PDF to Files") { savePDFToFiles() })

        if !downloads.downloads.isEmpty {
            let count = downloads.runningCount
            let title = count > 0
                ? "Downloads (\(count) active)"
                : "Downloads"
            buttons.append(OldOSSheetButton(title: title) { onShowDownloads() })
        }

        buttons.append(OldOSSheetButton(title: "Share\u{2026}") { systemShare() })
        buttons.append(OldOSSheetButton(title: "Print") { printPage() })

        return buttons
    }

    var body: some View {
        ZStack {
            OldOSActionSheet(
                theme: theme,
                buttons: actionButtons,
                bottomInset: bottomInset,
                onCancel: onClose
            )
            .zIndex(1)

            if showAddBookmark {
                SafariAddBookmarkView(
                    theme: theme,
                    title: $bookmarkTitle,
                    url: currentURL,
                    topInset: topInset,
                    onCancel: { withAnimation(.linear(duration: 0.25)) { showAddBookmark = false } },
                    onSave: {
                        if let currentURL {
                            store.addBookmark(title: bookmarkTitle, url: currentURL.absoluteString)
                        }
                        withAnimation(.linear(duration: 0.25)) { showAddBookmark = false }
                        onClose()
                    }
                )
                .transition(.move(edge: .bottom))
                .zIndex(2)
            }
        }
        .fileExporter(
            isPresented: $showExporter,
            document: exporterURL.map { PDFDocumentFile(url: $0) },
            contentType: .pdf,
            defaultFilename: pdfFilename
        ) { _ in
            exporterURL = nil
        }
    }

    private var pdfFilename: String {
        let base = tab.title.isEmpty
            ? (currentURL?.host ?? "Page")
            : tab.title
        return base
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
    }

    private func mailLink() {
        guard let currentURL else { return }
        let subject = (tab.title.isEmpty ? currentURL.absoluteString : tab.title)
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let body = currentURL.absoluteString
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let mailto = URL(string: "mailto:?subject=\(subject)&body=\(body)") {
            UIApplication.shared.open(mailto, options: [:], completionHandler: nil)
        }
        onClose()
    }

    /// Only the system browser can pin a web clip, so the page is handed over
    /// to it and the user finishes there, instead of a dead button.
    private func addToHomeScreen() {
        guard let currentURL else { return }
        UIPasteboard.general.string = currentURL.absoluteString
        UIApplication.shared.open(currentURL, options: [:], completionHandler: nil)
        onClose()
    }

    private func copyLink() {
        guard let currentURL else { return }
        UIPasteboard.general.string = currentURL.absoluteString
        onClose()
    }

    private func findOnPage() {
        onClose()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { tab.findOnPage() }
    }

    private func requestDesktopSite() {
        tab.toggleDesktopSite()
        onClose()
    }

    private func toggleReader() {
        tab.toggleReader()
        onClose()
    }

    /// The system Reading List is shared with real Safari, so users can flip
    /// back to iOS Safari later and pick up the queued articles.
    private func addToReadingList() {
        guard let currentURL,
              SSReadingList.default() != nil
        else { onClose(); return }

        try? SSReadingList.default()?.addItem(
            with: currentURL,
            title: tab.title,
            previewText: nil
        )
        onClose()
    }

    /// Render the current page as a PDF via WKWebView.createPDF and let the
    /// user drop it into Files / iCloud Drive with the system document
    /// picker.
    private func savePDFToFiles() {
        onClose()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            tab.webView.createPDF { result in
                guard case let .success(data) = result else { return }
                let base = (try? FileManager.default.url(
                    for: .documentDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: true
                )) ?? URL(fileURLWithPath: NSTemporaryDirectory())
                let folder = base.appendingPathComponent("Downloads", isDirectory: true)
                try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

                let filename = "\(pdfFilename).pdf"
                let destination = folder.appendingPathComponent(filename)
                do {
                    try data.write(to: destination)
                    let entry = SafariDownload(
                        sourceURL: tab.url ?? destination,
                        suggestedFilename: filename
                    )
                    entry.updateProgress(received: Int64(data.count), expected: Int64(data.count))
                    entry.markCompleted(at: destination)

                    DispatchQueue.main.async {
                        SafariDownloadManager.shared.register(entry)
                        exporterURL = destination
                        showExporter = true
                    }
                } catch {
                    // Silent — the Downloads row won't appear but nothing else
                    // is disturbed.
                }
            }
        }
    }

    /// Hands the page to the stock iOS share sheet, so AirDrop, Messages,
    /// Reading List and every share extension installed on the device work.
    private func systemShare() {
        guard let currentURL else { return }
        onClose()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            guard
                let scene = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .first(where: { $0.activationState == .foregroundActive }),
                let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
            else { return }

            var presenter = root
            while let presented = presenter.presentedViewController {
                presenter = presented
            }

            let controller = UIActivityViewController(
                activityItems: [currentURL],
                applicationActivities: nil
            )
            // System share sheet always mirrors the device Light/Dark Mode.
            controller.overrideUserInterfaceStyle = .unspecified
            controller.popoverPresentationController?.sourceView = presenter.view
            controller.popoverPresentationController?.sourceRect = CGRect(
                x: presenter.view.bounds.midX,
                y: presenter.view.bounds.maxY - 60,
                width: 1,
                height: 1
            )
            presenter.present(controller, animated: true)
        }
    }

    private func printPage() {
        let controller = UIPrintInteractionController.shared
        let info = UIPrintInfo(dictionary: nil)
        info.outputType = .general
        info.jobName = tab.title.isEmpty ? "Web Page" : tab.title
        controller.printInfo = info
        controller.printFormatter = tab.webView.viewPrintFormatter()
        controller.present(animated: true) { _, _, _ in }
        onClose()
    }
}

/// FileDocument wrapper used by `SafariActionsView`'s `.fileExporter` so the
/// on-disk PDF the browser just wrote can be re-exposed to the document
/// picker without re-encoding it.
private struct PDFDocumentFile: FileDocument {
    static var readableContentTypes: [UTType] { [.pdf] }
    static var writableContentTypes: [UTType] { [.pdf] }

    let url: URL

    init(url: URL) { self.url = url }

    init(configuration: ReadConfiguration) throws {
        throw CocoaError(.featureUnsupported)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        try FileWrapper(url: url, options: .immediate)
    }
}

// MARK: - Add Bookmark

/// OldOS `add_bookmark_view`, kept full screen instead of the 320x480 frame.
struct SafariAddBookmarkView: View {
    let theme: OldOSSafariTheme
    /// "Add Bookmark" when saving a page, "Edit Bookmark" when the Bookmarks
    /// screen reuses the same iOS 6 form.
    var heading: String = "Add Bookmark"
    @Binding var title: String
    let url: URL?
    let topInset: CGFloat
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(oldOS: theme.barGradient)
                .frame(height: topInset)

            ZStack {
                theme.groupedBackground
                OldOSPinstripeBackground(line: theme.groupedPinstripe).clipped()

                VStack(spacing: 0) {
                    OldOSTitleBar(
                        title: heading,
                        theme: theme,
                        leading: OldOSBarButton("Cancel", type: theme.secondaryButton, action: onCancel),
                        trailing: OldOSBarButton("Save", type: .blue, action: onSave)
                    )

                    ScrollView {
                        VStack(spacing: 0) {
                            Spacer().frame(height: 20)

                            OldOSGroupedCard(theme: theme, rowCount: 2) {
                                ZStack {
                                    Rectangle()
                                        .fill(Color.clear)
                                        .frame(height: 50)
                                        .oldOSBorder(width: 1.25, edges: [.bottom], color: theme.cardStroke)

                                    HStack(spacing: 0) {
                                        ZStack(alignment: .leading) {
                                            if title.isEmpty {
                                                Text("Title")
                                                    .font(OldOSFont.regular(18))
                                                    .foregroundColor(theme.cardDetailText)
                                                    .allowsHitTesting(false)
                                            }
                                            TextField("", text: $title)
                                                .font(OldOSFont.regular(18))
                                                .foregroundColor(theme.cardFieldText)
                                                .submitLabel(.done)
                                                .onSubmit(onSave)
                                        }
                                        .padding(.leading, 12)

                                        if !title.isEmpty {
                                            Button { title = "" } label: {
                                                Image("UITextFieldClearButton")
                                            }
                                            .buttonStyle(.plain)
                                            .fixedSize()
                                            .padding(.trailing, 12)
                                        }
                                    }
                                }
                                .frame(height: 50)

                                ZStack {
                                    Rectangle().fill(Color.clear).frame(height: 50)
                                    HStack {
                                        Text(url?.absoluteString ?? "about:blank")
                                            .font(OldOSFont.regular(18))
                                            .foregroundColor(theme.cardDetailText)
                                            .lineLimit(1)
                                            .padding(.leading, 12)
                                        Spacer()
                                    }
                                }
                                .frame(height: 50)
                            }

                            Spacer().frame(height: 20)

                            OldOSGroupedCard(theme: theme, rowCount: 1) {
                                HStack {
                                    Text("Bookmarks")
                                        .font(OldOSFont.regular(18))
                                        .foregroundColor(theme.cardFieldText)
                                        .padding(.leading, 12)
                                    Spacer()
                                    Image("UITableNext").padding(.trailing, 12)
                                }
                                .frame(height: 50)
                            }

                            Spacer(minLength: 20)
                        }
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
        .background(theme.groupedBackground.ignoresSafeArea())
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - System share sheet bridge

/// Retained so the project keeps a UIKit escape hatch for future actions.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        // System share sheet must always follow device Light/Dark Mode.
        controller.overrideUserInterfaceStyle = .unspecified
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
