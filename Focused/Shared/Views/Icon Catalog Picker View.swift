import SwiftUI

/// Unified SF Symbols picker used across the app.
/// Uses the shared `availableHabitIcons` catalog.
struct IconCatalogPickerView: View {
    @Environment(\.dismiss) private var dismiss
    
    let title: String
    let tintColor: Color
    @Binding var selectedIconName: String?
    var onPick: (() -> Void)? = nil
    
    @State private var searchText: String = ""
    
    private let hapticManager = HapticSoundManager.shared
    private let columns = [GridItem(.adaptive(minimum: 60), spacing: 12)]
    
    private var filteredIcons: [String] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return availableHabitIcons }
        return availableHabitIcons.filter { $0.localizedCaseInsensitiveContains(q) }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("search icons", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding()
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 8)
                
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(filteredIcons, id: \.self) { name in
                            Button {
                                hapticManager.playHaptic(style: .light)
                                selectedIconName = name
                                onPick?()
                                dismiss()
                            } label: {
                                Image(systemName: name)
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .frame(width: 52, height: 52)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(tintColor)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(
                                                (selectedIconName == name) ? Color.white.opacity(0.9) : Color.black.opacity(0.08),
                                                lineWidth: (selectedIconName == name) ? 2 : 1
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
        }
    }
}

