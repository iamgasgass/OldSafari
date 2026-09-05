import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// OldOS-style Safari action panel.  The panel itself is custom skeuomorphic
/// chrome; the system share controller is used only for actual OS sharing.
struct SafariActionsView: View {
    @ObservedObject var store: SafariTabStore
    let onClose: () -> Void

    @State private var showSystemShare = false
    @State private var showMailShare = false
    @State private var showBookmarkEditor = false
    @State private var bookmarkTitle = ""
    @State private var targetTabID: UUID?

    private var currentTab: SafariTab? { store.tab(for: targetTabID) ?? store.selected }
    private var privateMode: Bool { store.isPrivateMode }
    private var text: Color { privateMode ? .white : Color(red: 0.04, green: 0.12, blue: 0.25) }
    private var muted: Color { privateMode ? .white.opacity(0.58) : .black.opacity(0.32) }
    private var rowTop: Color { privateMode ? Color(red: 0.18, green: 0.18, blue: 0.21) : .white }
    private var rowBottom: Color { privateMode ? Color(red: 0.08, green: 0.08, blue: 0.10) : Color(red: 0.88, green: 0.90, blue: 0.94) }

    private var bookmarkExists: Bool {
        guard let url = currentTab?.url?.absoluteString else { return false }
        return store.bookmarks.contains { $0.url == url }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Color.black.opacity(0.42).ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { onClose() }

                VStack(spacing: 0) {
                    SafariLegacyNavigationBar(
                        title: "Safari",
                        leading: { Color.clear.frame(width: 70, height: 30) },
                        trailing: { SafariLegacyTextButton(title: "Cancel", compact: true, action: onClose) }
                    )

                    ScrollView {
                        VStack(spacing: 0) {
                            actionRow(icon: "Bookmark", title: bookmarkExists ? "Bookmarked" : "Add Bookmark",
                                      disabled: currentTab?.url == nil || bookmarkExists) {
                                bookmarkTitle = currentTab?.title.isEmpty == false
                                    ? currentTab?.title ?? "Bookmark"
                                    : (currentTab?.url?.host ?? "Bookmark")
                                showBookmarkEditor = true
                            }
                            actionRow(systemImage: "doc.on.doc", title: "Copy Link", disabled: currentTab?.url == nil) {
                                UIPasteboard.general.string = currentTab?.url?.absoluteString
                                onClose()
                            }
                            actionRow(systemImage: "square.and.arrow.up", title: "Share…", disabled: currentTab?.url == nil) {
                                showSystemShare = true
                            }
                            actionRow(systemImage: "arrow.clockwise", title: "Reload", disabled: currentTab == nil) {
                                currentTab?.reload(); onClose()
                            }
                            actionRow(systemImage: "magnifyingglass", title: "Find on Page", disabled: currentTab == nil) {
                                currentTab?.findOnPage(); onClose()
                            }
                            actionRow(systemImage: "desktopcomputer",
                                      title: currentTab?.isRequestingDesktopSite == true ? "Request Mobile Site" : "Request Desktop Site",
                                      disabled: currentTab == nil) {
                                currentTab?.toggleDesktopSite(); onClose()
                            }
                            actionRow(systemImage: "house", title: "Add to Home Screen", disabled: true) {}
                            actionRow(systemImage: "envelope", title: "Mail Link to this Page", disabled: currentTab?.url == nil) {
                                showMailShare = true
                            }
                            actionRow(systemImage: "printer", title: "Print", disabled: currentTab?.url == nil) {
                                if let webView = currentTab?.webView {
                                    let controller = UIPrintInteractionController.shared
                                    controller.printFormatter = webView.viewPrintFormatter()
                                    controller.present(animated: true)
                                }
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    .background(LinearGradient(colors: [rowTop, rowBottom], startPoint: .top, endPoint: .bottom))
                }
                .frame(maxWidth: .infinity)
                .frame(maxHeight: geometry.size.height * 0.70)
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.black.opacity(0.45), lineWidth: 1))
                .shadow(color: .black.opacity(0.55), radius: 12, x: 0, y: 5)
                .padding(.horizontal, 6)
                .padding(.bottom, max(5, geometry.safeAreaInsets.bottom))

                if showBookmarkEditor {
                    SafariBookmarkEditorOverlay(
                        privateMode: privateMode,
                        title: $bookmarkTitle,
                        url: currentTab?.url?.absoluteString ?? "",
                        onCancel: { showBookmarkEditor = false },
                        onSave: {
                            store.addBookmark(title: bookmarkTitle, url: currentTab?.url?.absoluteString ?? "")
                            showBookmarkEditor = false
                            onClose()
                        }
                    ).zIndex(5)
                }
            }
        }
        .onAppear { targetTabID = store.selectedID }
        .preferredColorScheme(privateMode ? .dark : .light)
        .sheet(isPresented: $showSystemShare) {
            if let url = currentTab?.url { ShareSheet(items: [url]) }
        }
        .sheet(isPresented: $showMailShare) {
            if let url = currentTab?.url {
                ShareSheet(items: ["\(currentTab?.title ?? "")\n\(url.absoluteString)", url])
            }
        }
    }

    @ViewBuilder
    private func actionRow(icon: String? = nil, systemImage: String? = nil,
                           title: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Group {
                    if let icon { Image(icon).resizable().scaledToFit() }
                    else if let systemImage { Image(systemName: systemImage) }
                }
                .frame(width: 24, height: 24)
                .foregroundStyle(privateMode ? .white.opacity(0.82) : Color(red: 0.06, green: 0.16, blue: 0.34))

                Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(text)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(muted)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
            .background(LinearGradient(colors: [rowTop, rowBottom], startPoint: .top, endPoint: .bottom))
            .overlay(alignment: .bottom) {
                Rectangle().fill(privateMode ? Color.white.opacity(0.10) : Color.black.opacity(0.14)).frame(height: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
    }
}

private struct SafariBookmarkEditorOverlay: View {
    let privateMode: Bool
    @Binding var title: String
    let url: String
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.50).ignoresSafeArea()
            VStack(spacing: 0) {
                SafariLegacyNavigationBar(
                    title: "Add Bookmark",
                    leading: { SafariLegacyTextButton(title: "Cancel", compact: true, action: onCancel) },
                    trailing: {
                        SafariLegacyTextButton(title: "Save", highlighted: true, compact: true, action: onSave)
                            .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || url.isEmpty)
                    }
                )
                VStack(alignment: .leading, spacing: 7) {
                    Text("Title").font(.system(size: 12, weight: .bold))
                        .foregroundStyle(privateMode ? .white.opacity(0.65) : .black.opacity(0.55))
                    TextField("Title", text: $title)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 15))
                    Text("Address").font(.system(size: 12, weight: .bold))
                        .foregroundStyle(privateMode ? .white.opacity(0.65) : .black.opacity(0.55))
                        .padding(.top, 5)
                    Text(url).font(.system(size: 12))
                        .foregroundStyle(privateMode ? .white.opacity(0.62) : .black.opacity(0.65))
                        .lineLimit(2)
                }
                .padding(14)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: 360, maxHeight: 250)
            .background(privateMode ? Color(red: 0.13, green: 0.13, blue: 0.16) : Color(red: 0.94, green: 0.95, blue: 0.97))
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.black.opacity(0.45), lineWidth: 1))
            .shadow(color: .black.opacity(0.55), radius: 12, x: 0, y: 5)
        }
    }
}
