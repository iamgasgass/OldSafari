import SwiftUI
import Combine

struct SafariAddressBar: View {
    @ObservedObject var tab: SafariTab
    let isPrivate: Bool
    var focusedField: FocusState<SafariSearchField?>.Binding

    @State private var text = ""

    private var focused: Bool { focusedField.wrappedValue == .address }

    var body: some View {
        HStack(spacing: 6) {
            if !focused, tab.isSecure {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isPrivate ? .white.opacity(0.8) : .secondary)
            }

            TextField("Address", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(fieldTextColor)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .focused(focusedField, equals: .address)
                .submitLabel(.go)
                .multilineTextAlignment(focused ? .leading : .center)
                .onSubmit { navigate() }
                .onAppear { syncFromWebView(force: true) }
                .onReceive(tab.$url.receive(on: DispatchQueue.main)) { _ in
                    if !focused { syncFromWebView(force: true) }
                }
                .onChange(of: focusedField.wrappedValue) { newValue in
                    if newValue != .address { syncFromWebView(force: true) }
                }

            if focused && !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            } else if !focused {
                Button {
                    if tab.isLoading { tab.stop() } else { tab.reload() }
                } label: {
                    if tab.isLoading {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(isPrivate ? .white.opacity(0.85) : OldSafariPalette.placeholderText)
                            .frame(width: 17, height: 17)
                    } else {
                        Image("AddressViewReload")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 17, height: 17)
                    }
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button { tab.toggleDesktopSite() } label: {
                        Label(tab.isRequestingDesktopSite ? "Request Mobile Website" : "Request Desktop Website", systemImage: "display")
                    }
                    Button { tab.findOnPage() } label: {
                        Label("Find on Page", systemImage: "magnifyingglass")
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(fieldBackground)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(isPrivate ? OldSafariPalette.fieldBorderPrivate : OldSafariPalette.fieldBorder, lineWidth: 0.8))
        .id("address-\(tab.id.uuidString)")
    }

    private var fieldBackground: LinearGradient {
        LinearGradient(colors: isPrivate ? [OldSafariPalette.fieldTopPrivate, OldSafariPalette.fieldBottomPrivate] : [OldSafariPalette.fieldTop, OldSafariPalette.fieldBottom], startPoint: .top, endPoint: .bottom)
    }

    private var fieldTextColor: Color {
        focused ? (isPrivate ? .white : .black) : (isPrivate ? .white.opacity(0.85) : OldSafariPalette.placeholderText)
    }

    private func syncFromWebView(force: Bool = false) {
        guard force || !focused else { return }
        text = tab.url?.absoluteString ?? ""
    }

    private func navigate() {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { focusedField.wrappedValue = nil; return }

        if let url = URL(string: input), let scheme = url.scheme, !scheme.isEmpty {
            tab.load(url)
        } else if looksLikeDomain(input), let url = URL(string: "https://\(input)") {
            tab.load(url)
        } else {
            let encoded = input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            if let searchURL = URL(string: "https://www.google.com/search?q=\(encoded)") { tab.load(searchURL) }
        }
        focusedField.wrappedValue = nil
    }

    private func looksLikeDomain(_ input: String) -> Bool {
        !input.contains(" ") && input.contains(".") && !input.hasPrefix(".")
    }
}
