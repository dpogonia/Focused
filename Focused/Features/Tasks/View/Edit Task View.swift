import SwiftUI
import SwiftData

// Presentation · Tasks — форма добавления/редактирования задачи.
// Изменения уходят в SwiftData; правила «что показать в списке» — `FilterTasksUseCase` на экране `AllTasksView`.

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
    @State private var subTasksInput: String = ""
    @State private var subTasks: [SubTask] = []
    @State private var tags: [String] = []
    @State private var selectedSphereID: UUID? = nil
    @State private var positiveImpact: Double = 0.0
    @State private var negativeImpact: Double = 0.0
    @State private var colorForPicker: Color = .blue
    @State private var showDeleteTaskConfirmation: Bool = false
    @State private var showArchiveTaskConfirmation: Bool = false
    
    private let hapticManager = HapticSoundManager.shared
    
    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(AppEditFormChrome.basicSectionTitle)) {
                    TextField("title", text: $title)
                    TextField("description", text: $descript, axis: .vertical)
                        .lineLimit(2, reservesSpace: true)
                }
                
                Section(header: Text(AppEditFormChrome.subTasksSectionTitle)) {
                    HStack {
                        TextField("add sub-task", text: $subTasksInput, onCommit: addSubTask)
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
                
                AreaImpactSection(
                    selectedSphereID: $selectedSphereID,
                    positiveImpact: $positiveImpact,
                    negativeImpact: $negativeImpact,
                    colorHex: $colorHex,
                    colorForPicker: $colorForPicker
                ) { sphere, amount in
                    applyMissDecrease(to: sphere, amount: amount)
                }
                
                Section(header: Text(AppEditFormChrome.detailsSectionTitle)) {
                    if let date = dueDate {
                        HStack(spacing: 8) {
                            EditFormDetailLeadingIcon(systemName: "calendar")
                            Text("Due Date")
                            Spacer(minLength: 8)
                            DatePicker(
                                "",
                                selection: Binding(get: { date }, set: { dueDate = $0 }),
                                displayedComponents: .date
                            )
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .accessibilityLabel("Due Date")
                            Button {
                                dueDate = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        Button {
                            dueDate = Date()
                        } label: {
                            HStack(spacing: 8) {
                                EditFormDetailLeadingIcon(systemName: "calendar")
                                Text("Add Due Date")
                            }
                        }
                    }
                    
                }
                
                Section(header: Text(AppEditFormChrome.tagsSectionTitle)) {
                    MemoTagsSelectionView(selectedTags: $tags)
                }
                if taskToEdit != nil {
                    Section {
                        Button {
                            showArchiveTaskConfirmation = true
                        } label: {
                            Label(
                                (taskToEdit?.statusEnum == .archived) ? "Unarchive" : "Archive",
                                systemImage: (taskToEdit?.statusEnum == .archived) ? "tray.and.arrow.up" : "archivebox"
                            )
                        }
                        .tint(.gray)
                        
                        Button(role: .destructive) {
                            showDeleteTaskConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
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
                    if taskToEdit == nil {
                        colorHex = AppConstants.Colors.palette.first ?? "#3498db"
                    }
                } else if taskToEdit == nil, let sid = newVal, let sphere = spheres.first(where: { $0.id == sid }) {
                    colorHex = sphere.colorHex
                }
            }
            .overlay {
                if showArchiveTaskConfirmation, let task = taskToEdit {
                    let allowSecondary = task.statusEnum != .archived
                    ImpactActionPresenter.dialog(
                        isPresented: $showArchiveTaskConfirmation,
                        spheres: spheres,
                        sphereID: task.sphereID,
                        negativeImpact: task.negativeImpact,
                        allowSecondaryAction: allowSecondary,
                        title: task.statusEnum == .archived ? "Unarchive task?" : "Archive task?",
                        message: task.statusEnum == .archived ? "This task will return to the active list." : "This task will be archived.",
                        messageWithImpact: "Archive this task. You can also apply its miss decrease to the area.",
                        primaryTitle: task.statusEnum == .archived ? "Unarchive" : "Archive",
                        primaryTint: .gray,
                        secondaryTitleFormat: "Archive and apply negative impact (-%@%%) on area",
                        secondaryTint: .gray,
                        onPrimary: {
                            if task.statusEnum == .archived {
                                task.updateStatus(to: .inProgress)
                            } else {
                                task.updateStatus(to: .archived)
                            }
                            try? modelContext.save()
                            NotificationCenter.default.postAppEvent(.taskStatusDidChange)
                            dismiss()
                        },
                        onSecondary: {
                            if task.statusEnum != .archived, let sid = task.sphereID, let sphere = spheres.first(where: { $0.id == sid }) {
                                applyMissDecrease(to: sphere, amount: task.negativeImpact)
                            }
                            task.updateStatus(to: .archived)
                            try? modelContext.save()
                            NotificationCenter.default.postAppEvent(.taskStatusDidChange)
                            NotificationCenter.default.postAppEvent(.sphereSatisfactionDidChange)
                            dismiss()
                        },
                        onCancel: { }
                    )
                }
            }
            .overlay {
                if showDeleteTaskConfirmation, let task = taskToEdit {
                    let sphereForImpact = task.sphereID.flatMap { sid in
                        spheres.first(where: { $0.id == sid })
                    }
                    ImpactActionPresenter.dialog(
                        isPresented: $showDeleteTaskConfirmation,
                        spheres: spheres,
                        sphereID: task.sphereID,
                        negativeImpact: task.negativeImpact,
                        title: "Delete task?",
                        message: "This task and its subtasks will be permanently deleted.",
                        messageWithImpact: "Delete this task. You can also apply its miss decrease to the area.",
                        primaryTitle: "Delete",
                        primaryTint: .red,
                        secondaryTitleFormat: "Delete and apply negative impact (-%@%%) on area",
                        secondaryTint: .red,
                        onPrimary: {
                            modelContext.delete(task)
                            try? modelContext.save()
                            NotificationCenter.default.postAppEvent(.taskStatusDidChange)
                            dismiss()
                        },
                        onSecondary: {
                            if let sphereForImpact {
                                applyMissDecrease(to: sphereForImpact, amount: task.negativeImpact)
                            }
                            modelContext.delete(task)
                            try? modelContext.save()
                            NotificationCenter.default.postAppEvent(.taskStatusDidChange)
                            NotificationCenter.default.postAppEvent(.sphereSatisfactionDidChange)
                            dismiss()
                        },
                        onCancel: { }
                    )
                }
            }
        }
    }
    
    private func loadTaskData() {
        if let task = taskToEdit {
            title = task.title
            descript = task.descript ?? ""
            let sphere = task.sphereID.flatMap { sid in spheres.first { $0.id == sid } }
            colorHex = task.colorHex ?? sphere?.colorHex ?? AppConstants.Colors.palette.first!
            dueDate = task.dueDate
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
        var seenTagKeys = Set<String>()
        for rawTagName in tags {
            let tagName = rawTagName
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "#", with: "")
            let normalized = TagNameNormalizer.storageName(from: tagName)
            let key = TagNameNormalizer.key(from: normalized)
            guard !normalized.isEmpty else { continue }
            guard !seenTagKeys.contains(key) else { continue }
            seenTagKeys.insert(key)
            
            let fetchDescriptor = FetchDescriptor<Tag>(predicate: #Predicate<Tag> { $0.name == normalized })
            if let existingTag = try? modelContext.fetch(fetchDescriptor).first {
                taskTags.append(existingTag)
            } else {
                let newTag = Tag(name: normalized)
                modelContext.insert(newTag)
                taskTags.append(newTag)
            }
        }
        
        if let task = taskToEdit {
            task.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            task.descript = descript.isEmpty ? nil : descript
            task.colorHex = colorHex
            task.dueDate = dueDate
            task.subTasks = subTasks
            task.tags = taskTags
            task.sphereID = selectedSphereID
            
            task.positiveImpact = positiveImpact
            task.negativeImpact = negativeImpact
        } else {
            shiftExistingTasksDownForInsertAtTop()
            let newTask = SuperTask(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                descript: descript.isEmpty ? nil : descript,
                colorHex: colorHex,
                dueDate: dueDate,
                repeating: .none,
                status: .inProgress,
                orderIndex: 0,
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
        TagMaintenanceService.pruneUnusedTags(modelContext: modelContext)
    }

    private func shiftExistingTasksDownForInsertAtTop() {
        let descriptor = FetchDescriptor<SuperTask>(
            sortBy: [SortDescriptor(\SuperTask.orderIndex, order: .forward)]
        )
        guard let existing = try? modelContext.fetch(descriptor), !existing.isEmpty else { return }
        for task in existing {
            task.orderIndex += 1
        }
        try? modelContext.save()
    }

    private func applyMissDecrease(to sphere: Sphere, amount: Double) {
        let clamped = max(0.0, min(100.0, amount))
        sphere.satisfaction = max(0.0, min(100.0, sphere.satisfaction - clamped))
        try? modelContext.save()
    }
}
