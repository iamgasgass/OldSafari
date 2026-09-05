import SwiftUI
import UIKit
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
        return min(max(content, minimum), available * 0.88)
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

                        Spacer(minLength: 0)

                        cancelButton
                            .padding(.bottom, 25 + bottomInset)
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
    let theme: OldOSSafariTheme
    let topInset: CGFloat
    let bottomInset: CGFloat
    let onClose: () -> Void

    @State private var showAddBookmark = false
    @State private var bookmarkTitle = ""

    private var currentURL: URL? { tab.url }

    var body: some View {
        ZStack {
            OldOSActionSheet(
                theme: theme,
                buttons: [
                    OldOSSheetButton(title: "Add Bookmark") {
                        bookmarkTitle = tab.title.isEmpty ? (currentURL?.host ?? "Untitled") : tab.title
                        withAnimation(.linear(duration: 0.25)) { showAddBookmark = true }
                    },
                    OldOSSheetButton(title: "Add to Home Screen") {},
                    OldOSSheetButton(title: "Mail Link to this Page") { mailLink() },
                    OldOSSheetButton(title: "Copy") { copyLink() },
                    OldOSSheetButton(title: "Find on Page") { findOnPage() },
                    OldOSSheetButton(
                        title: tab.isRequestingDesktopSite ? "Request Mobile Site" : "Request Desktop Site"
                    ) { requestDesktopSite() },
                    OldOSSheetButton(title: "Share\u{2026}") { systemShare() },
                    OldOSSheetButton(title: "Print") { printPage() }
                ],
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

// MARK: - Add Bookmark

/// OldOS `add_bookmark_view`, kept full screen instead of the 320x480 frame.
struct SafariAddBookmarkView: View {
    let theme: OldOSSafariTheme
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
                        title: "Add Bookmark",
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
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
