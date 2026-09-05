import SwiftUI
import UIKit

/// OldOS `google_search_bar`: the capsule search field that shares the title
/// bar with the address field, 1/3 of the width when idle.
struct SafariGoogleSearchBar: View {
    let theme: OldOSSafariTheme

    @Binding var text: String
    @Binding var isEditing: Bool

    var onSubmit: (String) -> Void

    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 5)

            HStack(alignment: .center, spacing: 10) {
                ZStack(alignment: .leading) {
                    if text.isEmpty {
                        Text("Google")
                            .font(OldOSFont.regular(15))
                            .foregroundColor(theme.fieldPlaceholder)
                            .allowsHitTesting(false)
                    }

                    TextField("", text: $text, onEditingChanged: { changed in
                        withAnimation(.linear(duration: 0.22)) { isEditing = changed }
                    })
                    .font(OldOSFont.regular(15))
                    .foregroundColor(isEditing ? theme.fieldTextActive : theme.fieldTextIdle)
                    .keyboardType(.webSearch)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
                    .onSubmit {
                        onSubmit(text)
                        text = ""
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
            }
            .padding([.top, .bottom], 5)
            .padding(.leading, 5)

            Spacer(minLength: 8)
        }
        .oldOSInnerShadowBackground(
            Capsule(),
            theme.fieldFill,
            radius: 1.8,
            offset: CGPoint(x: 0, y: 1),
            intensity: 0.6
        )
        .oldOSStrokeCapsule(theme.fieldStroke, lineWidth: 0.65)
        .padding(.leading, 1)
        .padding(.trailing, 2.5)
    }
}
