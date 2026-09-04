import SwiftUI
import UIKit

struct SafariToolbar: View {
    @ObservedObject var tab: SafariTab
    let isPrivate: Bool
    let tabCount: Int

    let onTabs: () -> Void
    let onLibrary: () -> Void
    let onShare: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            toolbarButton("NavBack", disabled: !tab.canGoBack) {
                tab.goBack()
            }
            toolbarButton("NavForward", disabled: !tab.canGoForward) {
                tab.goForward()
            }
            toolbarButton("NavAction", disabled: false, action: onShare)
            toolbarButton("NavBookmarks", disabled: false, action: onLibrary)

            Button(action: onTabs) {
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
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
        .padding(.bottom, 6)
        .background(toolbarBackground)
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

    /// The tab-count icon has 8 frames named "NavTab", "NavTab2" … "NavTab8"
    /// (the first frame, for a single tab, has no numeric suffix).
    private var tabIconName: String {
        let clamped = min(max(tabCount, 1), 8)
        return clamped == 1 ? "NavTab" : "NavTab\(clamped)"
    }

    private func toolbarButton(_ image: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            if !disabled {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            action()
        } label: {
            Image(image)
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
                .opacity(disabled ? 0.35 : 1)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}
