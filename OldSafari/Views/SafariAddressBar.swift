import SwiftUI
import Combine

/// OldOS/iOS 6-inspired address field.  The loading treatment deliberately
/// stays restrained: a thin blue progress sweep along the lower edge of the
/// field, plus the original stop/reload control.  This avoids the modern
/// shimmer effect and keeps the chrome visually close to legacy Safari.
struct SafariAddressBar: View {
    @ObservedObject var tab: SafariTab
    let isPrivate: Bool
    var focusedField: FocusState<SafariSearchField?>.Binding

    @State private var text = ""

    private var focused: Bool { focusedField.wrappedValue == .address }
    private var progress: CGFloat { CGFloat(max(0, min(tab.estimatedProgress, 1))) }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: isPrivate
                    ? [OldSafariPalette.fieldTopPrivate, OldSafariPalette.fieldBottomPrivate]
                    : [OldSafariPalette.fieldTop, OldSafariPalette.fieldBottom],
                startPoint: .top, endPoint: .bottom
            )

            // Legacy Safari-style progress: no shimmer, no extra row.
            if tab.isLoading {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.black.opacity(isPrivate ? 0.38 : 0.16))
                            .frame(height: 2)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: isPrivate
                                        ? [Color(red: 0.18, green: 0.40, blue: 0.82),
                                           Color(red: 0.34, green: 0.60, blue: 1.00)]
                                        : [Color(red: 0.12, green: 0.38, blue: 0.86),
                                           Color(red: 0.34, green: 0.66, blue: 1.00)],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .frame(width: max(2, proxy.size.width * progress), height: 2)
                            .animation(.easeOut(duration: 0.16), value: progress)
                    }
                    .frame(maxHeight: .infinity, alignment: .bottom)
                }
                .allowsHitTesting(false)
            }

            HStack(spacing: 5) {
                if !focused, tab.isSecure {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(isPrivate ? .white.opacity(0.82) : .secondary)
                }

                TextField("Address", text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(isPrivate ? Color.white : Color.black)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .focused(focusedField, equals: .address)
                    .submitLabel(.go)
                    .multilineTextAlignment(focused ? .leading : .center)
                    .onSubmit(navigate)
                    .onAppear { syncFromWebView(force: true) }
                    .onReceive(tab.$url) { _ in
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
                        Group {
                            if tab.isLoading {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11, weight: .bold))
                            } else {
                                Image("AddressViewReload")
                                    .resizable()
                                    .scaledToFit()
                            }
                        }
                        .frame(width: 17, height: 17)
                        .foregroundStyle(isPrivate ? .white.opacity(0.86) : OldSafariPalette.placeholderText)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button { tab.toggleDesktopSite() } label: {
                            Label(
                                tab.isRequestingDesktopSite ? "Request Mobile Website" : "Request Desktop Website",
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
                    isPrivate ? OldSafariPalette.fieldBorderPrivate : OldSafariPalette.fieldBorder,
                    lineWidth: 0.8
                )
        }
        .shadow(color: .black.opacity(isPrivate ? 0.30 : 0.18), radius: 1, x: 0, y: 1)
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
        } else if !input.contains(" "), input.contains("."),
                  let url = URL(string: "https://\(input)") {
            tab.load(url)
        } else {
            let encoded = input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            if let url = URL(string: "https://www.google.com/search?q=\(encoded)") {
                tab.load(url)
            }
        }
        focusedField.wrappedValue = nil
    }
}
