import SwiftUI

struct iOS6AddressBar: View {
    @ObservedObject var state: SafariState
    @FocusState private var isFocused: Bool
    
    var body: some View {
        ZStack {
            // Skeuomorphic Navigation Header Gradient
            LinearGradient(
                gradient: state.isPrivateMode ? iOS6Theme.privateTopBarGradient : iOS6Theme.topBarGradient,
                startPoint: .top,
                endPoint: .bottom
            )
            .overlay(
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(iOS6Theme.topHighlight)
                        .frame(height: 1)
                    Spacer()
                    Rectangle()
                        .fill(state.isPrivateMode ? iOS6Theme.privateBottomBorder : iOS6Theme.bottomBorder)
                        .frame(height: 1)
                }
            )
            
            HStack(spacing: 6) {
                // Main Glossy Address Bar Container
                ZStack(alignment: .leading) {
                    // Beveled Inset Field Background
                    RoundedRectangle(cornerRadius: 5)
                        .fill(state.isPrivateMode ? Color(white: 0.12) : Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.black.opacity(0.6), Color.black.opacity(0.2)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: .black.opacity(0.25), radius: 1, x: 0, y: 1)
                    
                    // iOS 6 Glossy Blue Pill Loading Bar
                    if state.isLoading {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        LinearGradient(
                                            gradient: state.isPrivateMode ? iOS6Theme.privateProgressBarGradient : iOS6Theme.progressBarGradient,
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(width: max(12, geo.size.width * CGFloat(state.estimatedProgress)))
                                    .overlay(
                                        // Gloss reflection stripe
                                        VStack {
                                            Rectangle()
                                                .fill(Color.white.opacity(0.35))
                                                .frame(height: geo.size.height * 0.45)
                                            Spacer()
                                        }
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                    )
                                    .animation(.easeInOut(duration: 0.25), value: state.estimatedProgress)
                            }
                        }
                        .padding(1)
                    }
                    
                    // Text Input & Buttons
                    HStack(spacing: 4) {
                        Image(systemName: state.isPrivateMode ? "lock.fill" : "magnifyingglass")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(state.isPrivateMode ? .gray : Color(white: 0.4))
                            .padding(.leading, 6)
                        
                        TextField("Search or enter address", text: $state.currentURLString)
                            .font(.system(size: 13, weight: .regular, design: .default))
                            .foregroundColor(state.isPrivateMode ? .white : .black)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .focused($isFocused)
                            .onSubmit {
                                loadURL()
                            }
                        
                        // Skeuomorphic Stop / Refresh Icon
                        if state.isLoading {
                            Button(action: { state.webView?.stopLoading() }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.gray)
                            }
                            .padding(.trailing, 6)
                        } else {
                            Button(action: { state.webView?.reload() }) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(state.isPrivateMode ? Color.white.opacity(0.8) : Color(white: 0.3))
                            }
                            .padding(.trailing, 6)
                        }
                    }
                }
                .frame(height: 29)
                
                // Dedicated Google Search Box (Authentic iOS 6 Separate Field)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(state.isPrivateMode ? Color(white: 0.12) : Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.black.opacity(0.4), lineWidth: 1)
                        )
                    
                    HStack {
                        Text("Google")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(Color.gray.opacity(0.8))
                            .padding(.leading, 8)
                        Spacer()
                    }
                }
                .frame(width: 80, height: 29)
                .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1)
            }
            .padding(.horizontal, 6)
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
