import SwiftUI
import SwiftData


// MARK: - SUBTASKS VIEW
struct SubTasksView: View {
    @Bindable var task: SuperTask
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var newSubTaskTitle: String = ""
    @State private var editingSubTask: SubTask?
    @State private var editingTitle: String = ""
    @State private var showAddSubTask: Bool = false
    @State private var showQuickAddSubTask: Bool = false
    
    private let hapticManager = HapticSoundManager.shared
    
    private var completedSubTasksCount: Int {
        task.subTasks.filter { $0.isCompleted }.count
    }
    
    private var totalSubTasksCount: Int {
        task.subTasks.count
    }
    
    private var progressPercentage: Double {
        guard !task.subTasks.isEmpty else { return 0 }
        return Double(completedSubTasksCount) / Double(totalSubTasksCount)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressHeader
                subtasksContent
            }
            .navigationTitle("Subtasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        Button(action: { showQuickAddSubTask = true }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                        }
                    }
                }
            }
            .sheet(isPresented: $showQuickAddSubTask) {
                AddSubTaskView(task: task)
            }
            .sheet(item: $editingSubTask) { subTask in
                SubTaskFormView(subTask: subTask)
            }
        }
    }
    
    // MARK: - PROGRESS HEADER
    @ViewBuilder
    private var progressHeader: some View {
        VStack(spacing: 8) {
            HStack {
                progressTextSection
                Spacer()
                progressCircleSection
            }
            .padding(.horizontal)
            .padding(.top)
            
            progressBarSection
        }
        .padding(.bottom)
        .background(Color(UIColor.secondarySystemGroupedBackground))
    }
    
    @ViewBuilder
    private var progressTextSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Progress")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("\(completedSubTasksCount) of \(totalSubTasksCount) completed")
                .font(.title2)
                .fontWeight(.bold)
        }
    }
    
    @ViewBuilder
    private var progressCircleSection: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                .frame(width: 60, height: 60)
            
            Circle()
                .trim(from: 0, to: progressPercentage)
                .stroke(Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .frame(width: 60, height: 60)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: completedSubTasksCount)
            
            Text("\(Int(progressPercentage * 100))%")
                .font(.caption)
                .fontWeight(.semibold)
        }
    }
    
    @ViewBuilder
    private var progressBarSection: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 8)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.blue)
                    .frame(width: geometry.size.width * progressPercentage, height: 8)
                    .animation(.easeInOut(duration: 0.5), value: completedSubTasksCount)
            }
        }
        .frame(height: 8)
        .padding(.horizontal)
    }
    
    // MARK: - SUBTASKS CONTENT
    @ViewBuilder
    private var subtasksContent: some View {
        if task.subTasks.isEmpty {
            EmptyStateView.noSubtasks()
        } else {
            subtasksListView
        }
    }
    
    
    @ViewBuilder
    private var subtasksListView: some View {
        List {
            ForEach(task.subTasks.sorted(by: { $0.orderIndex < $1.orderIndex }), id: \.id) { subTask in
                SubTaskRowView(subTask: subTask, task: task)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("Delete", role: .destructive) {
                            deleteSubTask(subTask)
                        }
                        
                        Button("Edit") {
                            startEditing(subTask)
                        }
                        .tint(.blue)
                    }
            }
            .onMove(perform: moveSubTasks)
        }
        .listStyle(.plain)
    }
    
    // MARK: - PRIVATE FUNCTIONS
    
    private func startEditing(_ subTask: SubTask) {
        editingSubTask = subTask
        editingTitle = subTask.title
    }
    
    private func saveEditedSubTask() {
        if let subTask = editingSubTask {
            subTask.title = editingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            try? modelContext.save()
            hapticManager.selectionChanged()
        }
        editingSubTask = nil
        editingTitle = ""
    }
    
    private func deleteSubTask(_ subTask: SubTask) {
        if let index = task.subTasks.firstIndex(where: { $0.id == subTask.id }) {
            task.subTasks.remove(at: index)
            try? modelContext.save()
            hapticManager.itemDeleted()
        }
    }
    
    private func moveSubTasks(from source: IndexSet, to destination: Int) {
        task.subTasks.move(fromOffsets: source, toOffset: destination)
        
        // Update order indices
        for (index, subTask) in task.subTasks.enumerated() {
            subTask.orderIndex = index
        }
        
        try? modelContext.save()
        hapticManager.selectionChanged()
    }
}



