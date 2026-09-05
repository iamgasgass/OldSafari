import SwiftUI
import UIKit

/// Shared iOS 6/OldOS skeuomorphic controls.  These are intentionally
/// deterministic rather than using modern Material/Liquid-Glass controls.
struct SafariLegacyButtonStyle: ButtonStyle {
    var highlighted = false
    var destructive = false
    var compact = false
    var dark = false

    func makeBody(configuration: Configuration) -> some View {
        let top = dark ? Color(red: 0.28, green: 0.29, blue: 0.33) : (highlighted ? Color(red: 0.72, green: 0.80, blue: 0.91) : .white)
        let bottom = dark ? Color(red: 0.10, green: 0.10, blue: 0.13) : (highlighted ? .white : Color(red: 0.70, green: 0.76, blue: 0.84))
        configuration.label
            .font(.system(size: compact ? 13 : 15, weight: .bold))
            .foregroundStyle(destructive ? Color(red: 0.75, green: 0.06, blue: 0.06) : (dark ? .white : Color(red: 0.04, green: 0.14, blue: 0.34)))
            .padding(.horizontal, compact ? 9 : 13)
            .frame(minHeight: compact ? 30 : 36)
            .background(LinearGradient(colors: configuration.isPressed ? [bottom, top] : [top, bottom], startPoint: .top, endPoint: .bottom))
            .overlay(alignment: .top) { Rectangle().fill(Color.white.opacity(configuration.isPressed ? 0.16 : 0.72)).frame(height: 1) }
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(dark ? Color.white.opacity(0.30) : Color(red: 0.15, green: 0.21, blue: 0.30), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .shadow(color: .black.opacity(0.38), radius: 1, x: 0, y: 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
    }
}

struct SafariLegacyTextButton: View {
    let title: String
    var highlighted = false
    var destructive = false
    var compact = false
    var dark = false
    let action: () -> Void
    var body: some View {
        Button(action: action) { Text(title) }
            .buttonStyle(SafariLegacyButtonStyle(highlighted: highlighted, destructive: destructive, compact: compact, dark: dark))
    }
}

struct SafariLegacyIconButton: View {
    let image: String
    var title: String? = nil
    var disabled = false
    var destructive = false
    var dark = false
    let action: () -> Void
    var body: some View {
        Button { if !disabled { action() } } label: {
            HStack(spacing: 5) {
                Image(image).resizable().scaledToFit().frame(width: 22, height: 22)
                if let title { Text(title) }
            }
        }
        .buttonStyle(SafariLegacyButtonStyle(destructive: destructive, compact: true, dark: dark))
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
    }
}

struct SafariLegacySegmentedControl: View {
    @Binding var selection: Int
    let labels: [String]
    var dark = false

    var body: some View {
        HStack(spacing: 0) {
            ForEach(labels.indices, id: \.self) { index in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.easeOut(duration: 0.10)) { selection = index }
                } label: {
                    Text(labels[index])
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(selection == index ? .white : (dark ? .white.opacity(0.76) : Color(red: 0.05, green: 0.14, blue: 0.31)))
                        .frame(maxWidth: .infinity, minHeight: 30)
                        .background(
                            LinearGradient(
                                colors: selection == index
                                    ? (dark ? [Color(red: 0.30, green: 0.43, blue: 0.63), Color(red: 0.08, green: 0.16, blue: 0.28)] : [Color(red: 0.39, green: 0.56, blue: 0.78), Color(red: 0.10, green: 0.25, blue: 0.47)])
                                    : (dark ? [Color(red: 0.24, green: 0.25, blue: 0.29), Color(red: 0.10, green: 0.10, blue: 0.12)] : [.white, Color(red: 0.70, green: 0.76, blue: 0.84)]),
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .overlay(alignment: .top) { Rectangle().fill(Color.white.opacity(selection == index ? 0.28 : 0.55)).frame(height: 1) }
                }
                .buttonStyle(.plain)
                .overlay(alignment: .trailing) {
                    if index < labels.count - 1 { Rectangle().fill(Color.black.opacity(dark ? 0.65 : 0.28)).frame(width: 1) }
                }
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(dark ? Color.white.opacity(0.32) : Color(red: 0.15, green: 0.21, blue: 0.30), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .shadow(color: .black.opacity(0.30), radius: 1, x: 0, y: 1)
    }
}

struct SafariLegacyNavigationBar<Leading: View, Trailing: View>: View {
    let title: String
    @ViewBuilder let leading: Leading
    @ViewBuilder let trailing: Trailing
    var dark = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: dark
                    ? [Color(red: 0.30, green: 0.31, blue: 0.35), Color(red: 0.08, green: 0.08, blue: 0.11)]
                    : [Color(red: 0.88, green: 0.91, blue: 0.95), Color(red: 0.45, green: 0.53, blue: 0.64)],
                startPoint: .top, endPoint: .bottom
            )
            .overlay(alignment: .top) { Rectangle().fill(Color.white.opacity(0.55)).frame(height: 1) }

            HStack {
                leading.frame(width: 86, alignment: .leading)
                Spacer()
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.75), radius: 0, x: 0, y: -1)
                    .shadow(color: .black.opacity(0.30), radius: 1, x: 0, y: 1)
                Spacer()
                trailing.frame(width: 86, alignment: .trailing)
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 60)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.black.opacity(0.48)).frame(height: 1) }
    }
}

