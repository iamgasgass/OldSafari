import SwiftUI

/// Reusable iOS 6 / OldOS-style controls. Keep these controls shared by Pages,
/// Bookmarks/History and the Safari action sheet so the chrome stays consistent.
struct SafariLegacyButtonStyle: ButtonStyle {
    var highlighted = false
    var destructive = false
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 13 : 15, weight: .semibold))
            .foregroundColor(destructive ? Color(red: 0.55, green: 0.03, blue: 0.03) : Color(red: 0.04, green: 0.16, blue: 0.38))
            .padding(.horizontal, compact ? 9 : 13)
            .frame(minHeight: compact ? 30 : 36)
            .background(
                LinearGradient(
                    colors: configuration.isPressed || highlighted
                        ? [Color(red: 0.76, green: 0.80, blue: 0.86), Color(red: 0.98, green: 0.99, blue: 1.0)]
                        : [Color.white, Color(red: 0.76, green: 0.80, blue: 0.86)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color(red: 0.20, green: 0.27, blue: 0.38), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .shadow(color: .black.opacity(0.35), radius: 1, x: 0, y: 1)
            .opacity(configuration.isPressed ? 0.78 : 1)
    }
}

struct SafariLegacyTextButton: View {
    let title: String
    var highlighted = false
    var destructive = false
    var compact = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
        }
        .buttonStyle(SafariLegacyButtonStyle(highlighted: highlighted, destructive: destructive, compact: compact))
    }
}

struct SafariLegacyIconButton: View {
    let image: String
    var title: String? = nil
    var disabled = false
    var destructive = false
    let action: () -> Void

    var body: some View {
        Button {
            guard !disabled else { return }
            action()
        } label: {
            HStack(spacing: 5) {
                Image(image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                if let title { Text(title) }
            }
        }
        .buttonStyle(SafariLegacyButtonStyle(destructive: destructive, compact: true))
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
    }
}

struct SafariLegacySegmentedControl: View {
    @Binding var selection: Int
    let labels: [String]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(labels.indices, id: \.self) { index in
                Button {
                    withAnimation(.easeOut(duration: 0.12)) { selection = index }
                } label: {
                    Text(labels[index])
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(selection == index ? .white : Color(red: 0.05, green: 0.14, blue: 0.31))
                        .frame(maxWidth: .infinity, minHeight: 30)
                        .background(
                            LinearGradient(
                                colors: selection == index
                                    ? [Color(red: 0.34, green: 0.50, blue: 0.72), Color(red: 0.12, green: 0.27, blue: 0.50)]
                                    : [Color.white, Color(red: 0.76, green: 0.80, blue: 0.86)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .buttonStyle(.plain)
                .overlay(alignment: .trailing) {
                    if index < labels.count - 1 {
                        Rectangle().fill(Color.black.opacity(0.22)).frame(width: 1)
                    }
                }
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color(red: 0.20, green: 0.27, blue: 0.38), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .shadow(color: .black.opacity(0.28), radius: 1, x: 0, y: 1)
    }
}

struct SafariLegacyNavigationBar<Leading: View, Trailing: View>: View {
    let title: String
    @ViewBuilder let leading: Leading
    @ViewBuilder let trailing: Trailing

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.92, green: 0.94, blue: 0.97), Color(red: 0.55, green: 0.63, blue: 0.73)],
                startPoint: .top,
                endPoint: .bottom
            )
            HStack {
                leading.frame(width: 86, alignment: .leading)
                Spacer()
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.65), radius: 0, x: 0, y: -1)
                    .shadow(color: .black.opacity(0.35), radius: 1, x: 0, y: 1)
                Spacer()
                trailing.frame(width: 86, alignment: .trailing)
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 44)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.black.opacity(0.45)).frame(height: 1) }
    }
}

struct SafariLegacyListRow<Label: View, Accessory: View>: View {
    let action: () -> Void
    @ViewBuilder let label: Label
    @ViewBuilder let accessory: Accessory

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                label
                Spacer(minLength: 8)
                accessory
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 54)
            .background(
                LinearGradient(
                    colors: [Color.white, Color(red: 0.91, green: 0.93, blue: 0.96)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(alignment: .bottom) { Rectangle().fill(Color.black.opacity(0.14)).frame(height: 1) }
        }
        .buttonStyle(.plain)
    }
}

struct SafariLegacyModalBackground<Content: View>: View {
    let title: String
    let onClose: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Color.black.opacity(0.42)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { onClose() }

