import SwiftUI
import SwiftData

// Presentation · Memo — тип «навыки»: дерево навыков, записи прогресса, редакторы.
// Оглавление: контекст sheet → модель → экран → детали/круг/прогресс/стат → sheet’ы.

// MARK: Контекст для sheet редактирования записи навыка
private struct SkillEntryEditContext: Identifiable {
    let id: UUID
    let skillID: UUID
    let entry: MemoSkillContent.SkillItem.SkillEntry
}

// MARK: Модель данных skills-мемо
struct MemoSkillContent: Codable, Hashable {
    var skills: [SkillItem] = []
    var iconName: String = "brain.head.profile"
    var customImageData: Data? = nil
    var colorHex: String = "#5E5CE6" // default indigo
    var sphereID: UUID? = nil
    var notes: String = ""
    var scale: Int = 10 // Максимальный уровень навыка
    var stepValue: Double = 1.0
    var currentLevel: Double = 0.0 // Текущий уровень для нового навыка
    var positiveImpact: Double = 0.0
    var negativeImpact: Double = 0.0
    var additionalImpacts: [SphereImpact] = []
    
    struct SkillItem: Codable, Hashable, Identifiable {
        var id: UUID = UUID()
        var name: String = ""
        var currentLevel: Double = 0.0
        var targetLevel: Double? = nil
        // Единицы измерения исключены, максимум шкалы задается целевым значением
        var iconName: String = "star.fill"
        var customImageData: Data? = nil
        var colorHex: String = "#5E5CE6" // default indigo
        var notes: String = ""
        var history: [SkillEntry] = []
        
        struct SkillEntry: Codable, Hashable, Identifiable {
            var id: UUID = UUID()
            var date: Date
            var level: Double
            var note: String = ""
        }
        
        var progress: Double {
            guard let target = targetLevel, target > 0 else { return 0 }
            return min(currentLevel / target, 1.0)
        }
    }
}

// MARK: Главный экран skills-мемо
struct SkillContentView: View {
    let item: MemoItem
    @Binding var showSkillStatistics: Bool
    
    @Environment(\.modelContext) private var modelContext
    @State private var skillContent: MemoSkillContent = MemoSkillContent()
    @State private var editingSkill: MemoSkillContent.SkillItem? = nil
    @State private var selectedStatsPeriod: MemoStatsPeriod = .month
    @State private var entryToDelete: (skillID: UUID, entry: MemoSkillContent.SkillItem.SkillEntry)? = nil
    @State private var entryToEdit: SkillEntryEditContext? = nil
    @State private var pendingLevel: Double? = nil
    @State private var iconPulseTrigger = UUID()
    @State private var repeatTimer: Timer? = nil
    @State private var repeatDirection: Int = 0
    @State private var skillForLevelEditor: MemoSkillContent.SkillItem? = nil
    @State private var levelEditorText: String = ""
    
    private let hapticManager = HapticSoundManager.shared
    
    private func effectiveStep() -> Double {
        let raw = skillContent.stepValue
        let positive = raw > 0 ? raw : 1.0
        return max(0.01, (positive * 100).rounded() / 100)
    }
    
