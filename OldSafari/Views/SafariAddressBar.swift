import Combine
import SwiftUI
import UIKit

/// OldOS `url_search_bar`.
///
/// The loading treatment is the important part: iOS 6 painted a glossy blue
/// plate behind the address field and covered it with the field's own fill,
/// then slid the covering edge to the right as `estimatedProgress` advanced.
/// That is reproduced exactly with a two-stop hard-step gradient whose stop
/// location *is* the progress value.
struct SafariAddressBar: View {
    @ObservedObject var tab: SafariTab
    let theme: OldOSSafariTheme

    @Binding var text: String
    @Binding var isEditing: Bool

    var onSubmit: (String) -> Void

    @State private var progress: Double = 0
    @State private var showsPlate: Bool = false

    private var clampedProgress: CGFloat {
        CGFloat(min(max(progress, 0), 1))
    }

    /// While the field is idle WebKit is the single source of truth, so the
    /// address always reflects the page that is actually on screen (redirects,
    /// in page navigation, back/forward, swipe gestures).  As soon as editing
    /// starts the local buffer takes over.
    private var liveURL: String { tab.url?.absoluteString ?? "" }

    private var displayed: Binding<String> {
        Binding(
            get: { isEditing ? text : liveURL },
            set: { text = $0 }
        )
    }

    private var isEmptyField: Bool {
        isEditing ? text.isEmpty : liveURL.isEmpty
    }

    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 5)

            HStack(alignment: .center, spacing: 10) {
                ZStack(alignment: .leading) {
                    if isEmptyField && !isEditing {
                        Text("Address")
                            .font(OldOSFont.regular(15))
                            .foregroundColor(theme.fieldPlaceholder)
                            .allowsHitTesting(false)
                    }

                    TextField("", text: displayed, onEditingChanged: { changed in
                        if changed { text = liveURL }
                        withAnimation(.linear(duration: 0.22)) { isEditing = changed }
                    })
                    .font(OldOSFont.regular(15))
                    .foregroundColor(isEditing ? theme.fieldTextActive : theme.fieldTextIdle)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .disableAutocorrection(true)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.go)
                    .onSubmit {
                        onSubmit(text)
                        withAnimation(.linear(duration: 0.22)) { isEditing = false }
                        oldOSHideKeyboard()
                    }
                }

                if isEditing, !text.isEmpty {
                    Button {
                        text = ""
                    } label: {
                        Image("UITextFieldClearButton")
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                }

                if !isEditing, tab.isSecure {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(theme.fieldTextIdle)
                }

                if !isEditing {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        if tab.isLoading { tab.stop() } else { tab.reload() }
                    } label: {
                        if tab.isLoading {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(theme.fieldTextIdle)
                                .frame(width: 20, height: 20)
                        } else {
                            Image("AddressViewReload")
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding([.top, .bottom], 5)
            .padding(.leading, 5)

            Spacer(minLength: 8)
        }
        .background(
            ZStack {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(theme.fieldFill)

                        if showsPlate {
                            LinearGradient(oldOS: theme.progressGradient)
                                .brightness(0.1)
                                .frame(width: geometry.size.width * clampedProgress)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                OldOSInnerShadow(
                    shape: RoundedRectangle(cornerRadius: 6),
                    fill: Color.clear,
                    radius: 1.8,
                    offset: CGPoint(x: 0, y: 1),
                    intensity: 0.5
                )
            }
        )
        .oldOSStrokeRoundedRectangle(6, theme.fieldStroke, lineWidth: 0.65)
        .padding(.leading, 2.5)
        .padding(.trailing, 1)
        .onReceive(tab.$estimatedProgress) { value in
            guard showsPlate else { return }
            withAnimation(.linear(duration: 0.2)) { progress = value }
        }
        .onReceive(tab.$isLoading) { loading in
            if loading {
                progress = 0.06
                withAnimation(.linear(duration: 0.18)) { showsPlate = true }
            } else {
                withAnimation(.linear(duration: 0.22)) { progress = 1 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
                    withAnimation(.linear(duration: 0.2)) { showsPlate = false }
                }
            }
        }
    }
}
