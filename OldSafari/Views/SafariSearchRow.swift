import SwiftUI
import UIKit

enum SafariSearchField: Hashable {
    case address
    case search
}

/// OldOS `safari_title_bar`: page title on top, address field + Google capsule
/// below, and a Cancel button that slides in from the trailing edge while
/// either field is being edited.
///
/// The widths are computed from the live width instead of the 320pt iPhone 4
/// grid OldOS was drawn against, so the two fields stretch across the whole
/// display on modern devices while keeping the original proportions.
struct SafariSearchRow: View {
    @ObservedObject var tab: SafariTab
    let theme: OldOSSafariTheme

    @Binding var editingField: SafariSearchField?
    @Binding var urlText: String
    @Binding var googleText: String

    var onNavigate: (String) -> Void
    var onSearch: (String) -> Void
    /// Reader Mode toggle. Nil-safe so screens that reuse the row without
    /// wiring Reader can keep their existing call sites unchanged.
    var onToggleReader: (() -> Void)? = nil

    /// Outer margin of the field row.  Small enough to look edge to edge, wide
    /// enough to clear the rounded display corners of recent iPhones.
    private let sideMargin: CGFloat = 8
    private let gap: CGFloat = 6
    private let cancelWidth: CGFloat = 59
    private let fieldHeight: CGFloat = 32

    private var isEditingAddress: Bool { editingField == .address }
    private var isEditingSearch: Bool { editingField == .search }
    private var isEditing: Bool { editingField != nil }

    private var addressEditingBinding: Binding<Bool> {
        Binding(
            get: { editingField == .address },
            set: { editing in
                if editing { editingField = .address } else if editingField == .address { editingField = nil }
            }
        )
    }

    private var searchEditingBinding: Binding<Bool> {
        Binding(
            get: { editingField == .search },
            set: { editing in
                if editing { editingField = .search } else if editingField == .search { editingField = nil }
            }
        )
    }

    var body: some View {
        GeometryReader { geometry in
            let available = max(geometry.size.width - sideMargin * 2, 200)
            let editingWidth = available - cancelWidth - gap

            ZStack {
                LinearGradient(oldOS: theme.barGradient)
                    .oldOSBorder(width: 1, edges: [.bottom], color: theme.barHairline)
                    .oldOSInnerShadowBottom(color: theme.barHighlight, radius: 0.025)

                VStack(spacing: 6) {
                    Spacer(minLength: 0)

                    titleRow

                    HStack(spacing: gap) {
                        if !isEditingSearch {
                            SafariAddressBar(
                                tab: tab,
                                theme: theme,
                                text: $urlText,
                                isEditing: addressEditingBinding,
                                onSubmit: onNavigate
                            )
                            .frame(
                                width: isEditingAddress
                                    ? editingWidth
                                    : (available - gap) * 0.665
                            )
                        }

                        if !isEditingAddress {
                            SafariGoogleSearchBar(
                                theme: theme,
                                text: $googleText,
                                isEditing: searchEditingBinding,
                                onSubmit: onSearch
                            )
                            .frame(
                                width: isEditingSearch
                                    ? editingWidth
                                    : (available - gap) * 0.335
                            )
                        }

                        if isEditing {
                            cancelButton
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .frame(height: fieldHeight)
                    .padding([.leading, .trailing], sideMargin)

                    Spacer(minLength: 0)
                }
                .padding(.bottom, 5)
            }
        }
        .frame(height: 68)
    }

    /// Page title + Reader glyph. The glyph is present only while Reader is
    /// actually useful (an article-like page is loaded), matching how the
    /// current Safari lights up its Reader indicator.
    private var titleRow: some View {
        HStack(spacing: 6) {
            Text(tab.title.isEmpty ? "Untitled" : tab.title)
                .foregroundColor(theme.pageTitle)
                .font(OldOSFont.bold(14))
                .shadow(color: theme.pageTitleShadow, radius: 0, x: 0, y: theme.pageTitleShadowY)
                .lineLimit(1)

            if tab.readerAvailable, let onToggleReader {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onToggleReader()
                } label: {
                    Text(tab.isReaderActive ? "Aa\u{2022}" : "Aa")
                        .font(OldOSFont.bold(10))
                        .foregroundColor(theme.pageTitle)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(theme.pageTitle.opacity(0.55), lineWidth: 0.75)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding([.leading, .trailing], 24)
    }

    private var cancelButton: some View {
        Button {
            withAnimation(.linear(duration: 0.22)) { editingField = nil }
            oldOSHideKeyboard()
        } label: {
            Text("Cancel")
                .font(OldOSFont.bold(13.25))
                .foregroundColor(.white)
                .shadow(color: Color.black.opacity(0.75), radius: 1, x: 0, y: -0.25)
                .frame(width: cancelWidth, height: fieldHeight)
                .oldOSInnerShadowBackground(
                    RoundedRectangle(cornerRadius: 5.5),
                    oldOSButtonGradient(theme.neutralButton),
                    radius: 0.8,
                    offset: CGPoint(x: 0, y: 0.6),
                    intensity: 0.7
                )
                .shadow(color: Color.white.opacity(0.28), radius: 0, x: 0, y: 0.8)
        }
        .buttonStyle(.plain)
    }
}
