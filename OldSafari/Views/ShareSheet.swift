import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// Classic Safari action sheet. It is intentionally rendered as an in-app
/// overlay instead of NavigationStack/sheet chrome, matching the OldOS Safari
/// presentation while preserving the browser's edge-to-edge/full-screen view.
struct SafariActionsView: View {
    @ObservedObject var store: SafariTabStore
    let tab: SafariTab
    let onClose: () -> Void

    @State private var showSystemShare = false
    @State private var showBookmarkEditor = false
    @State private var bookmarkTitle = ""

    private var bookmarkExists: Bool {
        guard let url = tab.url?.absoluteString else { return false }
        return store.bookmarks.contains { $0.url == url }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Color.black.opacity(0.38)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { onClose() }

                VStack(spacing: 0) {
                    SafariLegacyNavigationBar(
                        title: "Safari",
                        leading: {
                            Color.clear.frame(width: 70, height: 30)
                        },
                        trailing: {
                            SafariLegacyTextButton(title: "Cancel", compact: true, action: onClose)
                        }
                    )

                    VStack(spacing: 0) {
                        SafariLegacyActionRow(icon: "Bookmark", title: bookmarkExists ? "Bookmarked" : "Add Bookmark", disabled: tab.url == nil || bookmarkExists) {
                            bookmarkTitle = tab.title.isEmpty ? (tab.url?.host ?? "Bookmark") : tab.title
                            showBookmarkEditor = true
                        }

                        SafariLegacyActionRow(systemImage: "doc.on.doc", title: "Copy Link", disabled: tab.url == nil) {
                            UIPasteboard.general.string = tab.url?.absoluteString
                            onClose()
                        }

                        SafariLegacyActionRow(systemImage: "square.and.arrow.up", title: "Share…", disabled: tab.url == nil) {
                            showSystemShare = true
                        }

                        SafariLegacyActionRow(systemImage: "arrow.clockwise", title: "Reload", disabled: false) {
                            tab.reload()
                            onClose()
                        }

                        SafariLegacyActionRow(systemImage: "magnifyingglass", title: "Find on Page", disabled: false) {
                            tab.findOnPage()
                            onClose()
                        }

                        SafariLegacyActionRow(systemImage: "desktopcomputer", title: tab.isRequestingDesktopSite ? "Request Mobile Site" : "Request Desktop Site", disabled: false) {
                            tab.toggleDesktopSite()
                            onClose()
                        }
                    }
                    .background(
                        LinearGradient(
                            colors: [Color.white, Color(red: 0.88, green: 0.90, blue: 0.94)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .frame(maxWidth: .infinity)
                .frame(maxHeight: geometry.size.height * 0.64)
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.black.opacity(0.45), lineWidth: 1))
                .shadow(color: .black.opacity(0.55), radius: 12, x: 0, y: 5)
                .padding(.horizontal, 6)
                .padding(.bottom, max(5, geometry.safeAreaInsets.bottom))

                if showBookmarkEditor {
                    SafariBookmarkEditorOverlay(
                        title: $bookmarkTitle,
                        url: tab.url?.absoluteString ?? "",
                        onCancel: { showBookmarkEditor = false },
                        onSave: {
                            store.addBookmark(title: bookmarkTitle, url: tab.url?.absoluteString ?? "")
                            showBookmarkEditor = false
                            onClose()
                        }
                    )
                    .zIndex(5)
                }
            }
        }
        .sheet(isPresented: $showSystemShare) {
            if let url = tab.url {
                ShareSheet(items: [url])
            }
        }
    }
}

private struct SafariLegacyActionRow: View {
    let icon: String?
    let systemImage: String?
    let title: String
    let disabled: Bool
    let action: () -> Void

    init(icon: String, title: String, disabled: Bool, action: @escaping () -> Void) {
        self.icon = icon
        self.systemImage = nil
        self.title = title
        self.disabled = disabled
        self.action = action
    }

    init(systemImage: String, title: String, disabled: Bool, action: @escaping () -> Void) {
        self.icon = nil
        self.systemImage = systemImage
        self.title = title
        self.disabled = disabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Group {
                    if let icon {
                        Image(icon).resizable().scaledToFit()
                    } else if let systemImage {
                        Image(systemName: systemImage)
                    }
                }
                .frame(width: 24, height: 24)
                .foregroundColor(Color(red: 0.06, green: 0.16, blue: 0.34))

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(red: 0.04, green: 0.12, blue: 0.25))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.black.opacity(0.32))
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
            .background(
                LinearGradient(
                    colors: [Color.white, Color(red: 0.88, green: 0.90, blue: 0.94)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(alignment: .bottom) { Rectangle().fill(Color.black.opacity(0.14)).frame(height: 1) }
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
    }
}

private struct SafariBookmarkEditorOverlay: View {
    @Binding var title: String
    let url: String
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.46).ignoresSafeArea()
            VStack(spacing: 0) {
                SafariLegacyNavigationBar(
                    title: "Add Bookmark",
                    leading: {
                        SafariLegacyTextButton(title: "Cancel", compact: true, action: onCancel)
                    },
                    trailing: {
                        SafariLegacyTextButton(
                            title: "Save",
                            highlighted: true,
                            compact: true,
                            action: onSave
                        )
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || url.isEmpty)
                        .opacity(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || url.isEmpty ? 0.45 : 1)
                    }
                )

                VStack(alignment: .leading, spacing: 7) {
                    Text("Title")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.black.opacity(0.55))
                    TextField("Title", text: $title)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 15))

                    Text("Address")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.black.opacity(0.55))
                        .padding(.top, 5)
                    Text(url)
                        .font(.system(size: 12))
                        .foregroundColor(.black.opacity(0.65))
                        .lineLimit(2)
                }
                .padding(14)

                Spacer()
            }
            .frame(maxWidth: 360, maxHeight: 250)
            .background(Color(red: 0.94, green: 0.95, blue: 0.97))
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.black.opacity(0.45), lineWidth: 1))
            .shadow(color: .black.opacity(0.55), radius: 12, x: 0, y: 5)
        }
    }
}
