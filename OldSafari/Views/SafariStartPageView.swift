import SwiftUI

struct SafariStartPageView: View {
    @ObservedObject var store: SafariTabStore
    let tab: SafariTab

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            if tab.isPrivate {
                VStack(spacing: 10) {
                    Image(systemName: "eyeglasses")
                        .font(.system(size: 34))
                        .foregroundStyle(.white.opacity(0.85))
                    Text("Private Browsing")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Safari won't remember the pages you visit, your search history, or your AutoFill information in this tab.")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding(.top, 80)
            } else {
                Text("Favorites")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 24)

                LazyVGrid(columns: columns, spacing: 18) {
                    ForEach(store.bookmarks) { bookmark in
                        Button {
                            if let url = URL(string: bookmark.url) {
                                tab.load(url)
                            }
                        } label: {
                            VStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.secondarySystemBackground))
                                    .frame(width: 56, height: 56)
                                    .overlay(
                                        Text(String(bookmark.title.prefix(1)).uppercased())
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundStyle(.secondary)
                                    )
                                Text(bookmark.title)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(tab.isPrivate ? Color.black : Color(.systemBackground))
    }
}
