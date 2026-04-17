import SwiftUI
import SwiftData
import PhotosUI

// Presentation · Goals — форма создания/редактирования цели (sheet с родительского списка).
// Пишет в SwiftData через `modelContext`; валидация и бизнес-правила списка — в use case на `AllGoalsView`, не здесь.
// Справочник архитектуры: `Core/ArchitectureStagesAndMap.swift`.

// MARK: - ADD/EDIT GOAL VIEW
struct EditGoalView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var spheres: [Sphere]
    @Query(sort: [SortDescriptor(\Goal.orderIndex, order: .forward)]) private var allGoals: [Goal]
    @Binding var goalToEdit: Goal?
    
    @State private var title: String = ""
    @State private var descript: String = ""
    @State private var imageData: Data?
    @State private var colorHex: String = AppConstants.Colors.palette.first!
    @State private var colorForPicker: Color = Color(hex: AppConstants.Colors.palette.first!)
    @State private var dueDate: Date?
    @State private var reward: String = ""
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
    @State private var iconName: String? = nil
    @State private var showDeleteGoalConfirmation: Bool = false
    @State private var showArchiveGoalConfirmation: Bool = false
    
    let allGoalsCount: Int
    var onSaveWithDate: ((Date?) -> Void)? = nil
    
    private let hapticManager = HapticSoundManager.shared
    
    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private let descriptionMaxLength = 100
    private let rewardMaxLength = 30
    private let goalMediaSize: CGFloat = 100
    
    private var goalMediaRowHeight: CGFloat {
        // MediaCirclePicker draws a ring of (size + 10).
        // Add a little vertical breathing room to avoid clipping inside Form rows.
        goalMediaSize + 18
    }
    
    private var descriptionHeight: CGFloat {
        // More compact than before: keep the form tight.
        let lineCount = max(1, (descript.count + 44) / 45)
        return max(44, min(84, CGFloat(lineCount) * 20))
    }
    
    private var descriptBinding: Binding<String> {
        Binding(
            get: { descript },
            set: { newValue in
                descript = String(newValue.prefix(descriptionMaxLength))
            }
        )
    }
    
    private var rewardBinding: Binding<String> {
        Binding(
            get: { reward },
            set: { newValue in
                reward = String(newValue.prefix(rewardMaxLength))
            }
        )
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(AppEditFormChrome.basicSectionTitle) {
                    HStack(alignment: .center, spacing: 8) {
                        TextField("title", text: $title)
                        Button {
                            isFlagged.toggle()
                            hapticManager.selectionChanged()
                        } label: {
                            Image(systemName: isFlagged ? "star.fill" : "star")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(importantStarTint)
                                .frame(width: 44, height: 40)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isFlagged ? "Important, on" : "Mark as important")
                    }
                    
                    HStack(alignment: .center, spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            ZStack(alignment: .topLeading) {
                                if descript.isEmpty {
                                    Text("description")
                                        .foregroundColor(.placeholderColor)
                                        .padding(.top, 8)
                                        .padding(.leading, 5)
                                        .allowsHitTesting(false)
                                }
                                TextEditor(text: descriptBinding)
                                    .frame(height: goalMediaRowHeight)
                                    .scrollContentBackground(.hidden)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        MediaCirclePicker(
                            dialogTitle: "Goal media",
                            tintHex: colorHex,
                            size: goalMediaSize,
                            fallbackIconName: goalFallbackIconName,
                            imageData: $imageData,
                            iconName: $iconName
                        )
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                
                AreaImpactSection(
                    selectedSphereID: $selectedSphereID,
                    positiveImpact: $positiveImpact,
                    negativeImpact: $negativeImpact,
                    colorHex: $colorHex,
                    colorForPicker: $colorForPicker
                ) { _, amount in
                    applyMissDecreaseForGoal(amount: amount)
                }
                
                Section(AppEditFormChrome.detailsSectionTitle) {
                    if let date = dueDate {
                        HStack(spacing: 8) {
                            EditFormDetailLeadingIcon(systemName: "calendar")
                            Text("Due Date")
                            DatePicker(
                                "",
                                selection: Binding(get: { date }, set: { dueDate = $0 }),
                                displayedComponents: .date
                            )
                            .accessibilityLabel("Due Date")
                            Spacer(minLength: 0)
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
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            EditFormDetailLeadingIcon(systemName: "trophy.fill")
                            TextField("reward", text: rewardBinding)
                        }
                    }
                }
                
                
                Section {
                    MemoTagsSelectionView(selectedTags: $tags)
                } header: {
                    Text(AppEditFormChrome.tagsSectionTitle)
                }
                
                if goalToEdit != nil {
                    Section {
                        Button {
                            showArchiveGoalConfirmation = true
                        } label: {
                            Label(
                                (goalToEdit?.status == .archived) ? "Unarchive" : "Archive",
                                systemImage: (goalToEdit?.status == .archived) ? "tray.and.arrow.up" : "archivebox"
                            )
                        }
                        .tint(.gray)
                        
                        Button(role: .destructive) {
                            showDeleteGoalConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
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
                    if goalToEdit == nil {
                        colorHex = AppConstants.Colors.palette.first ?? "#3498db"
                    }
                } else if goalToEdit == nil, let sid = newVal, let sphere = spheres.first(where: { $0.id == sid }) {
                    // Не перезаписывать пользовательский цвет — только подставлять цвет сферы как дефолт при первом выборе
                    let defaultColor = AppConstants.Colors.palette.first ?? "#3498db"
                    if colorHex == defaultColor {
                        colorHex = sphere.colorHex
                    }
                }
            }
            .overlay {
                if showArchiveGoalConfirmation, let goal = goalToEdit {
                    let allowSecondary = goal.status != .archived
                    ImpactActionPresenter.dialog(
                        isPresented: $showArchiveGoalConfirmation,
                        spheres: spheres,
                        sphereID: goal.sphereID,
                        negativeImpact: goal.negativeImpact,
                        allowSecondaryAction: allowSecondary,
                        title: goal.status == .archived ? "Unarchive goal?" : "Archive goal?",
                        message: goal.status == .archived ? "This goal will return to the active list." : "This goal will be archived.",
                        messageWithImpact: "Archive this goal. You can also apply its miss decrease to the area.",
                        primaryTitle: goal.status == .archived ? "Unarchive" : "Archive",
                        primaryTint: .gray,
                        secondaryTitleFormat: "Archive and apply negative impact (-%@%%) on area",
                        secondaryTint: .gray,
                        onPrimary: {
                            archiveGoal(goal, applyNegativeImpact: false)
                            dismiss()
                        },
                        onSecondary: {
                            archiveGoal(goal, applyNegativeImpact: true)
                            dismiss()
                        },
                        onCancel: { }
                    )
                }
            }
            .overlay {
                if showDeleteGoalConfirmation, let goal = goalToEdit {
                    ImpactActionPresenter.dialog(
                        isPresented: $showDeleteGoalConfirmation,
                        spheres: spheres,
                        sphereID: goal.sphereID,
                        negativeImpact: goal.negativeImpact,
                        title: "Delete goal?",
                        message: "This goal will be permanently deleted.",
                        messageWithImpact: "Delete this goal. You can also apply its miss decrease to the area.",
                        primaryTitle: "Delete",
                        primaryTint: .red,
                        secondaryTitleFormat: "Delete and apply negative impact (-%@%%) on area",
                        secondaryTint: .red,
                        onPrimary: {
                            goalToEdit = nil
                            modelContext.delete(goal)
                            try? modelContext.save()
                            dismiss()
                        },
                        onSecondary: {
                            applyMissDecreaseForGoal(amount: goal.negativeImpact)
                            goalToEdit = nil
                            modelContext.delete(goal)
                            try? modelContext.save()
                            dismiss()
                        },
                        onCancel: { }
                    )
                }
            }
        }
    }
    
    private func loadGoalData() {
        if let goal = goalToEdit {
            title = goal.title
            let rawDescript = goal.descript ?? ""
            descript = String(rawDescript.prefix(descriptionMaxLength))
            reward = String((goal.reward ?? "").prefix(rewardMaxLength))
            imageData = goal.imageData
            iconName = goal.iconName
            let sphere = goal.sphereID.flatMap { sid in spheres.first { $0.id == sid } }
            colorHex = goal.colorHex ?? sphere?.colorHex ?? AppConstants.Colors.palette.first!
            dueDate = goal.dueDate
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
        iconName = nil
        colorHex = AppConstants.Colors.palette.first ?? "#3498db"
        dueDate = nil
        reward = ""
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
            // Создаём новый Tag для каждой цели — переиспользование существующего
            // приводило к "переезду" тега с первой цели на вторую при выборе того же тега
            let newTag = Tag(name: normalized)
            modelContext.insert(newTag)
            goalTags.append(newTag)
        }
        
        if let goal = goalToEdit {
            let wasFlagged = goal.isFlagged
            goal.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            goal.descript = descript.isEmpty ? nil : descript
            goal.imageData = imageData
            goal.iconName = iconName
            goal.colorHex = colorHex
            goal.dueDate = dueDate
            goal.reward = reward.isEmpty ? nil : reward
            goal.subtasks = subtasks
            goal.counters = counters
            goal.tags = goalTags
            goal.sphereID = selectedSphereID
            goal.positiveImpact = positiveImpact
            goal.negativeImpact = negativeImpact
            goal.isFlagged = isFlagged
            if isFlagged && !wasFlagged {
                let maxO = allGoals.filter { $0.isFlagged && $0.id != goal.id }.map(\.visionGridOrder).max() ?? -1
                goal.visionGridOrder = maxO + 1
            } else if !isFlagged {
                goal.visionGridOrder = 0
            }
        } else {
            // New goals should appear at the top while preserving manual reordering.
            // We shift all existing goals down by 1 and place the new goal at index 0.
            for goal in allGoals {
                goal.orderIndex += 1
            }
            let newGoal = Goal(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                description: descript.isEmpty ? nil : descript,
                imageData: imageData,
                iconName: iconName,
                colorHex: colorHex,
                dueDate: dueDate,
                reward: reward.isEmpty ? nil : reward,
                status: .pending,
                orderIndex: 0,
                subtasks: subtasks,
                counters: counters,
                sphereID: selectedSphereID,
                positiveImpact: positiveImpact,
                negativeImpact: negativeImpact,
                isFlagged: isFlagged,
                visionGridOrder: isFlagged ? nextVisionGridOrderForNewGoal() : 0
            )
            newGoal.tags = goalTags
            modelContext.insert(newGoal)
        }
        try? modelContext.save()
        TagMaintenanceService.pruneUnusedTags(modelContext: modelContext)
        // Синхронизируем календарь, чтобы сохранённая цель оставалась видимой (фильтр по dueDate/creationDate)
        let dateForCalendar = dueDate ?? goalToEdit?.creationDate ?? Date()
        onSaveWithDate?(dateForCalendar)
    }

    private var goalFallbackIconName: String {
        let sid = selectedSphereID ?? goalToEdit?.sphereID
        return sid.flatMap { id in spheres.first(where: { $0.id == id })?.iconName } ?? "trophy"
    }
    
    /// Star tint when Important (`isFlagged`): linked sphere color, else secondary.
    private var importantStarTint: Color {
        guard isFlagged else { return Color.secondary }
        let sid = selectedSphereID ?? goalToEdit?.sphereID
        if let sid, let sphere = spheres.first(where: { $0.id == sid }) {
            return Color(hex: sphere.colorHex)
        }
        return Color(hex: colorHex)
    }
    
    private func nextVisionGridOrderForNewGoal() -> Int {
        let maxO = allGoals.filter(\.isFlagged).map(\.visionGridOrder).max() ?? -1
        return maxO + 1
    }

    /// Применяет Miss Decrease к сфере, связанной с целью (goalToEdit?.sphereID ?? selectedSphereID).
    private func applyMissDecreaseForGoal(amount: Double) {
        let sphereID = goalToEdit?.sphereID ?? selectedSphereID
        guard let sid = sphereID, let sphere = spheres.first(where: { $0.id == sid }) else { return }
        let clamped = max(0.0, min(100.0, amount))
        sphere.satisfaction = max(0.0, min(100.0, sphere.satisfaction - clamped))
        try? modelContext.save()
        NotificationCenter.default.postAppEvent(.goalStatusDidChange)
        NotificationCenter.default.postAppEvent(.sphereSatisfactionDidChange)
    }
    
    private func archiveGoal(_ goal: Goal, applyNegativeImpact: Bool) {
        let willArchive = goal.status != .archived
        if willArchive && applyNegativeImpact {
            applyMissDecreaseForGoal(amount: goal.negativeImpact)
            NotificationCenter.default.postAppEvent(.sphereSatisfactionDidChange)
        }
        
        goal.updateStatus(to: willArchive ? .archived : .pending)
        try? modelContext.save()
        NotificationCenter.default.postAppEvent(.goalStatusDidChange)
    }
    
}

