import SwiftUI

struct SafariGoogleSearchBar: View {
    @ObservedObject var tab: SafariTab
    let isPrivate: Bool
    var focusedField: FocusState<SafariSearchField?>.Binding

    @State private var query = ""
    private var focused: Bool { focusedField.wrappedValue == .search }

    var body: some View {
        HStack(spacing: 6) {
            if !focused {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isPrivate ? .white.opacity(0.7) : OldSafariPalette.placeholderText)
            }
            TextField("Google", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(focused ? (isPrivate ? .white : .black) : (isPrivate ? .white.opacity(0.85) : OldSafariPalette.placeholderText))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .focused(focusedField, equals: .search)
                .submitLabel(.search)
                .multilineTextAlignment(focused ? .leading : .center)
                .onSubmit { search() }
            if focused && !query.isEmpty {
                Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(LinearGradient(colors: isPrivate ? [OldSafariPalette.fieldTopPrivate, OldSafariPalette.fieldBottomPrivate] : [OldSafariPalette.fieldTop, OldSafariPalette.fieldBottom], startPoint: .top, endPoint: .bottom))
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(isPrivate ? OldSafariPalette.fieldBorderPrivate : OldSafariPalette.fieldBorder, lineWidth: 0.8))
        .id("google-\(tab.id.uuidString)")
    }

    private func search() {
        let input = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { focusedField.wrappedValue = nil; return }
        let encoded = input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "https://www.google.com/search?q=\(encoded)") { tab.load(url) }
        focusedField.wrappedValue = nil
    }
}
