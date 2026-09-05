import SwiftUI

struct SafariLibraryView: View {
    @ObservedObject var store: SafariTabStore
    let currentTab: SafariTab?

    @Environment(\.dismiss) private var dismiss
    @State private var section: LibrarySection = .bookmarks
    @State private var editMode: EditMode = .inactive
    @State private var showClearHistoryConfirmation = false

    enum LibrarySection: String, CaseIterable {
        case bookmarks = "Bookmarks"
        case history = "History"
    }

    var body: some View {
        NavigationStack {
            Group {
                switch section {
                case .bookmarks: bookmarksList
                case .history: historyList
                }
            }
            .environment(\.editMode, $editMode)
            .navigationTitle(section.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    leadingToolbarContent
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    Picker("Section", selection: $section.animation()) {
                        ForEach(LibrarySection.allCases, id: \.self) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .confirmationDialog(
                "Clear History",
                isPresented: $showClearHistoryConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear History", role: .destructive) { store.clearHistory() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    @ViewBuilder
    private var leadingToolbarContent: some View {
        switch section {
        case .bookmarks:
            HStack(spacing: 14) {
                Button {
                    guard let tab = currentTab, let url = tab.url?.absoluteString else { return }
                    store.addBookmark(title: tab.title, url: url)
                } label: {
                    Image("Bookmark").resizable().scaledToFit().frame(width: 22, height: 22)
                }
                .disabled(currentTab?.url == nil)

                if !store.bookmarks.isEmpty {
                    Button(editMode.isEditing ? "Done" : "Edit") {
                        withAnimation { editMode = editMode.isEditing ? .inactive : .active }
                    }
                    .font(.system(size: 14))
                }
            }
        case .history:
            if !store.history.isEmpty {
                Button("Clear") { showClearHistoryConfirmation = true }
                    .foregroundStyle(.red)
            }
        }
    }

    private var bookmarksList: some View {
        List {
            if store.bookmarks.isEmpty {
                Text("No Bookmarks").foregroundStyle(.secondary)
            } else {
                ForEach(Array(store.bookmarks.enumerated()), id: \.element.id) { index, bookmark in
                    HStack(spacing: 10) {
                        if editMode.isEditing {
                            Button {
                                withAnimation { store.removeBookmarks(at: IndexSet(integer: index)) }
                            } label: {
                                Image("UIRemoveControlMinus")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 22, height: 22)
                            }
                            .buttonStyle(.plain)
                        }

                        Button {
                            if let url = URL(string: bookmark.url) {
                                currentTab?.load(url)
                            }
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(bookmark.title).font(.headline)
                                Text(bookmark.url).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(editMode.isEditing)
                    }
                }
                .onDelete { store.removeBookmarks(at: $0) }
            }
        }
    }

    private var historyList: some View {
        List {
            if store.history.isEmpty {
                HStack {
                    Image("HistoryFolder").resizable().scaledToFit().frame(width: 24, height: 24)
                    Text("No History").foregroundStyle(.secondary)
                }
            } else {
                ForEach(SafariHistoryEntry.grouped(store.history), id: \.label) { group in
                    Section(group.label) {
                        ForEach(group.entries) { entry in
                            Button {
                                if let url = URL(string: entry.url) {
                                    currentTab?.load(url)
                                }
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(entry.title).font(.subheadline).lineLimit(1)
                                    Text(entry.url)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { store.removeHistory(at: $0, in: group.entries) }
                    }
                }
            }
        }
    }
}