// MARK: - ADD SUBTASK VIEW
struct AddSubTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var task: SuperTask
    
    @State private var title: String = ""
    @State private var estimatedDuration: Int = 0
    @State private var notes: String = ""
    
    private let hapticManager = HapticSoundManager.shared
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Subtask Details")) {
                    TextField("Subtask title", text: $title)
                        .textFieldStyle(.roundedBorder)
                    
                    HStack {
                        Text("Estimated duration")
                        Spacer()
                        Picker("Duration", selection: $estimatedDuration) {
                            Text("No estimate").tag(0)
                            ForEach([5, 10, 15, 30, 45, 60, 90, 120], id: \.self) { minutes in
                                Text("\(minutes) min").tag(minutes)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                        .textFieldStyle(.roundedBorder)
                }
                
                if !task.subTasks.isEmpty {
                    Section(header: Text("Current Subtasks")) {
                        ForEach(task.subTasks) { subTask in
                            HStack {
                                Image(systemName: subTask.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(subTask.isCompleted ? .green : .gray)
                                Text(subTask.title)
                                    .strikethrough(subTask.isCompleted)
                                    .foregroundColor(subTask.isCompleted ? .secondary : .primary)
                                Spacer()
                                if subTask.estimatedDuration > 0 {
                                    Text("\(subTask.estimatedDuration) min")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Subtask")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addSubTask()
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func addSubTask() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let newSubTask = SubTask(
            title: trimmedTitle,
            orderIndex: task.subTasks.count,
            estimatedDuration: estimatedDuration,
            notes: notes.isEmpty ? nil : notes
        )
        
        task.subTasks.append(newSubTask)
        hapticManager.completionSuccess()
    }
}


// MARK: - SUBTASK EDIT ROW
struct SubTaskEditRow: View {
    let subTask: SubTask
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "list.bullet")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 16)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(subTask.title)
                    .font(.body)
                    .strikethrough(subTask.isCompleted)
                    .foregroundColor(subTask.isCompleted ? .secondary : .primary)
                
                if subTask.estimatedDuration > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(subTask.estimatedDuration) min")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - SUBTASK ROW VIEW
struct SubTaskRowView: View {
    @Bindable var subTask: SubTask
    let task: SuperTask
    @Environment(\.modelContext) private var modelContext
    
    @State private var isEditing = false
    @State private var editedTitle = ""
    
    private let hapticManager = HapticSoundManager.shared
    
    var body: some View {
        HStack(spacing: 12) {
            // Чекбокс
            Button(action: {
                hapticManager.selectionChanged()
                withAnimation(.easeInOut(duration: 0.2)) {
                    subTask.toggleCompletion()
                }
                try? modelContext.save()
            }) {
                Image(systemName: subTask.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.subheadline)
                    .foregroundColor(subTask.isCompleted ? .green : .secondary)
                    .scaleEffect(subTask.isCompleted ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: subTask.isCompleted)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Заголовок
            if isEditing {
                TextField("Subtask title", text: $editedTitle)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        if !editedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            subTask.title = editedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                            try? modelContext.save()
                        }
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isEditing = false
                        }
                    }
                    .onAppear {
                        editedTitle = subTask.title
                    }
                    .transition(.scale.combined(with: .opacity))
            } else {
                Text(subTask.title)
                    .font(.subheadline)
                    .foregroundColor(subTask.isCompleted ? .secondary : .primary)
                    .strikethrough(subTask.isCompleted)
                    .lineLimit(2)
                    .animation(.easeInOut(duration: 0.2), value: subTask.isCompleted)
                                    .onTapGesture(count: 2) {
                    hapticManager.selectionChanged()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isEditing = true
                    }
                }
            }
            
            Spacer()
            
            // Действия
            HStack(spacing: 8) {
                if subTask.estimatedDuration > 0 {
                    Label("\(subTask.estimatedDuration)min", systemImage: "clock")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Menu {
                    Button("Edit") {
                        hapticManager.selectionChanged()
                        isEditing = true
                    }
                    
                    Button("Delete", role: .destructive) {
                        hapticManager.itemDeleted()
                        task.subTasks.removeAll { $0.id == subTask.id }
                        try? modelContext.save()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .padding(.leading, 24) // Отступ слева для визуального "выдвижения"
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                hapticManager.selectionChanged()
                withAnimation(.easeInOut(duration: 0.2)) {
                    isEditing = true
                }
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
            
            Button(role: .destructive) {
                hapticManager.itemDeleted()
                withAnimation(.easeInOut(duration: 0.2)) {
                    task.subTasks.removeAll { $0.id == subTask.id }
                }
                try? modelContext.save()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                hapticManager.selectionChanged()
                withAnimation(.easeInOut(duration: 0.2)) {
                    subTask.toggleCompletion()
                }
                try? modelContext.save()
            } label: {
                Label(subTask.isCompleted ? "Mark Incomplete" : "Mark Complete",
                      systemImage: subTask.isCompleted ? "circle" : "checkmark.circle")
            }
            .tint(subTask.isCompleted ? .orange : .green)
        }
        .animation(.easeInOut(duration: 0.2), value: isEditing)
    }
}

// MARK: - QUICK ADD SUBTASK VIEW
struct QuickAddSubTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var task: SuperTask
    
    @State private var title: String = ""
    @State private var note: String = ""
    @State private var estimatedDuration: Int = 0
    @State private var dueDate: Date? = nil
    @State private var reminderDate: Date? = nil
    @State private var priority: Priority = .medium
    @State private var checklist: [String] = [""]
    @State private var showDetails: Bool = false
    @State private var showReminder: Bool = false
    @State private var showMore: Bool = false
    @State private var hasDueDate: Bool = false
    @State private var hasReminder: Bool = false
    
    private let hapticManager = HapticSoundManager.shared
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Название субтаска", text: $title)
                }
                
                Section {
                    DisclosureGroup(isExpanded: $showDetails) {
                        TextField("Короткая заметка (1–2 строки)", text: $note, axis: .vertical)
                            .lineLimit(2)
                        
                        Picker("Приоритет", selection: $priority) {
                            ForEach(Priority.allCases) { p in
                                Text(p.title).tag(p)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        Picker("Оценка времени", selection: $estimatedDuration) {
                            Text("Нет").tag(0)
                            ForEach([5,10,15,30,45,60], id: \.self) { m in Text("\(m) мин").tag(m) }
                        }
                    } label: {
                        Label("Подробности", systemImage: "slider.horizontal.3")
                    }
                    
                    DisclosureGroup(isExpanded: $showReminder) {
                        Toggle("Дедлайн", isOn: $hasDueDate.animation())
                        if hasDueDate {
                            DatePicker("Дата", selection: Binding(get: { dueDate ?? Date() }, set: { dueDate = $0 }), displayedComponents: [.date, .hourAndMinute])
                                .datePickerStyle(.compact)
                        }
                        
                        Toggle("Напоминание", isOn: $hasReminder.animation())
                        if hasReminder {
                            DatePicker("Когда", selection: Binding(get: { reminderDate ?? Date() }, set: { reminderDate = $0 }), displayedComponents: [.date, .hourAndMinute])
                                .datePickerStyle(.compact)
                            HStack(spacing: 8) {
                                Button("+30 мин") { reminderDate = Date().addingTimeInterval(30*60); hasReminder = true }
                                Button("+2 ч") { reminderDate = Date().addingTimeInterval(2*60*60); hasReminder = true }
                                Button("Завтра") {
                                    let cal = Calendar.current
                                    reminderDate = cal.date(byAdding: .day, value: 1, to: Date())
                                    hasReminder = true
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    } label: {
                        Label("Напоминание", systemImage: "bell")
                    }
                    
                    DisclosureGroup(isExpanded: $showMore) {
                        ForEach(Array(checklist.enumerated()), id: \.offset) { idx, _ in
                            TextField("Пункт \(idx+1)", text: Binding(
                                get: { checklist[idx] },
                                set: { checklist[idx] = $0 }
                            ))
                        }
                        Button("Добавить пункт") { checklist.append("") }
                            .buttonStyle(.bordered)
                    } label: {
                        Label("Ещё", systemImage: "ellipsis")
                    }
                }
            }
            .navigationTitle("Новый субтаск")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Добавить", action: addSubTask)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func addSubTask() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let newSubTask = SubTask(
            title: trimmedTitle,
            orderIndex: task.subTasks.count,
            estimatedDuration: estimatedDuration,
            notes: note.isEmpty ? nil : note,
            dueDate: hasDueDate ? dueDate : nil,
            reminderDate: hasReminder ? reminderDate : nil,
            priority: priority,
            checklist: checklist.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        )
        
        task.subTasks.append(newSubTask)
        hapticManager.completionSuccess()
        dismiss()
    }
}

// MARK: - SUBTASK FORM VIEW
struct SubTaskFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var subTask: SubTask
    
    @State private var title: String = ""
    @State private var estimatedDuration: Int = 0
    @State private var notes: String = ""
    
    private let hapticManager = HapticSoundManager.shared
    
    var body: some View {
        NavigationView {
            Form {
                Section("Subtask Details") {
                    TextField("Title", text: $title)
                        .textFieldStyle(.roundedBorder)
                    
                    HStack {
                        Text("Estimated Duration")
                        Spacer()
                        Stepper("\(estimatedDuration) min", value: $estimatedDuration, in: 0...999, step: 5)
                    }
                    
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .navigationTitle("Edit Subtask")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        hapticManager.selectionChanged()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveSubTask()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            loadSubTaskData()
        }
    }
    
    private func loadSubTaskData() {
        title = subTask.title
        estimatedDuration = subTask.estimatedDuration
        notes = subTask.notes ?? ""
    }
    
    private func saveSubTask() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        
        subTask.title = trimmedTitle
        subTask.estimatedDuration = estimatedDuration
        subTask.notes = notes.isEmpty ? nil : notes
        
        hapticManager.playHaptic(style: .medium)
        dismiss()
    }
}
