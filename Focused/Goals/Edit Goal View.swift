import SwiftUI
import SwiftData
import PhotosUI

// MARK: - ADD/EDIT GOAL VIEW
struct EditGoalView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var spheres: [Sphere]
    @Binding var goalToEdit: Goal?
    
    @State private var title: String = ""
    @State private var descript: String = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var showPhotoPicker: Bool = false
    @State private var colorHex: String = AppConstants.Colors.palette.first!
    @State private var colorForPicker: Color = Color(hex: AppConstants.Colors.palette.first!)
    @State private var dueDate: Date?
    @State private var reward: String = ""
    @State private var status: Goal.Status = .pending
    @State private var subtasks: [SubTask] = []
    @State private var subtaskInput: String = ""
    @State private var counters: [Counter] = []
    @State private var counterNameInput: String = ""
    @State private var counterTargetInput: String = ""
    @State private var tags: [String] = []
    @State private var selectedSphereID: UUID?
    @State private var positiveImpact: Double = 0.0
    @State private var negativeImpact: Double = 0.0
    @State private var isFlagged: Bool = false
    
    let allGoalsCount: Int
    
    private let hapticManager = HapticSoundManager.shared
    
    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Description") {
                    TextField("title", text: $title)
                    ZStack(alignment: .topLeading) {
                        if descript.isEmpty {
                            Text("additional information")
                                .foregroundColor(.placeholderColor)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $descript)
                            .frame(minHeight: 50)
                    }
                    ColorSelectionView(availableColors: AppConstants.Colors.palette, selectedColorHex: $colorHex, colorForPicker: $colorForPicker)
                        .padding(.vertical, 0)
                    if let data = imageData ?? goalToEdit?.imageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 100)
                            .contextMenu {
                                Button {
                                    showPhotoPicker = true
                                } label: {
                                    Label("Change Image", systemImage: "photo.on.rectangle")
                                }
                                Button(role: .destructive) {
                                    imageData = nil
                                    // Очистим изображение у редактируемой цели немедленно, если есть
                                    goalToEdit?.imageData = nil
                                } label: {
                                    Label("Remove Image", systemImage: "trash")
                                }
                            }
                            .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhoto, matching: .images)
                    } else if let sphereID = selectedSphereID ?? goalToEdit?.sphereID, let sphere = spheres.first(where: { $0.id == sphereID }) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: sphere.colorHex).opacity(0.15))
                                .frame(width: 100, height: 100)
                            Image(systemName: sphere.iconName)
                                .font(.system(size: 44, weight: .semibold))
                                .foregroundColor(Color(hex: sphere.colorHex))
                        }
                        .frame(maxHeight: 100)
                        .contextMenu {
                            Button {
                                showPhotoPicker = true
                            } label: {
                                Label("Select Image", systemImage: "photo")
                            }
                        }
                        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhoto, matching: .images)
                    }
                    PhotosPicker("Select Image", selection: $selectedPhoto, matching: .images)
                        .onChange(of: selectedPhoto) { oldItem, newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                    imageData = data
                                }
                            }
                        }
                }
                
                Section("Status") {
                    Picker("Status", selection: $status) {
                        ForEach(Goal.Status.allCases, id: \.self) { status in
                            Text(status.rawValue.capitalized)
                        }
                    }
                    DatePicker("Due Date", selection: Binding(get: { dueDate ?? Date() }, set: { dueDate = $0 }), displayedComponents: .date)
                    TextField("Reward", text: $reward)
                }
                Section("Sphere") {
                    VStack(alignment: .leading, spacing: 8) {
                        SpherePickerView(selectedSphereID: $selectedSphereID)
                        if let sid = selectedSphereID, let sphere = spheres.first(where: { $0.id == sid }) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Impact on \(sphere.title)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                ImpactSliderView(
                                    positiveImpact: $positiveImpact,
                                    negativeImpact: $negativeImpact,
                                    range: 0...10,
                                    step: 0.1,
                                    unit: ""
                                )
                            }
                        }
                    }
                }
                
                
                Section {
                    MemoTagsSelectionView(selectedTags: $tags)
                } header: {
                    Text("Tags")
                }
                
                if goalToEdit != nil {
                    DeleteConfirmationButton(itemName: "Goal") {
                        if let goal = goalToEdit {
                            modelContext.delete(goal)
                            try? modelContext.save()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(goalToEdit == nil ? "New Goal" : "Edit Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(goalToEdit == nil ? "Create" : "Save") {
                        hapticManager.playNotificationHaptic(type: .success)
                        saveGoal()
                        dismiss()
                    }
                    .disabled(!isFormValid)
                }
            }
            .onAppear(perform: loadGoalData)
            .onChange(of: colorForPicker) {
                if let newHex = colorForPicker.toHex() {
                    colorHex = newHex
                }
            }
            .onChange(of: colorHex) {
                colorForPicker = Color(hex: colorHex)
            }
            .onChange(of: selectedSphereID) { old, newVal in
                if newVal == nil {
                    positiveImpact = 0.0
                    negativeImpact = 0.0
                }
            }
        }
    }
    
    private func loadGoalData() {
        if let goal = goalToEdit {
            title = goal.title
            descript = goal.descript ?? ""
            imageData = goal.imageData
            colorHex = goal.colorHex ?? AppConstants.Colors.palette.first!
            dueDate = goal.dueDate
            reward = goal.reward ?? ""
            status = goal.status
            subtasks = goal.subtasks
            counters = goal.counters
            tags = goal.tags.map { $0.name }
            selectedSphereID = goal.sphereID
            positiveImpact = goal.positiveImpact
            negativeImpact = goal.negativeImpact
            isFlagged = goal.isFlagged
        } else {
            resetFields()
        }
        colorForPicker = Color(hex: colorHex)
    }
    
    private func resetFields() {
        title = ""
        descript = ""
        imageData = nil
        colorHex = AppConstants.Colors.palette.first ?? "#3498db"
        dueDate = nil
        reward = ""
        status = .pending
        subtasks = []
        counters = []
        tags = []
        selectedSphereID = nil
        positiveImpact = 0.0
        negativeImpact = 0.0
        isFlagged = false
    }
    
    private func saveGoal() {
        var goalTags: [Tag] = []
        for tagName in tags {
            let fetchDescriptor = FetchDescriptor<Tag>(predicate: #Predicate<Tag> { $0.name == tagName })
            if let existingTag = try? modelContext.fetch(fetchDescriptor).first {
                goalTags.append(existingTag)
            } else {
                let newTag = Tag(name: tagName)
                modelContext.insert(newTag)
                goalTags.append(newTag)
            }
        }
        
        if let goal = goalToEdit {
            goal.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            goal.descript = descript.isEmpty ? nil : descript
            goal.imageData = imageData
            goal.colorHex = colorHex
            goal.dueDate = dueDate
            goal.reward = reward.isEmpty ? nil : reward
            goal.status = status
            goal.subtasks = subtasks
            goal.counters = counters
            goal.tags = goalTags
            goal.sphereID = selectedSphereID
            goal.positiveImpact = positiveImpact
            goal.negativeImpact = negativeImpact
            goal.isFlagged = isFlagged
        } else {
            let newGoal = Goal(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                description: descript.isEmpty ? nil : descript,
                imageData: imageData,
                colorHex: colorHex,
                dueDate: dueDate,
                reward: reward.isEmpty ? nil : reward,
                status: .pending,
                orderIndex: allGoalsCount,
                subtasks: subtasks,
                counters: counters,
                sphereID: selectedSphereID,
                positiveImpact: positiveImpact,
                negativeImpact: negativeImpact,
                isFlagged: isFlagged
            )
            newGoal.tags = goalTags
            modelContext.insert(newGoal)
        }
        try? modelContext.save()
    }
}

