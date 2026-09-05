import SwiftUI
import UIKit

enum SafariSearchField: Hashable {
    case address
    case search
}

/// OldOS `safari_title_bar`: page title on top, address field + Google capsule
/// below, and a Cancel button that slides in from the trailing edge while
/// either field is being edited.
struct SafariSearchRow: View {
    @ObservedObject var tab: SafariTab
    let theme: OldOSSafariTheme

    @Binding var editingField: SafariSearchField?
    @Binding var urlText: String
    @Binding var googleText: String

    var onNavigate: (String) -> Void
    var onSearch: (String) -> Void

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
            ZStack {
                LinearGradient(oldOS: theme.barGradient)
                    .oldOSBorder(width: 1, edges: [.bottom], color: theme.barHairline)
                    .oldOSInnerShadowBottom(color: theme.barHighlight, radius: 0.025)

                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    Text(tab.title.isEmpty ? "Untitled" : tab.title)
                        .foregroundColor(theme.pageTitle)
                        .font(OldOSFont.bold(14))
                        .shadow(color: theme.pageTitleShadow, radius: 0, x: 0, y: theme.pageTitleShadowY)
                        .lineLimit(1)
                        .padding([.leading, .trailing], 24)

                    HStack(spacing: 0) {
                        if !isEditingSearch {
                            SafariAddressBar(
                                tab: tab,
                                theme: theme,
                                text: $urlText,
                                isEditing: addressEditingBinding,
                                onSubmit: onNavigate
                            )
                            .frame(width: isEditingAddress ? geometry.size.width - 76 : geometry.size.width * 2 / 3 - 15)
                        }

                        if !isEditingAddress {
                            SafariGoogleSearchBar(
                                theme: theme,
                                text: $googleText,
                                isEditing: searchEditingBinding,
                                onSubmit: onSearch
                            )
                            .frame(width: isEditingSearch ? geometry.size.width - 76 : geometry.size.width * 1 / 3)
                        }

                        if isEditing {
                            Spacer().frame(width: 69)
                        }
                    }
                    .frame(height: 32)

                    Spacer(minLength: 0)
                }
            }
        }
        .frame(height: 60)
        .overlay(alignment: .bottomTrailing) {
            if isEditing {
                Button {
                    withAnimation(.linear(duration: 0.22)) { editingField = nil }
                    oldOSHideKeyboard()
                } label: {
                    Text("Cancel")
                        .font(OldOSFont.bold(13.25))
                        .foregroundColor(.white)
                        .shadow(color: Color.black.opacity(0.75), radius: 1, x: 0, y: -0.25)
                        .frame(width: 59, height: 32)
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
                .padding(.trailing, 12)
                .padding(.bottom, 8)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
    }
}