struct SafariLegacyListRow<Label: View, Accessory: View>: View {
    let action: () -> Void
    @ViewBuilder let label: Label
    @ViewBuilder let accessory: Accessory
    var dark = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                label; Spacer(minLength: 8); accessory
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 54)
            .background(LinearGradient(
                colors: dark ? [Color(red: 0.18, green: 0.18, blue: 0.21), Color(red: 0.08, green: 0.08, blue: 0.10)]
                            : [.white, Color(red: 0.91, green: 0.93, blue: 0.96)],
                startPoint: .top, endPoint: .bottom
            ))
            .overlay(alignment: .bottom) { Rectangle().fill(Color.black.opacity(dark ? 0.65 : 0.14)).frame(height: 1) }
        }
        .buttonStyle(.plain)
    }
}

struct SafariLegacyModalBackground<Content: View>: View {
    let title: String
    let onClose: () -> Void
    @ViewBuilder let content: Content
    var dark = false

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Color.black.opacity(0.46).ignoresSafeArea().contentShape(Rectangle()).onTapGesture { onClose() }
                VStack(spacing: 0) {
                    SafariLegacyNavigationBar(title: title, leading: { EmptyView() },
                                               trailing: { SafariLegacyTextButton(title: "Done", compact: true, dark: dark, action: onClose) },
                                               dark: dark)
                    content
                }
                .frame(maxWidth: .infinity)
                .frame(maxHeight: proxy.size.height * 0.92)
                .background(dark ? Color(red: 0.075, green: 0.075, blue: 0.09) : Color(red: 0.94, green: 0.95, blue: 0.97))
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.black.opacity(0.45), lineWidth: 1))
                .shadow(color: .black.opacity(0.55), radius: 12, x: 0, y: 5)
                .padding(.horizontal, 6).padding(.bottom, 5)
            }
        }
    }
}

struct SafariTabsView: View {
    @ObservedObject var store: SafariTabStore
    let onClose: () -> Void

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: store.isPrivateMode
                        ? [OldSafariPalette.tabsBackgroundTopPrivate, OldSafariPalette.tabsBackgroundBottomPrivate]
                        : [OldSafariPalette.tabsBackgroundTop, OldSafariPalette.tabsBackgroundBottom],
                    startPoint: .top, endPoint: .bottom
                ).ignoresSafeArea()

                VStack(spacing: 0) {
                    SafariLegacyNavigationBar(
                        title: store.isPrivateMode ? "Private Pages" : "Pages",
                        leading: {
                            SafariLegacyTextButton(title: store.isPrivateMode ? "Regular" : "Private", compact: true, dark: store.isPrivateMode) {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                store.togglePrivateMode()
                            }
                        },
                        trailing: { SafariLegacyTextButton(title: "Done", compact: true, dark: store.isPrivateMode, action: onClose) },
                        dark: store.isPrivateMode
                    )

                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(store.visibleTabs) { tab in
                                SafariLegacyPageCard(tab: tab, isSelected: tab.id == store.selectedID,
                                    onSelect: {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        store.select(id: tab.id); onClose()
                                    },
                                    onClose: {
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        withAnimation(.easeInOut(duration: 0.16)) { store.close(tab) }
                                    })
                            }
                        }
                        .padding(10)

                        SafariLegacyTextButton(title: "New Page", compact: false, dark: store.isPrivateMode) {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            store.addTab(); onClose()
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
                        Circle().fill(tab.isPrivate ? Color.white.opacity(0.25) : .white).frame(width: 7, height: 7)
                            .overlay(Circle().stroke(Color.black.opacity(0.25), lineWidth: 1))
                        Text(tab.title.isEmpty ? "Untitled" : tab.title)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(tab.isPrivate ? .white : Color(red: 0.05, green: 0.10, blue: 0.18))
                            .lineLimit(1)
                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 9).padding(.top, 8)

                    Text(tab.url?.host ?? "About Blank")
                        .font(.system(size: 10))
                        .foregroundStyle(tab.isPrivate ? .white.opacity(0.72) : Color.black.opacity(0.55))
                        .lineLimit(1)
                        .padding(.horizontal, 9).padding(.top, 2)

                    Spacer(minLength: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(tab.isPrivate ? 0.10 : 0.72))
                        .overlay(
                            VStack(spacing: 3) {
                                Image(systemName: tab.url == nil ? "safari" : "globe").font(.system(size: 22))
                                Text(isSelected ? "Current Page" : "Tap to Select").font(.system(size: 9, weight: .semibold))
                            }
                            .foregroundStyle(tab.isPrivate ? .white.opacity(0.55) : Color.black.opacity(0.35))
                        )
                        .padding(.horizontal, 8).padding(.bottom, 8).frame(height: 72)
                }
                .frame(maxWidth: .infinity, minHeight: 136)
                .background(LinearGradient(
                    colors: tab.isPrivate
                        ? [Color(red: 0.22, green: 0.22, blue: 0.25), Color(red: 0.08, green: 0.08, blue: 0.10)]
                        : [.white, Color(red: 0.79, green: 0.82, blue: 0.87)],
                    startPoint: .top, endPoint: .bottom
                ))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color(red: 0.13, green: 0.34, blue: 0.66) : Color.black.opacity(0.45),
                            lineWidth: isSelected ? 2 : 1))
                .shadow(color: .black.opacity(0.42), radius: 2, x: 0, y: 2)
            }
            .buttonStyle(.plain)

            Button(action: onClose) {
                Image("closebox").resizable().scaledToFit().frame(width: 23, height: 23).padding(4)
            }
            .buttonStyle(.plain)
        }
    }
}
