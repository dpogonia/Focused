import SwiftUI
import SwiftData

// MARK: - VISION CARD
struct VisionPageView: View {
    let title: String
    let icon: String
    let vision: String
    let color: Color
    let isSelected: Bool
    let onTap: () -> Void
    let onEdit: (String) -> Void
    let isGenerating: Bool
    let onGenerate: () -> Void
    
    @State private var isEditing: Bool = false
    @State private var editedText: String = ""
    @State private var showFullScreen: Bool = false
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 24, height: 24)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: onGenerate) {
                    if isGenerating {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "wand.and.stars")
                            .font(.title3)
                            .foregroundColor(color)
                    }
                }
                .frame(width: 32, height: 32)
                .background(color.opacity(0.1))
                .cornerRadius(10)
                .disabled(isGenerating)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            ZStack(alignment: .topLeading) {
                if isEditing {
                    TextEditor(text: $editedText)
                        .font(.body)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 80)
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(color.opacity(0.3), lineWidth: 1)
                        )
                } else {
                    if vision.isEmpty {
                        Text("Describe your life vision...")
                            .foregroundColor(.gray.opacity(0.7))
                            .font(.body)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ScrollView {
                            Text(vision)
                                .font(.body)
                                .foregroundColor(.primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxHeight: .infinity)
                        .mask( // FADING BOTTOM
                            LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: .black, location: 0.0),
                                    .init(color: .black, location: 0.85),
                                    .init(color: .clear, location: 1.0)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            
            // ACTIONABLE BUTTONS FOR EDITING MODE
            if isEditing {
                HStack(spacing: 8) {
                    Button("Cancel") {
                        editedText = vision
                        isEditing = false
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(6)
                    
                    Button("Save") {
                        onEdit(editedText)
                        isEditing = false
                    }
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(color)
                    .cornerRadius(6)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.systemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? color.opacity(0.5) : Color.gray.opacity(0.2), lineWidth: isSelected ? 1 : 1)
                )
                .shadow(color: isSelected ? color.opacity(0.2) : .black.opacity(0.1), radius: isSelected ? 8 : 4, x: 0, y: 2)
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSelected)
        .onTapGesture(perform: onTap)
        .onTapGesture(count: 2) {
            HapticSoundManager.shared.selectionChanged()
            editedText = vision
            isEditing = true
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            HapticSoundManager.shared.selectionChanged()
            showFullScreen = true
        }
        .sheet(isPresented: $showFullScreen) {
            VisionFullScreenView(
                title: title,
                icon: icon,
                vision: vision,
                color: color,
                onEdit: onEdit
            )
        }
    }
}

// MARK: - VISION FULL SCREEN VIEW
struct VisionFullScreenView: View {
    let title: String
    let icon: String
    let vision: String
    let color: Color
    let onEdit: (String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var isEditing: Bool = false
    @State private var editedText: String = ""
    private let hapticManager = HapticSoundManager.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                HStack {
                    HStack(spacing: 12) {
                        Image(systemName: icon)
                            .font(.title)
                            .foregroundColor(color)
                            .frame(width: 32, height: 32)
                        
                        Text(title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    if !vision.isEmpty {
                        Button("Edit") {
                            hapticManager.selectionChanged()
                            editedText = vision
                            isEditing = true
                        }
                        .font(.headline)
                        .foregroundColor(color)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(color.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    Button("Close") {
                        hapticManager.selectionChanged()
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundColor(color)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 20)
                
                Divider()
                
                if isEditing {
                    VStack(spacing: 16) {
                        TextEditor(text: $editedText)
                            .font(.body)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .scrollContentBackground(.hidden)
                            .frame(maxHeight: .infinity)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(color.opacity(0.3), lineWidth: 1)
                            )
                        
                        HStack(spacing: 12) {
                            Button("Cancel") {
                                editedText = vision
                                isEditing = false
                            }
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            
                            Button("Save") {
                                onEdit(editedText)
                                isEditing = false
                                dismiss()
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(color)
                            .cornerRadius(8)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                    .padding(.horizontal, 20)
                } else if vision.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        
                        Image(systemName: "text.bubble")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.3))
                        
                        Text("No vision yet")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        
                        Button("Add Vision") {
                            editedText = ""
                            isEditing = true
                        }
                        .font(.headline)
                        .foregroundColor(color)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(color.opacity(0.1))
                        .cornerRadius(8)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(vision)
                                .font(.body)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 20)
                        }
                    }
                }
                
                Spacer()
            }
            .background(Color(UIColor.systemBackground))
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            editedText = vision
        }
    }
}
