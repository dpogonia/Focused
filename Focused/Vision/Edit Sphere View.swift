import SwiftUI
import SwiftData

// MARK: - Add/Edit Sphere View
struct AddEditSphereView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Binding var sphereToEdit: Sphere?
    let spheresCount: Int
    
    @State private var title: String = ""
    @State private var satisfaction: Double = 50.0
    @State private var colorHex: String = AppConstants.Colors.palette.first ?? "#32ADE6"
    @State private var iconName: String = "star.fill"
    @State private var colorForPicker: Color = .blue
    @State private var colorUpdateTrigger: Bool = false
    
    @State private var showDeleteConfirmation: Bool = false
    
    private let hapticManager = HapticSoundManager.shared
    
    private var isEditing: Bool { sphereToEdit != nil }
    
    private let columns = [
        GridItem(.adaptive(minimum: 60), spacing: 10)
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .center, spacing: 15) {
                        Image(systemName: iconName)
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                            .frame(width: 100, height: 100)
                            .background(Color(hex: colorHex))
                            .clipShape(Circle())
                            .shadow(radius: 5)
                        
                        TextField("title", text: $title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .autocapitalization(.words)
                            .listRowBackground(Color.clear)
                        
                        VStack(spacing: 5) {
                            Text(String(format: "Satisfaction: %.2f%%", satisfaction))
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Slider(value: $satisfaction, in: 0...100, step: 0.01)
                                .accentColor(Color(hex: colorHex))
                        }
                    }
                    .padding(.vertical)
                    .frame(maxWidth: .infinity)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
                
                Section("DETAILS") {
                    VStack(alignment: .leading) {
                        ColorSelectionView(availableColors: AppConstants.Colors.palette, selectedColorHex: $colorHex, colorForPicker: $colorForPicker)
                    }
                    .padding(.vertical, 5)
                    
                    VStack(alignment: .leading) {
                        
                        
                        ScrollView {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                                ForEach(availableHabitIcons, id: \.self) { iconName in
                                    Button(action: {
                                        print("Icon tapped: \(iconName)")
                                        self.iconName = iconName
                                        print("Selected icon set to: \(self.iconName)")
                                        hapticManager.playHaptic(style: .light)
                                    }) {
                                        Image(systemName: iconName)
                                            .font(.title2)
                                            .foregroundColor(self.iconName == iconName ? .white : .primary)
                                            .frame(width: 40, height: 40)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(self.iconName == iconName ? (colorForPicker == .clear ? Color.accentColor : colorForPicker) : Color.gray.opacity(0.1))
                                            )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .id("\(iconName)_\(colorUpdateTrigger)")
                        }.frame(height: 144)
                    }
                    .padding(.vertical, 5)
                }
                
                if isEditing {
                    Section {
                        Button("Delete Sphere", role: .destructive) {
                            showDeleteConfirmation = true
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Sphere" : "New Sphere")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: saveSphere)
                        .disabled(title.isEmpty)
                }
            }
            .onAppear(perform: loadSphereData)
            .confirmationDialog("Are you sure you want to delete this sphere? This cannot be undone.", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive, action: deleteSphere)
            }
            .onChange(of: colorForPicker) {
                if let newHex = colorForPicker.toHex() {
                    colorHex = newHex
                }
                self.colorUpdateTrigger.toggle()
            }
            .onChange(of: colorHex) {
                colorForPicker = Color(hex: colorHex)
            }
        }
    }
    
    private func loadSphereData() {
        if let sphere = sphereToEdit {
            title = sphere.title
            satisfaction = sphere.satisfaction
            colorHex = sphere.colorHex
            iconName = sphere.iconName
        } else {
            title = ""
            satisfaction = 50.0
            colorHex = AppConstants.Colors.palette.randomElement() ?? "#3498db"
            iconName = availableHabitIcons.randomElement() ?? "star.fill"
        }
        colorForPicker = Color(hex: colorHex)
    }
    
    private func saveSphere() {
        hapticManager.completionSuccess()
        if let sphere = sphereToEdit {
            sphere.title = title
            sphere.satisfaction = satisfaction
            sphere.colorHex = colorHex
            sphere.iconName = iconName
        } else {
            let newSphere = Sphere(
                title: title,
                satisfaction: satisfaction,
                colorHex: colorHex,
                iconName: iconName,
                orderIndex: spheresCount
            )
            modelContext.insert(newSphere)
        }
        dismiss()
    }
    
    private func deleteSphere() {
        if let sphere = sphereToEdit {
            modelContext.delete(sphere)
            hapticManager.itemDeleted()
        }
        dismiss()
    }
}
