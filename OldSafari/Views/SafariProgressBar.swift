import SwiftUI

/// Retained as a compatibility component for projects that referenced the
/// old standalone progress strip. SafariRootView no longer places it below
/// the address/search row: loading progress now lives inside SafariAddressBar
/// to match the classic Safari chrome.
struct SafariProgressBar: View {
    let progress: Double
    let isLoading: Bool

    var body: some View {
        EmptyView()
    }
}
