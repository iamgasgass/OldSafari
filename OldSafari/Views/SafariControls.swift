import SwiftUI
import UIKit

// MARK: - Toolbar icon button

/// OldOS `tool_bar_button`: the raw @2x artwork at its intrinsic size, evenly
/// distributed across the toolbar, dimmed to 25% when unavailable.
struct OldOSToolBarButton: View {
    let image: String
    var enabled: Bool = true
    var action: () -> Void
    /// Optional long press, used by the two arrows for the tab history and by
    /// the pages button for "Close All Pages".
    var onLongPress: (() -> Void)? = nil

    @State private var didLongPress = false

    var body: some View {
        HStack {
            Spacer(minLength: 0)
            Button {
                // The long press already handled this touch.
                if didLongPress {
                    didLongPress = false
                    return
                }
                guard enabled else { return }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                action()
            } label: {
                Image(image)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.38)
                    .onEnded { _ in
                        guard enabled, let onLongPress else { return }
                        didLongPress = true
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onLongPress()
                    }
            )
            .allowsHitTesting(enabled)
            Spacer(minLength: 0)
        }
        .opacity(enabled ? 1 : 0.25)
        .frame(maxWidth: .infinity)
    }
}

/// A long press on one of the toolbar arrows asks for this: the tab's
/// back/forward list, drawn with the same 2012 sheet metal as the rest of the
/// app instead of a stock UIKit menu.
struct SafariHistoryRequest: Identifiable {
    let id = UUID()
    let title: String
    let items: [SafariNavigationItem]
    /// Horizontal position, 0…1, of the button that opened the panel.
    let anchor: CGFloat
}

struct SafariHistoryPreviewPanel: View {
    let theme: OldOSSafariTheme
    let request: SafariHistoryRequest
    /// Distance from the bottom of the screen to the top of the toolbar.
    var liftFromBottom: CGFloat = 0
    let onSelect: (SafariNavigationItem) -> Void
    let onDismiss: () -> Void

    private let rowHeight: CGFloat = 44
    private let headerHeight: CGFloat = 30

