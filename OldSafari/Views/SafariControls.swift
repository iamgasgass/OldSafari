import SwiftUI
import UIKit

// MARK: - Toolbar icon button

/// OldOS `tool_bar_button`: the raw @2x artwork at its intrinsic size, evenly
/// distributed across the toolbar, dimmed to 25% when unavailable.
struct OldOSToolBarButton: View {
    let image: String
    var enabled: Bool = true
    var action: () -> Void

    var body: some View {
        HStack {
            Spacer(minLength: 0)
            Button {
                guard enabled else { return }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                action()
            } label: {
                Image(image)
            }
            .buttonStyle(.plain)
            .allowsHitTesting(enabled)
            Spacer(minLength: 0)
        }
        .opacity(enabled ? 1 : 0.25)
        .frame(maxWidth: .infinity)
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
