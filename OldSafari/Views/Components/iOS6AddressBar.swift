import SwiftUI

struct iOS6AddressBar: View {
    @ObservedObject var state: SafariState
    @FocusState private var isFocused: Bool
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: state.isPrivateMode ? iOS6Theme.privateTopBarGradient : iOS6Theme.topBarGradient,
                startPoint: .top,
                endPoint: .bottom
            )
            .overlay(
                VStack {
                    Rectangle()
                        .fill(iOS6Theme.topHighlight)
                        .frame(height: 1)
                    Spacer()
                    Rectangle()
                        .fill(state.isPrivateMode ? iOS6Theme.privateBottomBorder : iOS6Theme.bottomBorder)
                        .frame(height: 1)
                }
            )
            
            HStack(spacing: 8) {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(state.isPrivateMode ? Color(white: 0.15) : Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.black.opacity(0.4), lineWidth: 1)
                        )
                    
                    if state.isLoading {
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        gradient: state.isPrivateMode ? iOS6Theme.privateProgressBarGradient : iOS6Theme.progressBarGradient,
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: geo.size.width * CGFloat(state.estimatedProgress))
                                .animation(.easeInOut(duration: 0.2), value: state.estimatedProgress)
                        }
                        .padding(1)
                    }
                    
                    HStack {
                        Image(systemName: state.isPrivateMode ? "lock.fill" : "magnifyingglass")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                            .padding(.leading, 6)
                        
                        TextField("Cerca o inserisci un indirizzo", text: $state.currentURLString)
                            .font(.system(size: 14, weight: .medium, design: .default))
                            .foregroundColor(state.isPrivateMode ? .white : .black)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .focused($isFocused)
                            .onSubmit {
                                loadURL()
                            }
                        
                        if state.isLoading {
                            Button(action: { state.webView?.stopLoading() }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                            .padding(.trailing, 6)
                        } else {
                            Button(action: { state.webView?.reload() }) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.gray)
                            }
                            .padding(.trailing, 6)
                        }
                    }
                }
                .frame(height: 28)
                .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1)
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 44)
    }
    
    private func loadURL() {
        var urlString = state.currentURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            if urlString.contains(".") && !urlString.contains(" ") {
                urlString = "https://" + urlString
            } else {
                urlString = "https://www.google.com/search?q=\(urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
            }
        }
        if let url = URL(string: urlString) {
            state.webView?.load(URLRequest(url: url))
        }
    }
}