                VStack(spacing: 0) {
                    SafariLegacyNavigationBar(
                        title: title,
                        leading: { EmptyView() },
                        trailing: {
                            SafariLegacyTextButton(title: "Done", compact: true, action: onClose)
                        }
                    )
                    content
                }
                .frame(maxWidth: .infinity)
                .frame(maxHeight: proxy.size.height * 0.92)
                .background(Color(red: 0.94, green: 0.95, blue: 0.97))
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.black.opacity(0.45), lineWidth: 1))
                .shadow(color: .black.opacity(0.55), radius: 12, x: 0, y: 5)
                .padding(.horizontal, 6)
                .padding(.bottom, 5)
            }
        }
    }
}
import SwiftUI
import UIKit

/// Full-screen OldOS/iOS 6 styled Pages view. Selection is performed directly
/// against SafariTabStore's selectedID, rather than relying on a navigation
/// stack selection state. This avoids the "same page is shown" bug when several
/// WKWebViews are alive at once.
struct SafariTabsView: View {
    @ObservedObject var store: SafariTabStore
    let onClose: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: store.isPrivateMode
                        ? [OldSafariPalette.tabsBackgroundTopPrivate, OldSafariPalette.tabsBackgroundBottomPrivate]
                        : [OldSafariPalette.tabsBackgroundTop, OldSafariPalette.tabsBackgroundBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    SafariLegacyNavigationBar(
                        title: store.isPrivateMode ? "Private Pages" : "Pages",
                        leading: {
                            SafariLegacyTextButton(
                                title: store.isPrivateMode ? "Regular" : "Private",
                                compact: true
                            ) {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                store.togglePrivateMode()
                            }
                        },
                        trailing: {
                            SafariLegacyTextButton(title: "Done", compact: true, action: onClose)
                        }
                    )

                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(store.visibleTabs) { tab in
                                SafariLegacyPageCard(
                                    tab: tab,
                                    isSelected: tab.id == store.selectedID,
                                    onSelect: {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        store.select(tab)
                                        onClose()
                                    },
                                    onClose: {
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        withAnimation(.easeInOut(duration: 0.16)) {
                                            store.close(tab)
                                        }
                                    }
                                )
                            }
                        }
                        .padding(10)

                        SafariLegacyTextButton(title: "New Page") {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            store.addTab()
                            onClose()
                        }
                        .padding(.bottom, max(14, geometry.safeAreaInsets.bottom + 8))
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
        .preferredColorScheme(store.isPrivateMode ? .dark : .light)
    }
}

private struct SafariLegacyPageCard: View {
    @ObservedObject var tab: SafariTab
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onSelect) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(tab.isPrivate ? Color.black : Color.white)
                            .frame(width: 7, height: 7)
                            .overlay(Circle().stroke(Color.black.opacity(0.25), lineWidth: 1))

                        Text(tab.title.isEmpty ? "Untitled" : tab.title)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(tab.isPrivate ? .white : Color(red: 0.05, green: 0.10, blue: 0.18))
                            .lineLimit(1)
                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 9)
                    .padding(.top, 8)

                    Text(tab.url?.host ?? "About Blank")
                        .font(.system(size: 10))
                        .foregroundColor(tab.isPrivate ? .white.opacity(0.75) : Color.black.opacity(0.55))
                        .lineLimit(1)
                        .padding(.horizontal, 9)
                        .padding(.top, 2)

                    Spacer(minLength: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(tab.isPrivate ? 0.10 : 0.72))
                        .overlay(
                            VStack(spacing: 3) {
                                Image(systemName: tab.url == nil ? "safari" : "globe")
                                    .font(.system(size: 22, weight: .regular))
                                Text(isSelected ? "Current Page" : "Tap to Select")
                                    .font(.system(size: 9, weight: .semibold))
                            }
                            .foregroundColor(tab.isPrivate ? .white.opacity(0.55) : Color.black.opacity(0.35))
                        )
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)
                        .frame(height: 72)
                }
                .frame(maxWidth: .infinity, minHeight: 136)
                .background(
                    LinearGradient(
                        colors: tab.isPrivate
                            ? [Color(red: 0.22, green: 0.22, blue: 0.25), Color(red: 0.08, green: 0.08, blue: 0.10)]
                            : [Color.white, Color(red: 0.79, green: 0.82, blue: 0.87)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color(red: 0.13, green: 0.34, blue: 0.66) : Color.black.opacity(0.45), lineWidth: isSelected ? 2 : 1)
                )
                .shadow(color: .black.opacity(0.42), radius: 2, x: 0, y: 2)
            }
            .buttonStyle(.plain)

            Button(action: onClose) {
                Image("closebox")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 23, height: 23)
                    .padding(4)
            }
            .buttonStyle(.plain)
        }
    }
}
