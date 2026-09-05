import SwiftUI

struct iOS6BookmarksView: View {
    @ObservedObject var state: SafariState
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                LinearGradient(
                    gradient: state.isPrivateMode ? iOS6Theme.privateTopBarGradient : iOS6Theme.topBarGradient,
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                HStack {
                    Spacer()
                    Text(selectedTab == 0 ? "Segnalibri" : "Cronologia")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(state.isPrivateMode ? .white : .black)
                        .shadow(color: state.isPrivateMode ? .black : .white.opacity(0.5), radius: 0, x: 0, y: 1)
                    Spacer()
                    
                    Button("Fine") {
                        dismiss()
                    }
                    .font(.system(size: 13, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(LinearGradient(gradient: iOS6Theme.topBarGradient, startPoint: .top, endPoint: .bottom))
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black.opacity(0.5), lineWidth: 1))
                    )
                    .foregroundColor(.black)
                }
                .padding(.horizontal, 10)
            }
            .frame(height: 44)
            
            Picker("", selection: $selectedTab) {
                Text("Segnalibri").tag(0)
                Text("Cronologia").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(8)
            .background(state.isPrivateMode ? Color(white: 0.15) : Color(white: 0.85))
            
            List {
                if selectedTab == 0 {
                    ForEach(state.bookmarks, id: \.self) { url in
                        Button(action: {
                            state.currentURLString = url.absoluteString
                            state.webView?.load(URLRequest(url: url))
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "book.fill")
                                    .foregroundColor(.blue)
                                Text(url.absoluteString)
                                    .font(.system(size: 14))
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
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(.gray)
                                Text(url.absoluteString)
                                    .font(.system(size: 14))
                                    .lineLimit(1)
                                    .foregroundColor(state.isPrivateMode ? .white : .black)
                            }
                        }
                        .listRowBackground(state.isPrivateMode ? Color(white: 0.12) : Color.white)
                    }
                }
            }
            .listStyle(PlainListStyle())
            .background(state.isPrivateMode ? Color.black : Color(white: 0.9))
        }
    }
}
