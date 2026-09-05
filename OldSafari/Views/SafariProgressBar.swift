import SwiftUI

/// Glossy loading strip inspired by the original OldOS/iOS 4 Safari chrome.
/// The progress value remains WebKit's real estimatedProgress; the moving
/// highlight is purely visual and disappears with the strip when loading ends.
struct SafariProgressBar: View {
    let progress: Double
    let isLoading: Bool

    @State private var shimmer = false

    private var clampedProgress: CGFloat {
        CGFloat(max(0, min(progress, 1)))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.black.opacity(0.22))

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.10, green: 0.43, blue: 0.94),
                                Color(red: 0.25, green: 0.70, blue: 1.00),
                                Color(red: 0.06, green: 0.34, blue: 0.84)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: geometry.size.width * clampedProgress)
                    .animation(.easeInOut(duration: 0.18), value: clampedProgress)

                if isLoading && clampedProgress > 0.02 {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    .clear,
                                    Color.white.opacity(0.08),
                                    Color.white.opacity(0.72),
                                    Color.white.opacity(0.08),
                                    .clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(26, geometry.size.width * 0.16))
                        .offset(x: shimmer ? geometry.size.width : -geometry.size.width * 0.20)
                        .mask(
                            Rectangle()
                                .frame(width: geometry.size.width * clampedProgress)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        )
                        .animation(
                            .linear(duration: 0.85)
                                .repeatForever(autoreverses: false),
                            value: shimmer
                        )
                }
            }
            .clipShape(Rectangle())
            .onAppear {
                if isLoading {
                    shimmer = false
                    DispatchQueue.main.async {
                        shimmer = true
                    }
                }
            }
            .onChange(of: isLoading) { loading in
                if loading {
                    shimmer = false
                    DispatchQueue.main.async {
                        shimmer = true
                    }
                } else {
                    shimmer = false
                }
            }
        }
        .frame(height: isLoading ? 3 : 0)
        .opacity(isLoading ? 1 : 0)
        .animation(.easeInOut(duration: 0.16), value: isLoading)
        .accessibilityHidden(true)
    }
}
