import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// Restores the action sheet behaviour of the original OldOS Safari while
/// leaving the existing full-screen chrome untouched.
struct SafariActionsView: View {
    @ObservedObject var store: SafariTabStore
    let tab: SafariTab

    @Environment(\.dismiss) private var dismiss
    @State private var showSystemShare = false
    @State private var showBookmarkEditor = false
    @State private var bookmarkTitle = ""

    private var bookmarkExists: Bool {
        guard let url = tab.url?.absoluteString else { return false }
        return store.bookmarks.contains { $0.url == url }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        bookmarkTitle = tab.title.isEmpty
                            ? (tab.url?.host ?? "Bookmark")
                            : tab.title
                        showBookmarkEditor = true
                    } label: {
                        Label("Add Bookmark", systemImage: "bookmark")
                    }
                    .disabled(tab.url == nil || bookmarkExists)

                    Button { showSystemShare = true } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }

                Section {
                    Button {
                        UIPasteboard.general.string = tab.url?.absoluteString
                        dismiss()
                    } label: {
                        Label("Copy Link", systemImage: "doc.on.doc")
                    }
                    .disabled(tab.url == nil)
                }
            }
            .navigationTitle("Safari")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showSystemShare) {
                if let url = tab.url {
                    ShareSheet(items: [url])
                }
            }
            .sheet(isPresented: $showBookmarkEditor) {
                SafariBookmarkEditor(
                    title: $bookmarkTitle,
                    url: tab.url?.absoluteString ?? "",
                    onCancel: { showBookmarkEditor = false },
                    onSave: {
                        store.addBookmark(
                            title: bookmarkTitle,
                            url: tab.url?.absoluteString ?? ""
                        )
                        showBookmarkEditor = false
                        dismiss()
                    }
                )
                .presentationDetents([.medium])
            }
        }
    }
}

struct SafariBookmarkEditor: View {
    @Binding var title: String
    let url: String
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Bookmark") {
                    TextField("Title", text: $title)
                    LabeledContent("Address", value: url)
                }
            }
            .navigationTitle("Add Bookmark")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: onSave)
                        .disabled(
                            title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || url.isEmpty
                        )
                }
            }
        }
    }
}
