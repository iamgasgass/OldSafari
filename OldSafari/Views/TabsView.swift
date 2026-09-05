import SwiftUI

public struct TabsView: View {
    @Binding var tabs: [TabItem]
    @Binding var activeTabId: UUID
    @Binding var isPrivate: Bool
    var onNewTab: () -> Void
    var onClose: () -> Void

    public var body: some View {
        VStack(spacing: 0) {
            // Header with Private Browsing button & Done button
            HStack {
                Button(action: {
                    withAnimation { isPrivate.toggle() }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isPrivate ? "lock.fill" : "lock")
                        Text("Navigazione privata")
                    }
                }
                .buttonStyle(iOS6ButtonStyle(isPrivate: isPrivate, isBlue: isPrivate))
                
                Spacer()
                
                Button("Fine") {
                    onClose()
                }
                .buttonStyle(iOS6ButtonStyle(isPrivate: isPrivate, isBlue: true))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isPrivate ? iOS6Theme.navBarGradientPrivate : iOS6Theme.navBarGradientNormal)

            // Grid of stacked page tabs (iOS 6 Style)
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(tabs) { tab in
                        ZStack(alignment: .topTrailing) {
                            VStack(spacing: 4) {
                                // Thumbnail frame
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(isPrivate ? Color(red: 0.2, green: 0.2, blue: 0.22) : Color.white)
                                        .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 2)
                                    
                                    if let img = tab.snapshot {
                                        Image(uiImage: img)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(height: 140)
                                            .clipped()
                                            .cornerRadius(4)
                                    } else {
                                        VStack {
                                            Image(systemName: "globe")
                                                .font(.largeTitle)
                                                .foregroundColor(.gray)
                                            Text(tab.title)
                                                .font(.caption)
                                                .foregroundColor(isPrivate ? .white : .black)
                                                .lineLimit(2)
                                        }
                                        .padding()
                                    }
                                }
                                .frame(height: 140)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(tab.id == activeTabId ? Color.blue : Color.black.opacity(0.4), lineWidth: tab.id == activeTabId ? 3 : 1)
                                )
                                
                                Text(tab.title)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(isPrivate ? .white : .black)
                                    .lineLimit(1)
                            }
                            .onTapGesture {
                                activeTabId = tab.id
                                onClose()
                            }
                            
                            // Close Tab Button (Red badge with X in iOS 6 style)
                            if tabs.count > 1 {
                                Button(action: {
                                    closeTab(tab.id)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(.red)
                                        .background(Circle().fill(Color.white))
                                }
                                .offset(x: 6, y: -6)
                            }
                        }
                        .padding(6)
                    }
                }
                .padding(16)
            }
            .ios6LinenBackground(isPrivate: isPrivate)

            // Bottom Bar with "+" New Tab button
            HStack {
                Spacer()
                Button(action: onNewTab) {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(isPrivate ? .white : .black)
                }
                .buttonStyle(iOS6ButtonStyle(isPrivate: isPrivate))
                Spacer()
            }
            .padding(.vertical, 8)
            .background(isPrivate ? iOS6Theme.toolbarGradientPrivate : iOS6Theme.toolbarGradientNormal)
        }
    }

    private func closeTab(_ id: UUID) {
        if let idx = tabs.firstIndex(where: { $0.id == id }) {
            tabs.remove(at: idx)
            if activeTabId == id {
                activeTabId = tabs.first?.id ?? UUID()
            }
        }
    }
}
