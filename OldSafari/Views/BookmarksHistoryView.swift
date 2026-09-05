import SwiftUI

public struct BookmarksHistoryView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var dataManager = SafariDataManager.shared
    
    @State private var selectedTab: Int = 0 // 0 = Segnalibri, 1 = Cronologia
    @State private var searchText: String = ""
    var isPrivate: Bool
    var onSelectURL: (String) -> Void

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar iOS 6 Style
            HStack {
                // Segmented Picker
                Picker("", selection: $selectedTab) {
                    Text("Segnalibri").tag(0)
                    Text("Cronologia").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(maxWidth: 220)
                
                Spacer()
                
                // Done Button
                Button("Fine") {
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(iOS6ButtonStyle(isPrivate: isPrivate, isBlue: true))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isPrivate ? iOS6Theme.navBarGradientPrivate : iOS6Theme.navBarGradientNormal)
            .overlay(
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(Color.black.opacity(0.6))
                        .frame(height: 1)
                }
            )

            // Content List
            if selectedTab == 0 {
                // BOOKMARKS LIST
                List {
                    ForEach(filteredBookmarks) { item in
                        Button(action: {
                            onSelectURL(item.url)
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            HStack {
                                Image(systemName: item.isFolder ? "folder.fill" : "bookmark.fill")
                                    .foregroundColor(item.isFolder ? .blue : (isPrivate ? .white : .blue))
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(isPrivate ? .white : .black)
                                    if !item.isFolder {
                                        Text(item.url)
                                            .font(.system(size: 11))
                                            .foregroundColor(.gray)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(isPrivate ? Color(red: 0.15, green: 0.16, blue: 0.18) : Color.white)
                    }
                    .onDelete(perform: deleteBookmark)
                }
                .listStyle(PlainListStyle())
                .background(isPrivate ? Color.black : Color(red: 0.92, green: 0.92, blue: 0.95))
            } else {
                // HISTORY LIST
                VStack(spacing: 0) {
                    List {
                        ForEach(filteredHistory) { item in
                            Button(action: {
                                onSelectURL(item.url)
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                HStack {
                                    Image(systemName: "clock.fill")
                                        .foregroundColor(.gray)
                                        .frame(width: 24)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.title)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(isPrivate ? .white : .black)
                                        Text(item.url)
                                            .font(.system(size: 11))
                                            .foregroundColor(.gray)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                            .listRowBackground(isPrivate ? Color(red: 0.15, green: 0.16, blue: 0.18) : Color.white)
                        }
                    }
                    .listStyle(PlainListStyle())
                    .background(isPrivate ? Color.black : Color(red: 0.92, green: 0.92, blue: 0.95))

                    // Clear History Footer Button
                    if !dataManager.history.isEmpty {
                        Button(action: {
                            dataManager.clearHistory()
                        }) {
                            Text("Cancella cronologia")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(isPrivate ? Color(red: 0.18, green: 0.19, blue: 0.22) : Color.white)
                                .border(Color.gray.opacity(0.3), width: 1)
                        }
                    }
                }
            }
        }
        .ios6LinenBackground(isPrivate: isPrivate)
    }

    private var filteredBookmarks: [BookmarkItem] {
        if searchText.isEmpty { return dataManager.bookmarks }
        return dataManager.bookmarks.filter { $0.title.localizedCaseInsensitiveContains(searchText) || $0.url.localizedCaseInsensitiveContains(searchText) }
    }

    private var filteredHistory: [HistoryItem] {
        if searchText.isEmpty { return dataManager.history }
        return dataManager.history.filter { $0.title.localizedCaseInsensitiveContains(searchText) || $0.url.localizedCaseInsensitiveContains(searchText) }
    }

    private func deleteBookmark(at offsets: IndexSet) {
        dataManager.bookmarks.remove(atOffsets: offsets)
    }
}
