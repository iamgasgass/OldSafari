import SwiftUI
import UIKit

struct SafariToolbar: View {
    @ObservedObject var tab: SafariTab
    let isPrivate: Bool
    let tabCount: Int
    let bottomInset: CGFloat

    let onTabs: () -> Void
    let onLibrary: () -> Void
    let onShare: () -> Void

    private let contentHeight: CGFloat = 48
    private let extraGestureClearance: CGFloat = 8

    var body: some View {
        ZStack(alignment: .bottom) {
            toolbarBackground
                .ignoresSafeArea(edges: .bottom)

            HStack(spacing: 0) {
                toolbarButton("NavBack", disabled: !tab.canGoBack) {
                    tab.goBack()
                }
                toolbarButton("NavForward", disabled: !tab.canGoForward) {
                    tab.goForward()
                }
                toolbarButton("NavAction", disabled: false, action: onShare)
                toolbarButton("NavBookmarks", disabled: false, action: onLibrary)

                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onTabs()
                }) {
                    ZStack {
                        Image(tabIconName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 28, height: 28)

                        Text("\(tabCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(radius: 1)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: contentHeight)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .frame(height: contentHeight)
            .padding(.bottom, bottomInset + extraGestureClearance)
        }
        .frame(height: contentHeight + bottomInset + extraGestureClearance)
        .background(toolbarBackground.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(OldSafariPalette.hairline)
                .frame(height: 1)
        }
    }

    private var toolbarBackground: LinearGradient {
        LinearGradient(
            colors: isPrivate
                ? [OldSafariPalette.chromeTopPrivate, OldSafariPalette.chromeBottomPrivate]
                : [OldSafariPalette.chromeTop, OldSafariPalette.chromeBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var tabIconName: String {
        let clamped = min(max(tabCount, 1), 8)
        return clamped == 1 ? "NavTab" : "NavTab\(clamped)"
    }

    private func toolbarButton(
        _ image: String,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            guard !disabled else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Image(image)
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
                .opacity(disabled ? 0.35 : 1)
                .frame(maxWidth: .infinity)
                .frame(height: contentHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}
