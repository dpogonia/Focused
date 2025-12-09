import SwiftUI

// MARK: - Unified Search Bar View
struct SearchBarView: View {
    @Binding var searchText: String
    @Binding var isVisible: Bool
    let placeholder: String
    let onSearchSubmit: (() -> Void)?
    
    private let hapticManager = HapticSoundManager.shared
    
    init(
        searchText: Binding<String>,
        isVisible: Binding<Bool>,
        placeholder: String = "Search...",
        onSearchSubmit: (() -> Void)? = nil
    ) {
        self._searchText = searchText
        self._isVisible = isVisible
        self.placeholder = placeholder
        self.onSearchSubmit = onSearchSubmit
    }
    
    var body: some View {
        if isVisible {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.caption)
                
                TextField(placeholder, text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                    .onSubmit {
                        hapticManager.selectionChanged()
                        onSearchSubmit?()
                    }
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        hapticManager.selectionChanged()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(UIColor.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .frame(width: 200)
            .transition(.move(edge: .trailing).combined(with: .opacity))
        }
    }
}

// MARK: - Search Bar Toggle Button
struct SearchBarToggleButton: View {
    @Binding var isVisible: Bool
    @Binding var searchText: String
    let hapticManager = HapticSoundManager.shared
    
    var body: some View {
        Button {
            hapticManager.selectionChanged()
            withAnimation(.easeInOut(duration: 0.3)) {
                isVisible.toggle()
            }
            if !isVisible {
                searchText = ""
            }
        } label: {
            Label(isVisible ? "Hide Search" : "Search", systemImage: "magnifyingglass")
        }
    }
}