    private func formatSkillLevel(_ level: Double) -> String {
        let step = effectiveStep()
        if step >= 1 || level.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", level)
        }
        let decimals = step < 0.01 ? 2 : (step < 0.1 ? 2 : 1)
        return String(format: "%.\(decimals)f", level)
    }
    
    private func filteredHistory(for skill: MemoSkillContent.SkillItem) -> [MemoSkillContent.SkillItem.SkillEntry] {
        guard let start = selectedStatsPeriod.startDate() else {
            return skill.history
        }
        return skill.history.filter { $0.date >= start }
    }
    
    // Computed property to get the single skill
    private var skill: MemoSkillContent.SkillItem? {
        return skillContent.skills.first
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                if let skill = skill {
                    skillDetailView(skill: skill)
                        .padding(.horizontal)
                        .padding(.top, 4)
                        .padding(.bottom, 16)
                }
            }
        }
        .onAppear {
            loadSkills()
            iconPulseTrigger = UUID()
            // If no skill exists, create one with the card's title
            if skillContent.skills.isEmpty {
                createInitialSkill()
            }
        }
        .onDisappear {
            stopRepeatTimer()
        }
        .sheet(item: $editingSkill) { skill in
            SkillEditorSheet(
                skill: skill,
                onSave: { updatedSkill in
                    updateSkill(updatedSkill)
                }
            )
        }
        .fullScreenCover(isPresented: $showSkillStatistics) {
            Group {
                if let skill = skill {
                let filtered = filteredHistory(for: skill)
                NavigationStack {
                    ScrollView {
                        VStack(spacing: 16) {
                            statisticsView(skill: skill)
                            if !filtered.isEmpty {
                                ChartView(
                                    data: filtered.sorted(by: { $0.date < $1.date }).map { ChartDataPoint(date: $0.date, value: $0.level) },
                                    title: skill.name,
                                    color: Color(hex: skill.colorHex),
                                    unit: ""
                                )
                                .frame(height: 200)
                            }
                        }
                        .padding()
                    }
                    .background(Color(UIColor.systemGroupedBackground))
                    .navigationTitle("Statistics")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showSkillStatistics = false
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                } else {
                    EmptyView()
                }
            }
        }
        .frostedDeleteConfirmation(
            isPresented: Binding(
                get: { entryToDelete != nil },
                set: { if !$0 { entryToDelete = nil } }
            ),
            title: "Delete history entry?",
            message: "This action cannot be undone.",
            onConfirm: {
                if let (skillID, entry) = entryToDelete,
                   let idx = skillContent.skills.firstIndex(where: { $0.id == skillID }) {
                    deleteSkillEntry(skill: skillContent.skills[idx], entry: entry)
                    entryToDelete = nil
                }
            }
        )
        .sheet(item: $entryToEdit) { ctx in
            SkillEntryEditSheet(
                entry: ctx.entry,
                maxLevel: skill?.targetLevel ?? Double(skillContent.scale),
                colorHex: skill?.colorHex ?? skillContent.colorHex,
                onSave: { updated in
                    if let idx = skillContent.skills.firstIndex(where: { $0.id == ctx.skillID }),
                       let entryIdx = skillContent.skills[idx].history.firstIndex(where: { $0.id == updated.id }) {
                        skillContent.skills[idx].history[entryIdx] = updated
                        if let last = skillContent.skills[idx].history.sorted(by: { $0.date > $1.date }).first {
                            skillContent.skills[idx].currentLevel = last.level
                            skillContent.currentLevel = last.level
                        }
                        saveSkills()
                    }
                    entryToEdit = nil
                },
                onCancel: {
                    entryToEdit = nil
                }
            )
        }
        .alert(
            "Change level",
            isPresented: Binding(
                get: { skillForLevelEditor != nil },
                set: { if !$0 { skillForLevelEditor = nil } }
            ),
            actions: {
                TextField("Enter level", text: $levelEditorText)
                    .keyboardType(.decimalPad)
                Button("Save") {
                    if let skill = skillForLevelEditor,
                       let newLevel = Double(levelEditorText.replacingOccurrences(of: ",", with: ".")) {
                        let maxAllowed = skill.targetLevel ?? Double(skillContent.scale)
                        let clamped = min(max(0, newLevel), maxAllowed)
                        updateSkillLevel(skill, newLevel: clamped)
                    }
                    skillForLevelEditor = nil
                }
                Button("Cancel", role: .cancel) {
                    skillForLevelEditor = nil
                }
            },
            message: {
                Text(skillForLevelEditor?.name ?? "")
            }
        )
    }
    
    // MARK: Детальный блок выбранного навыка
    @ViewBuilder
    private func skillDetailView(skill: MemoSkillContent.SkillItem) -> some View {
        let maxValue = skill.targetLevel ?? Double(max(1, skillContent.scale))
        let displayedLevel = pendingLevel ?? skill.currentLevel
        let step = effectiveStep()
        
        VStack(alignment: .leading, spacing: 16) {
            // Circle/Header View (like Counter)
            skillCircleView(skill: skill, displayedLevel: displayedLevel, maxValue: maxValue)
            
            // Slider (step-dependent)
            VStack(spacing: 12) {
                HStack {
                    Text("0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Slider(value: Binding(
                        get: { pendingLevel ?? skill.currentLevel },
                        set: { newValue in
                            let clamped = min(max(0, newValue), maxValue)
                            let stepped = (clamped / step).rounded() * step
                            pendingLevel = min(stepped, maxValue)
                        }
                    ), in: 0...maxValue, step: step)
                    .tint(Color(hex: skill.colorHex))
                    
                    Text("\(String(format: "%.0f", maxValue))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Control Buttons (like Counter - size 44)
                HStack(spacing: 20) {
                    Button {
                        applySkillStep(skill: skill, step: step, maxValue: maxValue, direction: -1)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(Color(hex: skill.colorHex))
                    }
                    .onLongPressGesture(minimumDuration: 0.4, pressing: { pressing in
                        if pressing {
                            startSkillRepeatTimer(skill: skill, step: step, maxValue: maxValue, direction: -1)
                        } else {
                            stopRepeatTimer()
                        }
                    }, perform: {})
                    
                    Spacer()
                    
                    Button {
                        presentLevelEditor(for: skill)
                    } label: {
                        Text(formatSkillLevel(displayedLevel))
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(Color(hex: skill.colorHex))
                    }
                    
                    Spacer()
                    
                    Button {
                        applySkillStep(skill: skill, step: step, maxValue: maxValue, direction: 1)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(Color(hex: skill.colorHex))
                    }
                    .onLongPressGesture(minimumDuration: 0.4, pressing: { pressing in
                        if pressing {
                            startSkillRepeatTimer(skill: skill, step: step, maxValue: maxValue, direction: 1)
                        } else {
                            stopRepeatTimer()
                        }
                    }, perform: {})
                }
                .padding(.horizontal, 40)
                
                if let pending = pendingLevel,
                   abs(pending - skill.currentLevel) > 0.0001 {
                    HStack(spacing: 20) {
                        Button("Cancel") {
                            pendingLevel = nil
                            hapticManager.playHaptic(style: .light)
                        }
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        Button("Accept") {
                            updateSkillLevel(skill, newLevel: pending)
                            pendingLevel = nil
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(hex: skill.colorHex))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 40)
                    .transition(.opacity)
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Progress to Target
            if let target = skill.targetLevel, target > 0 {
                skillProgressView(skill: skill, target: target)
            }
            
            // History (like Counter)
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(Color(hex: skill.colorHex))
                        Text("History")
                            .font(.headline)
                        Spacer()
                        Text("\(skill.history.count)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if skill.history.isEmpty {
                        Text("No history yet")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(UIColor.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        VStack(spacing: 12) {
                            ForEach(skill.history.sorted(by: { $0.date > $1.date }).prefix(10)) { entry in
                                HStack(spacing: 12) {
                                    Button {
                                        hapticManager.selectionChanged()
                                        entryToEdit = SkillEntryEditContext(id: entry.id, skillID: skill.id, entry: entry)
                                    } label: {
                                        HStack(spacing: 12) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(formatSkillLevel(entry.level))
                                                    .font(.subheadline.bold())
                                                Text(entry.date, style: .date)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            
                                            Spacer()
                                            
                                            if !entry.note.isEmpty {
                                                Text(entry.note)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                    .lineLimit(2)
                                            }
                                            
                                            Image(systemName: "pencil")
                                                .font(.body)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Button {
                                        hapticManager.playNotificationHaptic(type: .warning)
                                        entryToDelete = (skillID: skill.id, entry: entry)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.body)
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding()
                                .background(Color(UIColor.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .contextMenu {
                                    Button {
                                        entryToEdit = SkillEntryEditContext(id: entry.id, skillID: skill.id, entry: entry)
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        entryToDelete = (skillID: skill.id, entry: entry)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    // MARK: Круг прогресса по навыку
    private func skillCircleView(skill: MemoSkillContent.SkillItem, displayedLevel: Double, maxValue: Double) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                if let imageData = skill.customImageData ?? skillContent.customImageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .clipShape(Circle())
                        .iconPulseOnceOnAppear()
                } else {
                    Image(systemName: skill.iconName)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(Color(hex: skill.colorHex))
                        .symbolEffect(.pulse, options: .nonRepeating, value: iconPulseTrigger)
                }
                
                Text("Level \(formatSkillLevel(displayedLevel))\(skill.targetLevel != nil ? " / \(formatSkillLevel(maxValue))" : "")")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color(hex: skill.colorHex))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
                Spacer()
            }
            .padding()
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(hex: skill.colorHex).opacity(0.16))
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    // MARK: Полоса / числа прогресса
    private func skillProgressView(skill: MemoSkillContent.SkillItem, target: Double) -> some View {
        let displayedLevel = pendingLevel ?? skill.currentLevel
        return VStack(spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(Color(hex: skill.colorHex))
                        .font(.subheadline)
                    Text("Progress to target")
                        .font(.headline)
                }
                Spacer()
                Text("\(formatSkillLevel(displayedLevel)) / \(formatSkillLevel(target))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 12)
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: skill.colorHex))
                        .frame(
                            width: geometry.size.width * min(max(CGFloat(displayedLevel) / CGFloat(max(target, 0.0001)), 0), 1.0),
                            height: 12
                        )
                }
            }
            .frame(height: 12)
            
            Text("\(target > 0 ? Int(displayedLevel / max(target, 0.0001) * 100) : 0)%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: Мини-статистика
    @ViewBuilder
    private func statisticsView(skill: MemoSkillContent.SkillItem) -> some View {
        let filtered = filteredHistory(for: skill)
        VStack(spacing: 16) {
            MemoStatsPeriodSegmentedPicker(selection: $selectedStatsPeriod)
            
            Text("Statistics")
                .font(.headline)
            
            // Stats cards
            HStack(spacing: 12) {
                MemoStatisticMetricCard(
                    valueScalesDown: true,
                    title: "Current level",
                    value: String(format: "%.1f", skill.currentLevel),
                    icon: "star.fill",
                    color: Color(hex: skill.colorHex)
                )
                
                if skill.targetLevel != nil {
                    MemoStatisticMetricCard(
                        valueScalesDown: true,
                        title: "Progress",
                        value: String(format: "%.0f%%", skill.progress * 100),
                        icon: "target",
                        color: .blue
                    )
                }
                
                if !filtered.isEmpty {
                    MemoStatisticMetricCard(
                        valueScalesDown: true,
                        title: "Entries",
                        value: "\(filtered.count)",
                        icon: "clock.fill",
                        color: .indigo
                    )
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: Сохранение и форматирование
    private func loadSkills() {
        if let data = item.contentData,
           let content = try? JSONDecoder().decode(MemoSkillContent.self, from: data) {
            skillContent = content
        }
    }
    
    private func createInitialSkill() {
        let newSkill = MemoSkillContent.SkillItem(
            name: item.title,
            currentLevel: skillContent.currentLevel,
            targetLevel: nil,
            iconName: skillContent.iconName,
            customImageData: skillContent.customImageData,
            colorHex: skillContent.colorHex,
            notes: skillContent.notes,
            history: []
        )
        // Add initial history entry
        var skillWithHistory = newSkill
        skillWithHistory.history.append(
            MemoSkillContent.SkillItem.SkillEntry(
                date: Date(),
                level: skillContent.currentLevel,
                note: "Initial level"
            )
        )
        skillContent.skills = [skillWithHistory]
        saveSkills()
    }
    
    private func saveSkills() {
        if let data = try? JSONEncoder().encode(skillContent) {
            item.contentData = data
            try? modelContext.save()
        }
    }
    
    private func updateSkill(_ skill: MemoSkillContent.SkillItem) {
        if skillContent.skills.isEmpty {
            skillContent.skills = [skill]
        } else {
            skillContent.skills[0] = skill
        }
        // Update card title and content properties to match skill
        item.title = skill.name
        skillContent.currentLevel = skill.currentLevel
        skillContent.colorHex = skill.colorHex
        skillContent.iconName = skill.iconName
        skillContent.customImageData = skill.customImageData
        skillContent.notes = skill.notes
        hapticManager.playHaptic(style: .light)
        saveSkills()
    }
    
    private func applySkillStep(skill: MemoSkillContent.SkillItem, step: Double, maxValue: Double, direction: Int) {
        let base = pendingLevel ?? skill.currentLevel
        let raw = direction < 0 ? max(0, base - step) : min(maxValue, base + step)
        let stepped = (raw / step).rounded() * step
        pendingLevel = direction < 0 ? min(stepped, base) : min(stepped, maxValue)
        hapticManager.playHaptic(style: .light)
    }
    
    private func startSkillRepeatTimer(skill: MemoSkillContent.SkillItem, step: Double, maxValue: Double, direction: Int) {
        stopRepeatTimer()
        repeatDirection = direction
        let dir = repeatDirection
        repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            guard let currentSkill = skillContent.skills.first else { return }
            let s = effectiveStep()
            let maxV = currentSkill.targetLevel ?? Double(max(1, skillContent.scale))
            applySkillStep(skill: currentSkill, step: s, maxValue: maxV, direction: dir)
        }
        RunLoop.main.add(repeatTimer!, forMode: .common)
    }
    
    private func stopRepeatTimer() {
        repeatTimer?.invalidate()
        repeatTimer = nil
    }
    
    private func deleteSkillEntry(skill: MemoSkillContent.SkillItem, entry: MemoSkillContent.SkillItem.SkillEntry) {
        guard let idx = skillContent.skills.firstIndex(where: { $0.id == skill.id }) else { return }
        withAnimation {
            skillContent.skills[idx].history.removeAll { $0.id == entry.id }
            // Update currentLevel to last remaining entry
            if let last = skillContent.skills[idx].history.sorted(by: { $0.date > $1.date }).first {
                skillContent.skills[idx].currentLevel = last.level
                skillContent.currentLevel = last.level
            } else {
                skillContent.skills[idx].currentLevel = 0
                skillContent.currentLevel = 0
            }
        }
        hapticManager.playHaptic(style: .medium)
        saveSkills()
    }
    
    private func updateSkillLevel(_ skill: MemoSkillContent.SkillItem, newLevel: Double) {
        guard !skillContent.skills.isEmpty else { return }
        withAnimation {
            let maxAllowed = skillContent.skills[0].targetLevel ?? Double(skillContent.scale)
            let clampedLevel = min(max(0, newLevel), maxAllowed)
            skillContent.skills[0].currentLevel = clampedLevel
            skillContent.currentLevel = clampedLevel
            
            // Add history entry
            let entry = MemoSkillContent.SkillItem.SkillEntry(
                date: Date(),
                level: clampedLevel,
                note: ""
            )
            skillContent.skills[0].history.append(entry)
        }
        hapticManager.playHaptic(style: .light)
        saveSkills()
    }
    
    private func presentLevelEditor(for skill: MemoSkillContent.SkillItem) {
        skillForLevelEditor = skill
        levelEditorText = String(format: "%.1f", skill.currentLevel)
    }
}

// MARK: Sheet — правка записи истории навыка
struct SkillEntryEditSheet: View {
    let entry: MemoSkillContent.SkillItem.SkillEntry
    let maxLevel: Double
    let colorHex: String
    let onSave: (MemoSkillContent.SkillItem.SkillEntry) -> Void
    let onCancel: () -> Void
    
    @State private var editableLevel: Double
    @State private var editableNote: String
    
    init(entry: MemoSkillContent.SkillItem.SkillEntry, maxLevel: Double, colorHex: String, onSave: @escaping (MemoSkillContent.SkillItem.SkillEntry) -> Void, onCancel: @escaping () -> Void) {
        self.entry = entry
        self.maxLevel = maxLevel
        self.colorHex = colorHex
        self.onSave = onSave
        self.onCancel = onCancel
        _editableLevel = State(initialValue: min(max(0, entry.level), maxLevel))
        _editableNote = State(initialValue: entry.note)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(AppEditFormChrome.levelSectionTitle) {
                    Slider(value: $editableLevel, in: 0...max(1, maxLevel), step: 0.1)
                        .tint(Color(hex: colorHex))
                    Text(String(format: "%.1f", editableLevel))
                        .font(.headline)
                }
                
                Section(AppEditFormChrome.noteSectionTitle) {
                    TextEditor(text: $editableNote)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("Edit entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let updated = MemoSkillContent.SkillItem.SkillEntry(
                            id: entry.id,
                            date: entry.date,
                            level: min(max(0, editableLevel), maxLevel),
                            note: editableNote
                        )
                        onSave(updated)
                    }
                }
            }
        }
    }
}

// MARK: Sheet — редактор параметров навыка
struct SkillEditorSheet: View {
    let skill: MemoSkillContent.SkillItem?
    let onSave: (MemoSkillContent.SkillItem) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var currentLevel: Double
    @State private var targetLevel: String
    @State private var iconName: String
    @State private var customImageData: Data?
    @State private var colorHex: String
    @State private var notes: String
    
    init(skill: MemoSkillContent.SkillItem?, onSave: @escaping (MemoSkillContent.SkillItem) -> Void) {
        self.skill = skill
        self.onSave = onSave
        
        _name = State(initialValue: skill?.name ?? "")
        _currentLevel = State(initialValue: skill?.currentLevel ?? 0.0)
        _targetLevel = State(initialValue: skill?.targetLevel != nil ? "\(skill!.targetLevel!)" : "")
        
        _iconName = State(initialValue: skill?.iconName ?? "star.fill")
        _customImageData = State(initialValue: skill?.customImageData)
        _colorHex = State(initialValue: skill?.colorHex ?? "#5E5CE6")
        _notes = State(initialValue: skill?.notes ?? "")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(AppEditFormChrome.generalSectionTitle) {
                    TextField("skill name", text: $name)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current level")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Slider(value: $currentLevel, in: 0...(Double(targetLevel) ?? 100.0), step: 0.1)
                            Text(String(format: "%.1f", currentLevel))
                                .font(.headline)
                                .frame(width: 50)
                        }
                    }
                    
                    TextField("target level (optional)", text: $targetLevel)
                        .keyboardType(.decimalPad)
                }
                
                // Максимум шкалы задается целевым значением, единицы измерения убраны
                
                Section(AppEditFormChrome.additionalSectionTitle) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        TextEditor(text: $notes)
                            .frame(minHeight: 80)
                    }
                }
                
                Section(AppEditFormChrome.appearanceSectionTitle) {
                    MediaCirclePicker(
                        config: MediaCirclePickerConfiguration(
                            dialogTitle: "Skill media",
                            tintHex: colorHex,
                            size: 72,
                            fallbackIconName: "star.fill"
                        ),
                        imageData: $customImageData,
                        iconName: Binding(
                            get: { Optional(iconName) },
                            set: { newValue in
                                if let newValue { iconName = newValue }
                            }
                        )
                    )
                    
                    ColorPicker("Color", selection: Binding(
                        get: { Color(hex: colorHex) },
                        set: { colorHex = $0.toHex() ?? "#5E5CE6" }
                    ))
                }
            }
            .navigationTitle(skill == nil ? "New Skill" : "Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSkill()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
    
    private func saveSkill() {
        var newSkill = skill ?? MemoSkillContent.SkillItem()
        newSkill.name = name
        newSkill.currentLevel = currentLevel
        newSkill.targetLevel = Double(targetLevel)
        
        newSkill.iconName = iconName
        newSkill.customImageData = customImageData
        newSkill.colorHex = colorHex
        newSkill.notes = notes
        
        // Add initial history entry if new skill
        if skill == nil {
            newSkill.history.append(
                MemoSkillContent.SkillItem.SkillEntry(
                    date: Date(),
                    level: currentLevel,
                    note: "Initial level"
                )
            )
        }
        
        onSave(newSkill)
        dismiss()
    }
}
