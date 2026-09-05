import SwiftUI

/// The thin blue strip classic Safari shows creeping across while a
/// page loads. Fades out once loading completes instead of just
/// disappearing, so it never feels like a glitch.
struct SafariProgressBar: View {
    let progress: Double
    let isLoading: Bool

    var body: some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(OldSafariPalette.progressTint)
                .frame(width: geometry.size.width * CGFloat(max(0, min(progress, 1))))
                .animation(.easeInOut(duration: 0.25), value: progress)
        }
        .frame(height: isLoading ? 2 : 0)
        .opacity(isLoading ? 1 : 0)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }
}
