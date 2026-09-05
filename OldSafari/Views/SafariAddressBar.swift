import SwiftUI
import Combine

/// iOS 6 / OldOS-style address field.
///
/// The loading indicator is deliberately part of the address field itself:
/// WebKit progress grows from the left edge to the right edge of the same
/// rounded chrome, rather than occupying a separate row below it.
struct SafariAddressBar: View {
    @ObservedObject var tab: SafariTab
    let isPrivate: Bool
    var focusedField: FocusState<SafariSearchField?>.Binding

    @State private var text = ""
    @State private var shimmer = false

    private var focused: Bool { focusedField.wrappedValue == .address }

    private var progress: CGFloat {
        CGFloat(max(0, min(tab.estimatedProgress, 1)))
    }

    var body: some View {
        ZStack(alignment: .leading) {
            fieldBackground

            // The real WebKit progress fills the complete address field.
            // It is clipped by the same rounded shape as the field, so the
            // animation never appears underneath or outside the URL bar.
            if tab.isLoading {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: isPrivate
                                        ? [
                                            Color(red: 0.10, green: 0.30, blue: 0.62),
                                            Color(red: 0.18, green: 0.48, blue: 0.86),
                                            Color(red: 0.08, green: 0.27, blue: 0.58)
                                          ]
                                        : [
                                            Color(red: 0.08, green: 0.38, blue: 0.88),
                                            Color(red: 0.28, green: 0.68, blue: 1.00),
                                            Color(red: 0.05, green: 0.31, blue: 0.80)
                                          ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: geometry.size.width * progress)
                            .animation(.linear(duration: 0.12), value: progress)

                        if progress > 0.01 {
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            .clear,
                                            .white.opacity(0.12),
                                            .white.opacity(0.62),
                                            .white.opacity(0.12),
                                            .clear
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(28, geometry.size.width * 0.18))
                                .offset(
                                    x: shimmer
                                        ? geometry.size.width * progress
                                        : -geometry.size.width * 0.18
                                )
                                .animation(
                                    .linear(duration: 0.75)
                                        .repeatForever(autoreverses: false),
                                    value: shimmer
                                )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                }
                .allowsHitTesting(false)
            }

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
                    .onAppear {
                        syncFromWebView(force: true)
                        updateShimmer(tab.isLoading)
                    }
                    .onReceive(tab.$url) { _ in
                        if !focused { syncFromWebView(force: true) }
                    }
                    .onReceive(tab.$isLoading) { loading in
                        updateShimmer(loading)
                    }
                    .onChange(of: focusedField.wrappedValue) { newValue in
                        if newValue != .address {
                            syncFromWebView(force: true)
                        }
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
                                .foregroundColor(
                                    isPrivate
                                        ? .white.opacity(0.85)
                                        : OldSafariPalette.placeholderText
                                )
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
                            Label(
                                tab.isRequestingDesktopSite
                                    ? "Request Mobile Website"
                                    : "Request Desktop Website",
                                systemImage: "display"
                            )
                        }
                        Button { tab.findOnPage() } label: {
                            Label("Find on Page", systemImage: "magnifyingglass")
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .stroke(
                    tab.isLoading
                        ? (isPrivate
                            ? Color.white.opacity(0.72)
                            : Color(red: 0.12, green: 0.42, blue: 0.90).opacity(0.82))
                        : (isPrivate
                            ? OldSafariPalette.fieldBorderPrivate
                            : OldSafariPalette.fieldBorder),
                    lineWidth: tab.isLoading ? 1.0 : 0.8
                )
        }
        .id("address-\\(tab.id.uuidString)")
    }

    private var fieldBackground: some View {
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
        return isPrivate ? .white.opacity(0.90) : OldSafariPalette.placeholderText
    }

    private func updateShimmer(_ loading: Bool) {
        if loading {
            shimmer = false
            DispatchQueue.main.async {
                shimmer = true
            }
        } else {
            shimmer = false
        }
    }

    private func syncFromWebView(force: Bool = false) {
        guard force || !focused else { return }
        text = tab.url?.absoluteString ?? ""
    }

    private func navigate() {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else {
            focusedField.wrappedValue = nil
            return
        }

        if let url = URL(string: input), let scheme = url.scheme, !scheme.isEmpty {
            tab.load(url)
        } else if looksLikeDomain(input), let url = URL(string: "https://\\(input)") {
            tab.load(url)
        } else {
            let encoded = input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            if let searchURL = URL(string: "https://www.google.com/search?q=\\(encoded)") {
                tab.load(searchURL)
            }
        }

        focusedField.wrappedValue = nil
    }

    private func looksLikeDomain(_ input: String) -> Bool {
        !input.contains(" ") && input.contains(".") && !input.hasPrefix(".")
    }
}
