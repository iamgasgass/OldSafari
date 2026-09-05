import SwiftUI
import UIKit

/// OldOS Safari tab switcher: the live page shrinks to 55%, neighbouring pages
/// peek in from the sides at 20% opacity, the page title sits at 1/9 of the
/// height and the page dots at 1.5/9 from the bottom.
struct SafariTabsView: View {
    @ObservedObject var store: SafariTabStore
    let theme: OldOSSafariTheme
    let topInset: CGFloat
    let bottomInset: CGFloat
    let onClose: () -> Void

    @State private var index: Int = 0
    @State private var drag: CGFloat = 0

    private var tabs: [SafariTab] { store.visibleTabs }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let step = width * 0.70
            let cardHeight = max(height - (topInset + 45 + 6 + bottomInset), 120)

            ZStack {
                LinearGradient(oldOS: theme.tabsBackground).ignoresSafeArea()

                ZStack {
                    ForEach(Array(tabs.enumerated()), id: \.element.id) { position, tab in
                        let distance = abs(CGFloat(position - index) + drag / max(step, 1))

                        card(tab: tab, position: position, width: width, height: cardHeight, live: distance < 1.4)
                            .offset(x: CGFloat(position - index) * step + drag)
                            .opacity(Double(max(0.2, 1 - distance * 0.8)))
                            .zIndex(distance < 0.5 ? 1 : 0)
                    }
                }
                .offset(y: (topInset - 45 - 6 - bottomInset) / 2)

                VStack(spacing: 0) {
                    Spacer().frame(height: max(height * (1.0 / 9.0), topInset + 8))

                    Text(currentTitle)
                        .font(OldOSFont.bold(22))
                        .foregroundColor(theme.tabTitle)
                        .shadow(color: theme.tabTitleShadow, radius: 0, x: 0, y: -2.0 / 3.0)
                        .lineLimit(1)
                        .padding([.leading, .trailing], 20)

                    Text(currentURL)
                        .font(OldOSFont.bold(16))
                        .foregroundColor(theme.tabURL)
                        .lineLimit(1)
                        .padding([.leading, .trailing], 20)

                    Spacer(minLength: 0)

                    HStack(spacing: 9) {
                        ForEach(tabs.indices, id: \.self) { position in
                            Circle()
                                .fill(Color.white.opacity(position == index ? 1 : 0.25))
                                .frame(width: 7.5, height: 7.5)
                        }
                    }
                    .padding(.bottom, max(height * (1.5 / 9.0), 45 + bottomInset + 18))
                }
                .allowsHitTesting(false)

                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    SafariToolbar(
                        theme: theme,
                        mode: .tabs,
                        tabCount: tabs.count,
                        isPrivate: store.isPrivateMode,
                        canCreateTab: tabs.count < 8,
                        bottomInset: bottomInset,
                        onNewPage: {
                            store.addTab()
                            syncIndex()
                            onClose()
                        },
                        onDone: {
                            commitSelection()
                            onClose()
                        },
                        onTogglePrivate: {
                            withAnimation(.linear(duration: 0.25)) {
                                store.togglePrivateMode()
                                syncIndex()
                            }
                        }
                    )
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let raw = value.translation.width
                        let atStart = index == 0 && raw > 0
                        let atEnd = index == tabs.count - 1 && raw < 0
                        drag = (atStart || atEnd) ? raw * 0.32 : raw
                    }
                    .onEnded { value in
                        let threshold = step / 3
                        if abs(value.translation.width) > threshold {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                        withAnimation(.interpolatingSpring(stiffness: 190, damping: 24)) {
                            if value.translation.width < -threshold, index < tabs.count - 1 {
                                index += 1
                            } else if value.translation.width > threshold, index > 0 {
                                index -= 1
                            }
                            drag = 0
                        }
                        commitSelection()
                    }
            )
        }
        .onAppear(perform: syncIndex)
        .onChange(of: store.isPrivateMode) { _ in syncIndex() }
    }

    // MARK: Card

    private func card(tab: SafariTab, position: Int, width: CGFloat, height: CGFloat, live: Bool) -> some View {
        ZStack {
            Group {
                if tab.url == nil {
                    SafariStartPageView(store: store, tab: tab, theme: theme)
                } else if live {
                    // Only the visible neighbours keep a live web view attached,
                    // the rest fall back to a cheap placeholder.
                    SafariWebView(tab: tab)
                } else {
                    theme.pageBackground
                }
            }
            .frame(width: width, height: height)
            .background(theme.pageBackground)
            .allowsHitTesting(false)
            .shadow(color: Color.black.opacity(0.4), radius: 3, x: 0, y: 4)
        }
        .frame(width: width, height: height)
        .scaleEffect(0.55)
        .frame(width: width * 0.55, height: height * 0.55)
        .contentShape(Rectangle())
        .onTapGesture {
            if position == index {
                commitSelection()
                onClose()
            } else {
                withAnimation(.linear(duration: 0.25)) { index = position }
                commitSelection()
            }
        }
        .overlay(alignment: .topLeading) {
            if position == index, tabs.count > 1 {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    withAnimation(.linear(duration: 0.25)) {
                        store.close(tab)
                        index = min(index, max(store.visibleTabs.count - 1, 0))
                    }
                } label: {
                    Image("closebox")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 29, height: 29)
                }
                .buttonStyle(.plain)
                .offset(x: -14, y: -14)
            }
        }
    }

    // MARK: Helpers

    private var currentTitle: String {
        guard tabs.indices.contains(index) else { return "Untitled" }
        let title = tabs[index].title
        return title.isEmpty ? "Untitled" : title
    }

    private var currentURL: String {
        guard tabs.indices.contains(index) else { return "" }
        return tabs[index].url?.host ?? "about:blank"
    }

    private func syncIndex() {
        if let selected = store.selectedID, let position = tabs.firstIndex(where: { $0.id == selected }) {
            index = position
        } else {
            index = max(min(index, tabs.count - 1), 0)
        }
    }

    private func commitSelection() {
        guard tabs.indices.contains(index) else { return }
        store.select(tabs[index])
    }
}