    var body: some View {
        GeometryReader { geometry in
            let width = min(geometry.size.width - 24, 420)
            let available = geometry.size.height - liftFromBottom - 90
            let wanted = headerHeight + CGFloat(max(request.items.count, 1)) * rowHeight
            let height = max(min(wanted, available), headerHeight + rowHeight)
            let anchorX = min(
                max(request.anchor * geometry.size.width, 24),
                geometry.size.width - 24
            )
            let left = min(
                max(anchorX - width / 2, 12),
                max(geometry.size.width - width - 12, 12)
            )

            ZStack(alignment: .topLeading) {
                theme.scrim.opacity(0.4)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { onDismiss() }

                VStack(spacing: 0) {
                    panelBody(height: height)

                    OldOSPanelPointer()
                        .fill(LinearGradient(oldOS: theme.shareBody))
                        .frame(width: 20, height: 9)
                        .offset(x: anchorX - left - 10)
                        .frame(width: width, alignment: .leading)
                }
                .frame(width: width)
                .offset(
                    x: left,
                    y: geometry.size.height - liftFromBottom - height - 9 - 4
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .ignoresSafeArea()
    }

    private func panelBody(height: CGFloat) -> some View {
        VStack(spacing: 0) {
            ZStack {
                Rectangle()
                    .fill(LinearGradient(oldOS: theme.shareStrip))
                    .oldOSInnerShadowBottom(color: Color.white.opacity(0.98), radius: 0.1)

                Text(request.title)
                    .font(OldOSFont.bold(13.25))
                    .foregroundColor(theme.shareButtonText)
                    .shadow(
                        color: theme.shareButtonTextShadow,
                        radius: 0,
                        x: 0,
                        y: theme.shareButtonTextShadowY
                    )
            }
            .frame(height: headerHeight)

            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 0) {
                    ForEach(Array(request.items.enumerated()), id: \.element.id) { index, entry in
                        row(entry, isLast: index == request.items.count - 1)
                    }
                }
            }
        }
        .background(LinearGradient(oldOS: theme.shareBody))
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .oldOSAddBorder(
            LinearGradient(oldOS: theme.shareButtonOuterStroke),
            width: 0.5,
            cornerRadius: 12
        )
        .shadow(color: Color.black.opacity(0.5), radius: 14, x: 0, y: 5)
    }

    private func row(_ entry: SafariNavigationItem, isLast: Bool) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onSelect(entry)
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "clock")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.5))

                    VStack(alignment: .leading, spacing: 1) {
                        Text(entry.title)
                            .font(OldOSFont.bold(15))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        if !entry.host.isEmpty {
                            Text(entry.host)
                                .font(OldOSFont.regular(11))
                                .foregroundColor(Color.white.opacity(0.45))
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.35))
                }
                .padding([.leading, .trailing], 14)
                .frame(height: rowHeight - 1)

                Rectangle()
                    .fill(Color.white.opacity(isLast ? 0 : 0.09))
                    .frame(height: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Little triangle under the history panel, pointing at the arrow that opened it.
struct OldOSPanelPointer: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// The empty separator grid an iOS 6 plain UITableView drew under its last
/// row, so short lists never end in a blank sheet of white.
struct OldOSTableFiller: View {
    let theme: OldOSSafariTheme
    var rowHeight: CGFloat = 44
    var separator: CGFloat = 0.95

    var body: some View {
        GeometryReader { geometry in
            let rows = max(Int(ceil(geometry.size.height / rowHeight)) + 1, 1)

            VStack(spacing: 0) {
                ForEach(0..<rows, id: \.self) { _ in
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(theme.listBackground)
                            .frame(height: rowHeight - separator)
                        Rectangle()
                            .fill(theme.listSeparator)
                            .frame(height: separator)
                    }
                }
            }
            .frame(height: geometry.size.height, alignment: .top)
            .clipped()
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Rectangle (pill) button

/// OldOS `tool_bar_rectangle_button`: 32pt tall, 5.5pt radius, recessed bevel,
/// Helvetica Neue Bold 13.25 with a hard dark shadow above the glyphs.
struct OldOSRectangleButton: View {
    let title: String
    var type: OldOSButtonType = .gray
    var heightModifier: CGFloat = 0
    var action: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Text(title)
                .font(OldOSFont.bold(13.25))
                .foregroundColor(.white)
                .shadow(color: Color.black.opacity(0.75), radius: 1, x: 0, y: -0.25)
                .lineLimit(1)
                .fixedSize()
                .padding([.leading, .trailing], 11)
                .frame(height: 32 + heightModifier)
                .oldOSInnerShadowBackground(
                    RoundedRectangle(cornerRadius: 5.5),
                    oldOSButtonGradient(type),
                    radius: 0.8,
                    offset: CGPoint(x: 0, y: 0.6),
                    intensity: 0.7
                )
                .shadow(color: Color.white.opacity(0.28), radius: 0, x: 0, y: 0.8)
        }
        .buttonStyle(.plain)
        .frame(height: 32 + heightModifier)
    }
}

// MARK: - Title bars

struct OldOSBarButton {
    let title: String
    let type: OldOSButtonType
    let action: () -> Void

    init(_ title: String, type: OldOSButtonType, action: @escaping () -> Void) {
        self.title = title
        self.type = type
        self.action = action
    }
}

/// OldOS `generic_title_bar` and its Cancel/Save + Clear/Cancel variants, all
/// folded into one 60pt bar so the geometry can never drift between screens.
struct OldOSTitleBar: View {
    let title: String
    let theme: OldOSSafariTheme
    var leading: OldOSBarButton?
    var trailing: OldOSBarButton?

    var body: some View {
        ZStack {
            LinearGradient(oldOS: theme.barGradient)
                .oldOSBorder(width: 1, edges: [.bottom], color: theme.barHairline)
                .oldOSInnerShadowBottom(color: theme.barHighlight, radius: 0.025)

            Text(title)
                .font(OldOSFont.bold(22))
                .foregroundColor(theme.titleBarTitle)
                .shadow(color: theme.titleBarTitleShadow, radius: 0, x: 0, y: -1)
                .lineLimit(1)
                .padding([.leading, .trailing], 74)

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
        }
        .frame(height: 60)
    }
}

// MARK: - Table rows

/// OldOS bookmark/history row: 44pt tall, 0.95pt hairline, 25pt icon slot,
/// Helvetica Neue Bold 18 label and the `UITableNext` chevron artwork.
struct OldOSTableRow<Accessory: View>: View {
    let icon: String?
    let title: String
    var detail: String?
    let theme: OldOSSafariTheme
    var showsChevron: Bool = true
    var action: () -> Void
    @ViewBuilder var accessory: Accessory

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center, spacing: 0) {
                    Spacer().frame(width: 1, height: 44 - 0.95)

                    accessory

                    if let icon {
                        Image(icon).frame(width: 25, height: 44 - 0.95)
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        Text(title)
                            .font(OldOSFont.bold(18))
                            .foregroundColor(theme.listRowText)
                            .lineLimit(1)
                        if let detail, !detail.isEmpty {
                            Text(detail)
                                .font(OldOSFont.regular(11))
                                .foregroundColor(theme.listRowDetail)
                                .lineLimit(1)
                        }
                    }
                    .padding(.leading, 6)
                    .padding(.trailing, 12)

                    Spacer(minLength: 0)

                    if showsChevron {
                        Image("UITableNext").padding(.trailing, 12)
                    }
                }
                .padding(.leading, 15)
                .frame(height: 44 - 0.95)

                Rectangle()
                    .fill(theme.listSeparator)
                    .frame(height: 0.95)
            }
            .frame(height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

extension OldOSTableRow where Accessory == EmptyView {
    init(
        icon: String?,
        title: String,
        detail: String? = nil,
        theme: OldOSSafariTheme,
        showsChevron: Bool = true,
        action: @escaping () -> Void
    ) {
        self.init(
            icon: icon,
            title: title,
            detail: detail,
            theme: theme,
            showsChevron: showsChevron,
            action: action,
            accessory: { EmptyView() }
        )
    }
}

/// OldOS edit-mode delete affordance: the `UIRemoveControlMinus` artwork with a
/// hand-drawn em dash that rotates a quarter turn once armed.
struct OldOSRemoveControl: View {
    let armed: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Image("UIRemoveControlMinus")
                Text("—")
                    .foregroundColor(.white)
                    .font(.system(size: 15, weight: .heavy, design: .default))
                    .offset(y: armed ? -0.8 : -2)
                    .rotationEffect(.degrees(armed ? -90 : 0), anchor: .center)
                    .offset(y: armed ? -0.5 : 0)
            }
        }
        .buttonStyle(.plain)
        .offset(x: -2)
    }
}

/// The grouped white card used by Add Bookmark, matching
/// `list_section_content_only` (10pt radius, 1.25pt border, 50pt rows).
struct OldOSGroupedCard<Content: View>: View {
    let theme: OldOSSafariTheme
    let rowCount: Int
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(theme.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(theme.cardStroke, lineWidth: 1.25)
                )
            VStack(spacing: 0) { content }
        }
        .frame(height: CGFloat(rowCount) * 50)
        .padding([.leading, .trailing], 12)
    }
}
