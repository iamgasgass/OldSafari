import SwiftUI
import UIKit

/// OldOS/iOS 6 styled Bookmarks + History library. The two sections share one
/// explicit selection state, just like Pages uses store.selectedID. Actions
/// always operate on the current SafariTab instance passed by SafariRootView.
struct SafariLibraryView: View {
    @ObservedObject var store: SafariTabStore
    let currentTab: SafariTab?
    let onClose: () -> Void

    @State private var section = 0
    @State private var editing = false
    @State private var showClearHistory = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(red: 0.92, green: 0.93, blue: 0.95).ignoresSafeArea()

                VStack(spacing: 0) {
                    SafariLegacyNavigationBar(
                        title: section == 0 ? "Bookmarks" : "History",
                        leading: {
                            if section == 0 && !store.bookmarks.isEmpty {
                                SafariLegacyTextButton(title: editing ? "Done" : "Edit", compact: true) {
                                    withAnimation(.easeOut(duration: 0.12)) { editing.toggle() }
                                }
                            } else if section == 1 && !store.history.isEmpty {
                                SafariLegacyTextButton(title: "Clear", destructive: true, compact: true) {
                                    showClearHistory = true
                                }
                            } else {
                                Color.clear.frame(height: 30)
                            }
                        },
                        trailing: {
                            SafariLegacyTextButton(title: "Done", compact: true, action: onClose)
                        }
                    )

                    SafariLegacySegmentedControl(selection: $section, labels: ["Bookmarks", "History"])
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)

                    if section == 0 {
                        bookmarksList
                    } else {
                        historyList
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if showClearHistory {
                    SafariLegacyConfirmationOverlay(
                        title: "Clear History?",
                        message: "This will remove all non-private browsing history.",
                        destructiveTitle: "Clear History",
                        onCancel: { showClearHistory = false },
                        onConfirm: {
                            store.clearHistory()
                            showClearHistory = false
                        }
                    )
                    .zIndex(10)
                }
            }
            .padding(.top, geometry.safeAreaInsets.top)
            .padding(.bottom, geometry.safeAreaInsets.bottom)
            .ignoresSafeArea()
        }
    }

    private var bookmarksList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if store.bookmarks.isEmpty {
                    SafariLibraryEmptyState(icon: "Bookmark", title: "No Bookmarks", subtitle: "Bookmarks you add will appear here.")
                } else {
                    ForEach(Array(store.bookmarks.enumerated()), id: \.element.id) { index, bookmark in
                        HStack(spacing: 0) {
                            if editing {
                                Button {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    withAnimation(.easeOut(duration: 0.15)) {
                                        store.removeBookmarks(at: IndexSet(integer: index))
                                    }
                                } label: {
                                    Image("UIRemoveControlMinus")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 23, height: 23)
                                        .padding(.horizontal, 9)
                                }
                                .buttonStyle(.plain)
                            }

                            Button {
                                guard let url = URL(string: bookmark.url), let currentTab else { return }
                                currentTab.load(url)
                                onClose()
                            } label: {
                                HStack(spacing: 9) {
                                    Image("Bookmark")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 24, height: 24)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(bookmark.title.isEmpty ? "Untitled" : bookmark.title)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(Color(red: 0.05, green: 0.10, blue: 0.18))
                                            .lineLimit(1)
                                        Text(bookmark.url)
                                            .font(.system(size: 10))
                                            .foregroundColor(.black.opacity(0.55))
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.black.opacity(0.35))
                                }
                                .padding(.horizontal, 10)
                                .frame(minHeight: 56)
                            }
                            .buttonStyle(.plain)
                            .disabled(editing)
                        }
                        .background(Color.white)
                        .overlay(alignment: .bottom) { Rectangle().fill(Color.black.opacity(0.14)).frame(height: 1) }
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var historyList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if store.history.isEmpty {
                    SafariLibraryEmptyState(icon: "HistoryFolder", title: "No History", subtitle: "Pages you visit will appear here.")
                } else {
                    ForEach(SafariHistoryEntry.grouped(store.history), id: \.label) { group in
                        Text(group.label.uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(red: 0.24, green: 0.31, blue: 0.40))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.top, 12)
                            .padding(.bottom, 4)

                        ForEach(group.entries) { entry in
                            Button {
                                guard let url = URL(string: entry.url), let currentTab else { return }
                                currentTab.load(url)
                                onClose()
                            } label: {
                                HStack(spacing: 9) {
                                    Image("HistoryFolder")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 24, height: 24)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(entry.title.isEmpty ? "Untitled" : entry.title)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(Color(red: 0.05, green: 0.10, blue: 0.18))
                                            .lineLimit(1)
                                        Text(entry.url)
                                            .font(.system(size: 10))
                                            .foregroundColor(.black.opacity(0.55))
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.black.opacity(0.35))
                                }
                                .padding(.horizontal, 10)
                                .frame(minHeight: 54)
                            }
                            .buttonStyle(.plain)
                            .background(Color.white)
                            .overlay(alignment: .bottom) { Rectangle().fill(Color.black.opacity(0.14)).frame(height: 1) }
                        }
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}

private struct SafariLibraryEmptyState: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 8) {
            Image(icon)
                .resizable()
                .scaledToFit()
                .frame(width: 42, height: 42)
                .opacity(0.65)
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(Color(red: 0.20, green: 0.24, blue: 0.29))
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundColor(.black.opacity(0.52))
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.top, 70)
        .padding(.horizontal, 30)
    }
}

private struct SafariLegacyConfirmationOverlay: View {
    let title: String
    let message: String
    let destructiveTitle: String
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 0) {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(Color(red: 0.05, green: 0.10, blue: 0.18))
                    .padding(.top, 15)
                Text(message)
                    .font(.system(size: 12))
                    .foregroundColor(.black.opacity(0.60))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
                    .padding(.top, 5)
                    .padding(.bottom, 14)
                HStack(spacing: 0) {
                    SafariLegacyTextButton(title: "Cancel", compact: true, action: onCancel)
                    SafariLegacyTextButton(title: destructiveTitle, destructive: true, compact: true, action: onConfirm)
                }
                .padding(8)
            }
            .frame(maxWidth: 310)
            .background(Color(red: 0.94, green: 0.95, blue: 0.97))
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.black.opacity(0.45), lineWidth: 1))
            .shadow(color: .black.opacity(0.55), radius: 12, x: 0, y: 5)
        }
    }
}
