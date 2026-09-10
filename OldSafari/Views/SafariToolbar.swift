import SwiftUI
import UIKit

enum SafariToolbarMode {
    case browsing
    case tabs
    case bookmarks
    /// Free-form pair of rectangle buttons, used by History and any other
    /// screen that reuses the toolbar geometry.
    case pair(leading: OldOSBarButton?, trailing: OldOSBarButton?)
}

/// OldOS `tool_bar`: 45pt tall, 1pt hairline on top, and three completely
/// different button sets depending on what the browser is doing.
struct SafariToolbar: View {
    let theme: OldOSSafariTheme

    var canGoBack: Bool = false
    var canGoForward: Bool = false

    var mode: SafariToolbarMode = .browsing
    var tabCount: Int = 1
    var isPrivate: Bool = false
    var isEditingBookmarks: Bool = false
    var canCreateTab: Bool = true
    var bottomInset: CGFloat = 0
    /// Extra breathing room so the 45pt button row never sits on top of the
    /// home indicator / gesture area of recent iPhones.
    var lift: CGFloat = 6

    /// If non-zero, a red badge is stamped on the share glyph so the user
    /// knows there are downloads in flight — the modern-Safari cue in iOS 6
    /// clothing.
    var downloadCount: Int = 0

    var onBack: () -> Void = {}
    var onForward: () -> Void = {}
    var onShare: () -> Void = {}
    var onBookmarks: () -> Void = {}
    var onTabs: () -> Void = {}
    var onNewPage: () -> Void = {}
    var onDone: () -> Void = {}
    var onToggleEditing: () -> Void = {}
    var onNewFolder: () -> Void = {}
    var onTogglePrivate: () -> Void = {}

    /// Long presses: tab history on the two arrows, page actions on the
    /// pages button.
    var onBackHistory: (() -> Void)? = nil
    var onForwardHistory: (() -> Void)? = nil
    var onTabsLongPress: (() -> Void)? = nil

    /// Long-pressing the share button opens the Downloads sheet directly,
    /// so users do not have to walk through the share list every time.
    var onDownloadsTap: (() -> Void)? = nil

    private var tabImage: String {
        let clamped = min(max(tabCount, 1), 8)
        return clamped == 1 ? "NavTab" : "NavTab\(clamped)"
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                switch mode {
                case .browsing:
                    HStack(spacing: 0) {
                        OldOSToolBarButton(
                            image: "NavBack",
                            enabled: canGoBack,
                            action: onBack,
                            onLongPress: onBackHistory
                        )

                        OldOSToolBarButton(
                            image: "NavForward",
                            enabled: canGoForward,
                            action: onForward,
                            onLongPress: onForwardHistory
                        )

                        OldOSToolBarButton(
                            image: "NavAction",
                            action: onShare,
                            onLongPress: onDownloadsTap
                        )
                        .overlay(alignment: .topTrailing) {
                            if downloadCount > 0 {
                                DownloadBadge(count: downloadCount)
                                    // FIX (round 2): l'offset precedente (y:15)
                                    // si sovrapponeva ancora leggermente al
                                    // glifo. Spinto ulteriormente più in basso
                                    // e verso l'esterno perché il badge resti
                                    // ancorato solo all'angolo del pulsante,
                                    // senza toccare l'icona sottostante.
                                    .offset(x: -4, y: 20)
                                    .allowsHitTesting(false)
                            }
                        }

                        OldOSToolBarButton(image: "NavBookmarks", action: onBookmarks)
                        OldOSToolBarButton(
                            image: tabImage,
                            action: onTabs,
                            onLongPress: onTabsLongPress
                        )
                    }
                    .padding([.leading, .trailing], 6)
                    .transition(.opacity)

                case .tabs:
                    HStack(spacing: 0) {
                        OldOSRectangleButton(
                            title: "New Page",
                            type: canCreateTab ? theme.secondaryButton : theme.neutralButton,
                            action: onNewPage
                        )
                        .opacity(canCreateTab ? 1 : 0.5)
                        .allowsHitTesting(canCreateTab)
                        .padding(.leading, 5)

                        Spacer(minLength: 0)

                        OldOSRectangleButton(
                            title: "Private",
                            type: isPrivate ? .blue : theme.secondaryButton,
                            action: onTogglePrivate
                        )

                        Spacer(minLength: 0)

                        OldOSRectangleButton(title: "Done", type: .blue, action: onDone)
                            .padding(.trailing, 5)
                    }
                    .transition(.opacity)

                case .bookmarks:
                    HStack(spacing: 0) {
                        OldOSRectangleButton(
                            title: isEditingBookmarks ? "Done" : " Edit ",
                            type: isEditingBookmarks ? .blue : theme.secondaryButton,
                            action: onToggleEditing
                        )
                        .padding(.leading, 5)

                        Spacer(minLength: 0)

                        if isEditingBookmarks {
                            OldOSRectangleButton(title: "New Folder", type: theme.secondaryButton, action: onNewFolder)
                                .padding(.trailing, 5)
                        }
                    }
                    .transition(.opacity)

                case let .pair(leading, trailing):
                    HStack(spacing: 0) {
                        if let leading {
                            OldOSRectangleButton(title: leading.title, type: leading.type, action: leading.action)
                                .padding(.leading, 5)
                        }

                        Spacer(minLength: 0)
                        if let trailing {
                            OldOSRectangleButton(title: trailing.title, type: trailing.type, action: trailing.action)
                                .padding(.trailing, 5)
                        }
                    }
                    .transition(.opacity)
                }
            }
            .frame(height: 45)

            Color.clear.frame(height: bottomInset + lift)
        }
        .background(
            VStack(spacing: 0) {
                LinearGradient(oldOS: theme.toolbarGradient).frame(height: 45)
                (theme.toolbarGradient.last?.color ?? Color.black)
                    .frame(height: bottomInset + lift)
            }
        )
        .oldOSBorder(width: 1, edges: [.top], color: theme.barHairline)
    }
}

/// The small red pill badge iOS uses on tab bar icons, redrawn with iOS 6
/// glossy highlight so it lives comfortably on the OldOS toolbar chrome.
private struct DownloadBadge: View {
    let count: Int

    var body: some View {
        let label = count > 9 ? "9+" : String(count)
        ZStack {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 1.00, green: 0.35, blue: 0.32),
                            Color(red: 0.80, green: 0.10, blue: 0.10)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.9), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.4), radius: 1, x: 0, y: 1)

            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.5), radius: 0, x: 0, y: -0.5)
        }
        .frame(minWidth: 16, minHeight: 16)
        .padding(.horizontal, 3)
    }
}
