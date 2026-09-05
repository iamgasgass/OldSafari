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

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: isPrivate
                    ? [OldSafariPalette.chromeTopPrivate, OldSafariPalette.chromeBottomPrivate]
                    : [OldSafariPalette.chromeTop, OldSafariPalette.chromeBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)

            HStack(spacing: 0) {
                legacyIconButton("NavBack", disabled: !tab.canGoBack) { tab.goBack() }
                legacyIconButton("NavForward", disabled: !tab.canGoForward) { tab.goForward() }
                legacyIconButton("NavAction", disabled: tab.url == nil, action: onShare)
                legacyIconButton("NavBookmarks", disabled: false, action: onLibrary)

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onTabs()
                } label: {
                    ZStack {
                        Image(tabIconName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 28, height: 28)
                        Text("\(tabCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.8), radius: 1)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: contentHeight)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .frame(height: contentHeight)
            .padding(.bottom, bottomInset)
        }
        .frame(height: contentHeight + bottomInset)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.black.opacity(0.65)).frame(height: 1)
        }
    }

    private var tabIconName: String {
        let clamped = min(max(tabCount, 1), 8)
        return clamped == 1 ? "NavTab" : "NavTab\(clamped)"
    }

    private func legacyIconButton(_ image: String, disabled: Bool, action: @escaping () -> Void) -> some View {
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
