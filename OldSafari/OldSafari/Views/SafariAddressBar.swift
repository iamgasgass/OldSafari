import SwiftUI

struct SafariAddressBar: View {
    @ObservedObject var tab: SafariTab
    let isPrivate: Bool

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 6) {
            if !focused, tab.isSecure {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isPrivate ? .white.opacity(0.8) : .secondary)
            }

            TextField("Address or Search", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 16, weight: .regular, design: .default))
                .foregroundColor(fieldTextColor)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .focused($focused)
                .submitLabel(.go)
                .multilineTextAlignment(focused ? .leading : .center)
                .onSubmit { navigate() }
                .onAppear { syncFromWebView() }
                .onChange(of: focused) { isFocused in
                    if !isFocused { syncFromWebView() }
                }
                .onChange(of: tab.id) { _ in syncFromWebView() }
                .onChange(of: tab.url) { _ in
                    if !focused { syncFromWebView() }
                }

            if focused && !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            } else if !focused {
                Button {
                    if tab.isLoading {
                        tab.stop()
                    } else {
                        tab.reload()
                    }
                } label: {
                    if tab.isLoading {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(isPrivate ? .white.opacity(0.85) : OldSafariPalette.placeholderText)
                            .frame(width: 19, height: 19)
                    } else {
                        Image("AddressViewReload")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 19, height: 19)
                    }
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button {
                        tab.toggleDesktopSite()
                    } label: {
                        Label(
                            tab.isRequestingDesktopSite ? "Request Mobile Website" : "Request Desktop Website",
                            systemImage: "display"
                        )
                    }
                    Button {
                        tab.findOnPage()
                    } label: {
                        Label("Find on Page", systemImage: "magnifyingglass")
                    }
                }
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(fieldBackground)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(isPrivate ? OldSafariPalette.fieldBorderPrivate : OldSafariPalette.fieldBorder, lineWidth: 0.8)
        )
        .padding(.horizontal, 6)
        .padding(.top, 4)
    }

    private var fieldBackground: LinearGradient {
        LinearGradient(
            colors: isPrivate
                ? [OldSafariPalette.fieldTopPrivate, OldSafariPalette.fieldBottomPrivate]
                : [OldSafariPalette.fieldTop, OldSafariPalette.fieldBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var fieldTextColor: Color {
        if focused {
            return isPrivate ? .white : .black
        }
        return isPrivate ? .white.opacity(0.85) : OldSafariPalette.placeholderText
    }

    private func syncFromWebView() {
        text = tab.url?.absoluteString ?? ""
    }

    private func navigate() {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else {
            focused = false
            return
        }

        // Direct URL with an explicit scheme.
        if let url = URL(string: input), let scheme = url.scheme, !scheme.isEmpty {
            tab.load(url)
            focused = false
            return
        }

        // Looks like a bare domain ("example.com").
        if looksLikeDomain(input), let url = URL(string: "https://\(input)") {
            tab.load(url)
            focused = false
            return
        }

        // Fallback to a web search.
        let encoded = input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let searchURL = URL(string: "https://www.google.com/search?q=\(encoded)") {
            tab.load(searchURL)
        }
        focused = false
    }

    private func looksLikeDomain(_ input: String) -> Bool {
        guard !input.contains(" ") else { return false }
        return input.contains(".") && !input.hasPrefix(".")
    }
}
