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

    /// Long press history previews for the two navigation arrows.
    var backHistory: () -> [SafariNavigationItem] = { [] }
    var forwardHistory: () -> [SafariNavigationItem] = { [] }
    var onNavigateHistory: (SafariNavigationItem) -> Void = { _ in }

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
                        OldOSToolBarMenuButton(
                            image: "NavBack",
                            enabled: canGoBack,
                            items: backHistory,
                            onSelect: onNavigateHistory,
                            action: onBack
                        )

                        OldOSToolBarMenuButton(
                            image: "NavForward",
                            enabled: canGoForward,
                            items: forwardHistory,
                            onSelect: onNavigateHistory,
                            action: onForward
                        )
                        OldOSToolBarButton(image: "NavAction", action: onShare)
                        OldOSToolBarButton(image: "NavBookmarks", action: onBookmarks)
                        OldOSToolBarButton(image: tabImage, action: onTabs)
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
            .oldOSBorder(width: 1, edges: [.top], color: theme.barHairline)
        )
    }
}
