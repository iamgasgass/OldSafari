import SwiftUI

struct iOS6BookmarksView: View {
    @ObservedObject var state: SafariState
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab = 0 // 0 = Bookmarks, 1 = History
    
    var body: some View {
        VStack(spacing: 0) {
            // iOS 6 Header Bar with Done Button
            ZStack {
                LinearGradient(
                    gradient: state.isPrivateMode ? iOS6Theme.privateTopBarGradient : iOS6Theme.topBarGradient,
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                HStack {
                    Spacer()
                    Text(selectedTab == 0 ? "Bookmarks" : "History")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(state.isPrivateMode ? .white : .black)
                        .shadow(color: state.isPrivateMode ? .black : .white.opacity(0.5), radius: 0, x: 0, y: 1)
                    Spacer()
                    
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        ZStack {
                            LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: Color(red: 0.45, green: 0.55, blue: 0.70), location: 0.0),
                                    .init(color: Color(red: 0.25, green: 0.35, blue: 0.50), location: 0.5),
                                    .init(color: Color(red: 0.15, green: 0.25, blue: 0.40), location: 0.51),
                                    .init(color: Color(red: 0.20, green: 0.30, blue: 0.45), location: 1.0)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.black.opacity(0.6), lineWidth: 1)
                        }
                    )
                    .cornerRadius(4)
                }
                .padding(.horizontal, 8)
            }
            .frame(height: 44)
            
            // Retro Segmented Control
            Picker("", selection: $selectedTab) {
                Text("Bookmarks").tag(0)
                Text("History").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(8)
            .background(state.isPrivateMode ? Color(white: 0.12) : Color(white: 0.85))
            
            // Linen Texture Table List
            List {
                if selectedTab == 0 {
                    ForEach(state.bookmarks, id: \.self) { url in
                        Button(action: {
                            state.currentURLString = url.absoluteString
                            state.webView?.load(URLRequest(url: url))
                            dismiss()
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "book.fill")
                                    .foregroundColor(.blue)
                                Text(url.absoluteString)
                                    .font(.system(size: 14, weight: .medium))
                                    .lineLimit(1)
                                    .foregroundColor(state.isPrivateMode ? .white : .black)
                            }
                        }
                        .listRowBackground(state.isPrivateMode ? Color(white: 0.12) : Color.white)
                    }
                } else {
                    ForEach(state.history, id: \.self) { url in
                        Button(action: {
                            state.currentURLString = url.absoluteString
                            state.webView?.load(URLRequest(url: url))
                            dismiss()
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "clock")
                                    .foregroundColor(.gray)
                                Text(url.absoluteString)
                                    .font(.system(size: 14, weight: .medium))
                                    .lineLimit(1)
                                    .foregroundColor(state.isPrivateMode ? .white : .black)
                            }
                        }
                        .listRowBackground(state.isPrivateMode ? Color(white: 0.12) : Color.white)
                    }
                }
            }
            .listStyle(PlainListStyle())
            .background(state.isPrivateMode ? Color.black : Color(white: 0.92))
        }
    }
}
