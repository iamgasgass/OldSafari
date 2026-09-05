import SwiftUI

/// Shown while a page is still blank.  iOS 6 simply displayed an empty white
/// document, so this stays deliberately quiet: the period-correct pinstriped
/// grouped table with the user's bookmarks, and nothing else.
struct SafariStartPageView: View {
    @ObservedObject var store: SafariTabStore
    @ObservedObject var tab: SafariTab
    let theme: OldOSSafariTheme

    var body: some View {
        ZStack {
            theme.groupedBackground
            OldOSPinstripeBackground(line: theme.groupedPinstripe).clipped()

            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 20)

                    if store.bookmarks.isEmpty {
                        Text("No Bookmarks")
                            .font(OldOSFont.bold(18))
                            .foregroundColor(theme.sectionHeader)
                            .padding(.top, 40)
                    } else {
                        OldOSGroupedCard(theme: theme, rowCount: store.bookmarks.count) {
                            ForEach(Array(store.bookmarks.enumerated()), id: \.element.id) { index, bookmark in
                                Button {
                                    if let url = URL(string: bookmark.url) { tab.load(url) }
                                } label: {
                                    ZStack {
                                        Rectangle()
                                            .fill(Color.clear)
                                            .frame(height: 50)
                                            .oldOSBorder(
                                                width: index == store.bookmarks.count - 1 ? 0 : 1.25,
                                                edges: [.bottom],
                                                color: theme.cardStroke
                                            )
                                        HStack(spacing: 0) {
                                            Image("Bookmark").frame(width: 25, height: 50)
                                            Text(bookmark.title.isEmpty ? bookmark.url : bookmark.title)
                                                .font(OldOSFont.bold(18))
                                                .foregroundColor(theme.listRowText)
                                                .lineLimit(1)
                                                .padding(.leading, 10)
                                            Spacer(minLength: 0)
                                            Image("UITableNext").padding(.trailing, 12)
                                        }
                                        .padding(.leading, 12)
                                    }
                                    .frame(height: 50)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Spacer(minLength: 20)
                }
            }
            .scrollIndicators(.hidden)
        }
    }
}
