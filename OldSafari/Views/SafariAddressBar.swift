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

    @State private var progress: Double = 1
    @State private var showsPlate: Bool = false

    private var stopLocation: CGFloat {
        CGFloat(min(max(showsPlate ? progress : 1, 0), 1))
    }

    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 5)

            HStack(alignment: .center, spacing: 10) {
                ZStack(alignment: .leading) {
                    if text.isEmpty && !isEditing {
                        Text("Address")
                            .font(OldOSFont.regular(15))
                            .foregroundColor(theme.fieldPlaceholder)
                            .allowsHitTesting(false)
                    }

                    TextField("", text: $text, onEditingChanged: { changed in
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

                if !isEditing {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        if tab.isLoading { tab.stop() } else { tab.reload() }
                    } label: {
                        Image("AddressViewReload")
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
                RoundedRectangle(cornerRadius: 6)
                    .fill(LinearGradient(oldOS: theme.progressGradient))
                    .brightness(0.1)
                    .opacity(showsPlate ? 1 : 0)

                OldOSInnerShadow(
                    shape: RoundedRectangle(cornerRadius: 6),
                    fill: LinearGradient(
                        gradient: Gradient(stops: [
                            Gradient.Stop(color: .clear, location: stopLocation),
                            Gradient.Stop(color: theme.fieldPlain, location: stopLocation)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
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
                progress = 0
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
