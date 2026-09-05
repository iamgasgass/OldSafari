import SwiftUI

struct SafariAddressBar: View {
    @ObservedObject var tab: SafariTab
    let isPrivate: Bool

    @State private var urlText = ""
    @State private var searchText = ""
    @FocusState private var focusedField: Field?

    private enum Field { case url, search }

    var body: some View {
        HStack(spacing: 5) {
            addressField
            searchField
        }
        .padding(.horizontal, 6)
        .padding(.top, 4)
        .padding(.bottom, 5)
    }

    private var addressField: some View {
        HStack(spacing: 5) {
            if focusedField != .url, tab.isSecure {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isPrivate ? .white.opacity(0.8) : .secondary)
            }

            TextField("Address", text: $urlText)
                .textFieldStyle(.plain)
                .font(.system(size: 15.5, weight: .regular))
                .foregroundStyle(isPrivate ? .white : .primary)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .focused($focusedField, equals: .url)
                .submitLabel(.go)
                .multilineTextAlignment(focusedField == .url ? .leading : .center)
                .onSubmit(navigateURL)
                .onAppear(perform: sync)
                .onChange(of: tab.id) { _ in sync() }
                .onChange(of: tab.url) { _ in
                    if focusedField != .url { sync() }
                }

            if focusedField == .url && !urlText.isEmpty {
                Button { urlText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            } else if focusedField != .url {
                Button {
                    tab.isLoading ? tab.stop() : tab.reload()
                } label: {
                    Image(systemName: tab.isLoading ? "xmark" : "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isPrivate ? .white.opacity(0.85) : OldSafariPalette.placeholderText)
                        .frame(width: 19, height: 19)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button {
                        tab.toggleDesktopSite()
                    } label: {
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
        .frame(height: 34)
        .background(fieldBackground)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .stroke(
                    isPrivate
                        ? OldSafariPalette.fieldBorderPrivate
                        : OldSafariPalette.fieldBorder,
                    lineWidth: 0.8
                )
        }
        .overlay(alignment: .bottom) {
            loadingTint
                .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .frame(maxWidth: .infinity)
    }

    private var searchField: some View {
        HStack(spacing: 5) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isPrivate ? .white.opacity(0.72) : .secondary)

            TextField("Search", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 15.5))
                .foregroundStyle(isPrivate ? .white : .primary)
                .keyboardType(.webSearch)
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled(false)
                .focused($focusedField, equals: .search)
                .submitLabel(.search)
                .onSubmit(search)

            if focusedField == .search && !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 34)
        .background(fieldBackground)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .stroke(
                    isPrivate
                        ? OldSafariPalette.fieldBorderPrivate
                        : OldSafariPalette.fieldBorder,
                    lineWidth: 0.8
                )
        }
        .frame(width: 118)
    }

    private var loadingTint: some View {
        GeometryReader { proxy in
            Rectangle()
                .fill(OldSafariPalette.progressTint.opacity(tab.isLoading ? 0.85 : 0))
                .frame(
                    width: proxy.size.width * CGFloat(max(0, min(tab.estimatedProgress, 1))),
                    height: 2
                )
                .animation(.easeInOut(duration: 0.22), value: tab.estimatedProgress)
                .frame(maxHeight: .infinity, alignment: .bottomLeading)
        }
        .allowsHitTesting(false)
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

    private func sync() {
        urlText = tab.url?.absoluteString ?? ""
    }

    private func navigateURL() {
        let input = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else {
            focusedField = nil
            return
        }

        if let url = URL(string: input),
           let scheme = url.scheme,
           !scheme.isEmpty {
            tab.load(url)
            focusedField = nil
            return
        }

        if looksLikeDomain(input),
           let url = URL(string: "https://\(input)") {
            tab.load(url)
            focusedField = nil
            return
        }

        search(query: input)
    }

    private func search() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        search(query: query)
    }

    private func search(query: String) {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "https://www.google.com/search?q=\(encoded)") {
            tab.load(url)
        }
        searchText = ""
        focusedField = nil
    }

    private func looksLikeDomain(_ input: String) -> Bool {
        !input.contains(" ") && input.contains(".") && !input.hasPrefix(".")
    }
}
