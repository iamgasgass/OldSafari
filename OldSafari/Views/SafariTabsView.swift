import SwiftUI
import UIKit

struct SafariTabsView: View {
    @ObservedObject var store: SafariTabStore
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient.ignoresSafeArea()

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(store.visibleTabs) { tab in
                            SafariTabCard(tab: tab) {
                                store.select(tab)
                                dismiss()
                            } onClose: {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                store.close(tab)
                            }
                        }
                    }
                    .padding(16)

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        store.addTab()
                        dismiss()
                    } label: {
                        Label("New Page", systemImage: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 9)
                            .background(Color.blue.opacity(0.9))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle(store.isPrivateMode ? "Private" : "Pages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        store.togglePrivateMode()
                    } label: {
                        Label(
                            store.isPrivateMode ? "Regular" : "Private",
                            systemImage: store.isPrivateMode ? "sun.max" : "eyeglasses"
                        )
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(store.isPrivateMode ? .dark : .light)
    }

    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: store.isPrivateMode
                ? [OldSafariPalette.tabsBackgroundTopPrivate, OldSafariPalette.tabsBackgroundBottomPrivate]
                : [OldSafariPalette.tabsBackgroundTop, OldSafariPalette.tabsBackgroundBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private struct SafariTabCard: View {
    @ObservedObject var tab: SafariTab
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(tab.title.isEmpty ? "Untitled" : tab.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Button(action: onClose) {
                        Image("closebox")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.top, 8)

                Text(tab.url?.host ?? "About Blank")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.top, 2)

                Spacer(minLength: 8)

                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 68)
                    .overlay(
                        Image(systemName: tab.isPrivate ? "eyeglasses" : "globe")
                            .font(.system(size: 22))
                            .foregroundStyle(.white.opacity(0.5))
                    )
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
            }
            .frame(maxWidth: .infinity, minHeight: 130)
            .background(
                RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.24))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
