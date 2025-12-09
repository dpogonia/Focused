import SwiftUI
import SwiftData

// MARK: - ADD/EDIT TASK VIEW
struct AddEditTaskView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var spheres: [Sphere]
    
    @Binding var taskToEdit: SuperTask?
    let allTasksCount: Int
    
    @State private var title: String = ""
    @State private var descript: String = ""
    @State private var colorHex: String = AppConstants.Colors.palette.first ?? "#3498db"
    @State private var dueDate: Date? = nil
    @State private var priority: SuperTask.PriorityEnum = .none
    @State private var repeating: SuperTask.Repeating = .none
    @State private var subTasksInput: String = ""
    @State private var subTasks: [SubTask] = []
    @State private var tags: [String] = []
    @State private var selectedSphereID: UUID? = nil
    @State private var positiveImpact: Double = 0.0
    @State private var negativeImpact: Double = 0.0
    @State private var colorForPicker: Color = .blue
    
    private let hapticManager = HapticSoundManager.shared
    
    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Basic Info")) {
                    TextField("Title", text: $title)
                    TextField("Description (optional)", text: $descript, axis: .vertical)
                        .lineLimit(5, reservesSpace: true)
                }
                
                Section(header: Text("Sphere")) {
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
                                    range: 0...100,
                                    step: 1.0,
                                    unit: "%"
                                )
                            }
                        }
                    }
                }
                
                Section(header: Text("Details")) {
                    DatePicker("Due Date (optional)", selection: Binding(
                        get: { dueDate ?? Date() },
                        set: { dueDate = $0 }
                    ), displayedComponents: .date)
                    .datePickerStyle(.compact)
                    
                    Picker("Priority", selection: $priority) {
                        ForEach(SuperTask.PriorityEnum.allCases, id: \.self) { prio in
                            Text(prio.displayString).tag(prio)
                        }
                    }
                    
                    Picker("Repeating", selection: $repeating) {
                        ForEach(SuperTask.Repeating.allCases, id: \.self) { repeating in
                            Text(repeating.rawValue.capitalized).tag(repeating)
                        }
                    }
                }
                
                Section(header: Text("Color (optional)")) {
                    ColorSelectionView(availableColors: AppConstants.Colors.palette, selectedColorHex: $colorHex, colorForPicker: $colorForPicker)
                }
                
                
                
                Section(header: Text("Sub-Tasks")) {
                    HStack {
                    TextField("Add Sub-Task", text: $subTasksInput, onCommit: addSubTask)
                        Button(action: addSubTask) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                        }
                        .disabled(subTasksInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    
                    if !subTasks.isEmpty {
                        ForEach(subTasks) { subTask in
                            SubTaskEditRow(
                                subTask: subTask,
                                onDelete: { removeSubTask(subTask) }
                            )
                        }
                        .onDelete(perform: removeSubTasks)
                        .onMove(perform: moveSubTasks)
                    }
                }
                Section(header: Text("Tags")) {
                    MemoTagsSelectionView(selectedTags: $tags)
                }
                if taskToEdit != nil {
                    DeleteConfirmationButton(itemName: "Task") {
                        if let task = taskToEdit {
                            modelContext.delete(task)
                            try? modelContext.save()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(taskToEdit == nil ? "New Task" : "Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(taskToEdit == nil ? "Create" : "Save") {
                        hapticManager.playNotificationHaptic(type: .success)
                        saveTask()
                        dismiss()
                    }
                    .disabled(!isFormValid)
                }
            }
            .onAppear(perform: loadTaskData)
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
    
    private func loadTaskData() {
        if let task = taskToEdit {
            title = task.title
            descript = task.descript ?? ""
            colorHex = task.colorHex ?? AppConstants.Colors.palette.first!
            dueDate = task.dueDate
            priority = task.priorityEnum
            repeating = task.repeatingEnum
            subTasks = task.subTasks
            tags = task.tags.map { $0.name }
            selectedSphereID = task.sphereID
            
            positiveImpact = task.positiveImpact
            negativeImpact = task.negativeImpact
        } else {
            resetFields()
        }
        colorForPicker = Color(hex: colorHex)
    }
    
    private func resetFields() {
        title = ""
        descript = ""
        colorHex = AppConstants.Colors.palette.first ?? "#3498db"
        dueDate = nil
        priority = .none
        repeating = .none
        subTasks = []
        tags = []
        selectedSphereID = nil
        
        positiveImpact = 0.0
        negativeImpact = 0.0
    }
    
    private func addSubTask() {
        let trimmed = subTasksInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            let newSubTask = SubTask(title: trimmed, orderIndex: subTasks.count)
            subTasks.append(newSubTask)
            subTasksInput = ""
        }
    }
    
    private func removeSubTask(_ subTask: SubTask) {
        if let index = subTasks.firstIndex(where: { $0.id == subTask.id }) {
            subTasks.remove(at: index)
        }
    }
    
    private func removeSubTasks(at offsets: IndexSet) {
        subTasks.remove(atOffsets: offsets)
    }
    
    private func moveSubTasks(from source: IndexSet, to destination: Int) {
        subTasks.move(fromOffsets: source, toOffset: destination)
        
        // Update order indices
        for (index, subTask) in subTasks.enumerated() {
            subTask.orderIndex = index
        }
    }
    
    private func saveTask() {
        var taskTags: [Tag] = []
        for tagName in tags {
            let fetchDescriptor = FetchDescriptor<Tag>(predicate: #Predicate<Tag> { $0.name == tagName })
            if let existingTag = try? modelContext.fetch(fetchDescriptor).first {
                taskTags.append(existingTag)
            } else {
                let newTag = Tag(name: tagName)
                modelContext.insert(newTag)
                taskTags.append(newTag)
            }
        }
        
        if let task = taskToEdit {
            task.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            task.descript = descript.isEmpty ? nil : descript
            task.colorHex = colorHex
            task.dueDate = dueDate
            task.priority = priority.rawValue
            task.repeating = repeating.rawValue
            task.subTasks = subTasks
            task.tags = taskTags
            task.sphereID = selectedSphereID
            
            task.positiveImpact = positiveImpact
            task.negativeImpact = negativeImpact
        } else {
            
            let newTask = SuperTask(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                descript: descript.isEmpty ? nil : descript,
                colorHex: colorHex,
                dueDate: dueDate,
                priority: priority,
                repeating: repeating,
                status: .pending,
                orderIndex: allTasksCount,
                subTasks: subTasks,
                sphereID: selectedSphereID,
                goalID: nil,
                positiveImpact: positiveImpact,
                negativeImpact: negativeImpact,
                estimatedDuration: 0
            )
            newTask.tags = taskTags
            modelContext.insert(newTask)
        }
        
        try? modelContext.save()
    }
}
