import SwiftUI
import UIKit

/// OldOS `bookmarks_view`, extended with the History screen iOS 6 actually
/// shipped (day sections, Clear History) and a full Private Browsing skin.
struct SafariLibraryView: View {
    @ObservedObject var store: SafariTabStore
    let theme: OldOSSafariTheme
    let topInset: CGFloat
    let bottomInset: CGFloat
    let onClose: () -> Void

    @State private var showingHistory = false
    @State private var isEditing = false
    @State private var armedBookmark: UUID?
    @State private var confirmClear = false

    var body: some View {
        ZStack {
            theme.listBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Color.clear.frame(height: topInset)

                OldOSTitleBar(
                    title: showingHistory ? "History" : "Bookmarks",
                    theme: theme,
                    leading: showingHistory
                        ? OldOSBarButton("Bookmarks", type: theme.secondaryButton) {
                            withAnimation(.linear(duration: 0.22)) { showingHistory = false }
                        }
                        : nil,
                    trailing: isEditing
                        ? nil
                        : OldOSBarButton("Done", type: .blue, action: onClose)
                )

                if showingHistory {
                    historyList
                } else {
                    bookmarksList
                }

                bottomBar
            }

            if confirmClear {
                OldOSActionSheet(
                    theme: theme,
                    buttons: [
                        OldOSSheetButton(title: "Clear History", destructive: true) {
                            withAnimation(.linear(duration: 0.2)) {
                                store.clearHistory()
                                confirmClear = false
                            }
                        }
                    ],
                    heightFraction: 0.30,
                    bottomInset: bottomInset,
                    onCancel: { withAnimation(.linear(duration: 0.2)) { confirmClear = false } }
                )
                .transition(.move(edge: .bottom))
                .zIndex(5)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: Bookmarks

    private var bookmarksList: some View {
        OldOSPlainList {
            OldOSTableRow(
                icon: "HistoryFolder",
                title: "History",
                theme: theme
            ) {
                withAnimation(.linear(duration: 0.22)) { showingHistory = true }
            }

            ForEach(store.bookmarks) { bookmark in
                OldOSTableRow(
                    icon: "Bookmark",
                    title: bookmark.title.isEmpty ? bookmark.url : bookmark.title,
                    theme: theme,
                    showsChevron: !isEditing,
                    action: {
                        guard !isEditing else { return }
                        open(bookmark.url)
                    },
                    accessory: {
                        HStack(spacing: 0) {
                            if isEditing {
                                OldOSRemoveControl(armed: armedBookmark == bookmark.id) {
                                    withAnimation(.linear(duration: 0.15)) {
                                        armedBookmark = armedBookmark == bookmark.id ? nil : bookmark.id
                                    }
                                }
                                .transition(.move(edge: .leading).combined(with: .opacity))
                            }
                        }
                    }
                )
                .overlay(alignment: .trailing) {
                    if isEditing, armedBookmark == bookmark.id {
                        OldOSRectangleButton(title: "Delete", type: .red) {
                            withAnimation(.linear(duration: 0.2)) {
                                store.removeBookmark(id: bookmark.id)
                                armedBookmark = nil
                            }
                        }
                        .padding(.trailing, 12)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
            }

            if store.bookmarks.isEmpty {
                emptyState(title: "No Bookmarks", subtitle: "Bookmarks you add appear here.")
            }
        }
        .background(theme.listBackground)
    }

    // MARK: History

    private var historyList: some View {
        OldOSPlainList {
            if store.history.isEmpty {
                emptyState(title: "No History", subtitle: "Pages you visit appear here.")
            } else {
                ForEach(SafariHistoryEntry.grouped(store.history), id: \.label) { group in
                    sectionHeader(group.label)

                    ForEach(group.entries) { entry in
                        OldOSTableRow(
                            icon: "Bookmark",
                            title: entry.title.isEmpty ? entry.url : entry.title,
                            detail: entry.url,
                            theme: theme
                        ) {
                            open(entry.url)
                        }
                    }
                }
            }
        }
        .background(theme.listBackground)
    }

    private func sectionHeader(_ label: String) -> some View {
        ZStack {
            LinearGradient(oldOS: theme.barGradient)
                .oldOSBorder(width: 0.95, edges: [.bottom], color: theme.barHairline)

            HStack {
                Text(label)
                    .font(OldOSFont.bold(15))
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.45), radius: 0, x: 0, y: -1)
                    .padding(.leading, 12)
                Spacer()
            }
        }
        .frame(height: 23)
    }

    private func emptyState(title: String, subtitle: String) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(OldOSFont.bold(18))
                .foregroundColor(theme.listRowText)
            Text(subtitle)
                .font(OldOSFont.regular(14))
                .foregroundColor(theme.listRowDetail)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: Bottom bar

    private var bottomBar: some View {
        Group {
            if showingHistory {
                SafariToolbar(
                    theme: theme,
                    mode: .pair(
                        leading: store.history.isEmpty
                            ? nil
                            : OldOSBarButton(" Clear ", type: theme.secondaryButton) {
                                withAnimation(.linear(duration: 0.2)) { confirmClear = true }
                            },
                        trailing: nil
                    ),
                    isPrivate: store.isPrivateMode,
                    bottomInset: bottomInset
                )
            } else {
                SafariToolbar(
                    theme: theme,
                    mode: .bookmarks,
                    isPrivate: store.isPrivateMode,
                    isEditingBookmarks: isEditing,
                    bottomInset: bottomInset,
                    onDone: onClose,
                    onToggleEditing: {
                        withAnimation(.linear(duration: 0.2)) {
                            isEditing.toggle()
                            armedBookmark = nil
                        }
                    }
                )
            }
        }
    }

    // MARK: Actions

    private func open(_ rawURL: String) {
        guard let url = URL(string: rawURL), let tab = store.selected else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        tab.load(url)
        onClose()
    }
}
