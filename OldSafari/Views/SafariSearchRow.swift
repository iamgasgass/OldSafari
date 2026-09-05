import SwiftUI
import UIKit

/// Which of the two title-bar fields is currently being edited. Mirrors
/// the mutually-exclusive editing_state_url / editing_state_google pair
/// from the original OldOS Safari implementation.
enum SafariSearchField: Hashable {
    case address
    case search
}

/// Reconstructs the classic OldOS Safari title bar: a compact address
/// field alongside a dedicated Google search field, side by side. Tapping
/// either field expands it to fill the row and reveals a Cancel button,
/// exactly like stock Safari on iOS 4 — the piece that was missing from
/// the single-field bar this app previously shipped with.
struct SafariSearchRow: View {
    @ObservedObject var tab: SafariTab
    let isPrivate: Bool

    @FocusState private var focusedField: SafariSearchField?

    private let cancelWidth: CGFloat = 56

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 6) {
                if focusedField != .search {
                    SafariAddressBar(
                        tab: tab,
                        isPrivate: isPrivate,
                        focusedField: $focusedField
                    )
                    .frame(width: addressWidth(in: geometry.size.width))
                }

                if focusedField != .address {
                    SafariGoogleSearchBar(
                        tab: tab,
                        isPrivate: isPrivate,
                        focusedField: $focusedField
                    )
                    .frame(width: searchWidth(in: geometry.size.width))
                }

                if focusedField != nil {
                    Button("Cancel") {
                        focusedField = nil
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil
                        )
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isPrivate ? .white : Color(red: 0.06, green: 0.14, blue: 0.35))
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 6)
            .frame(height: geometry.size.height)
            .animation(.easeInOut(duration: 0.2), value: focusedField)
        }
        .frame(height: 34)
        .padding(.top, 4)
    }

    private func addressWidth(in totalWidth: CGFloat) -> CGFloat {
        let usable = totalWidth - 12
        switch focusedField {
        case .address: return max(usable - cancelWidth - 6, 0)
        case .search: return 0
        case nil: return usable * 0.62 - 3
        }
    }

    private func searchWidth(in totalWidth: CGFloat) -> CGFloat {
        let usable = totalWidth - 12
        switch focusedField {
        case .search: return max(usable - cancelWidth - 6, 0)
        case .address: return 0
        case nil: return usable * 0.38 - 3
        }
    }
}
