import SwiftUI
import SwiftData

// MARK: - Skill Content Model
struct MemoSkillContent: Codable, Hashable {
    var skills: [SkillItem] = []
    var iconName: String = "brain.head.profile"
    var customImageData: Data? = nil
    var colorHex: String = "#5E5CE6" // default indigo
    var sphereID: UUID? = nil
    var notes: String = ""
    var scale: Int = 10 // Максимальный уровень навыка
    var currentLevel: Double = 0.0 // Текущий уровень для нового навыка
    
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

// MARK: - Skill Content View
struct SkillContentView: View {
    let item: MemoItem
    @Binding var showSkillStatistics: Bool
    
    @Environment(\.modelContext) private var modelContext
    @State private var skillContent: MemoSkillContent = MemoSkillContent()
    @State private var editingSkill: MemoSkillContent.SkillItem? = nil
    
    private let hapticManager = HapticSoundManager.shared
    
    // Computed property to get the single skill
    private var skill: MemoSkillContent.SkillItem? {
        return skillContent.skills.first
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Statistics View
            if showSkillStatistics, let skill = skill, !skill.history.isEmpty {
                statisticsView(skill: skill)
                    .padding()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            ScrollView {
                if let skill = skill {
                    skillDetailView(skill: skill)
                        .padding()
                }
            }
        }
        .onAppear {
            loadSkills()
            // If no skill exists, create one with the card's title
            if skillContent.skills.isEmpty {
                createInitialSkill()
            }
        }
        .sheet(item: $editingSkill) { skill in
            SkillEditorSheet(
                skill: skill,
                onSave: { updatedSkill in
                    updateSkill(updatedSkill)
                }
            )
        }
    }
    
    // MARK: - Skill Detail View
    @ViewBuilder
    private func skillDetailView(skill: MemoSkillContent.SkillItem) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color(hex: skill.colorHex).opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    if let imageData = skill.customImageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: skill.iconName)
                            .font(.title2)
                            .foregroundColor(Color(hex: skill.colorHex))
                    }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(skill.name)
                        .font(.title2.bold())
                    
                    if let target = skill.targetLevel {
                        Text("\(String(format: "%.1f", skill.currentLevel))/\(String(format: "%.1f", target))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Уровень: \(String(format: "%.1f", skill.currentLevel))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button {
                    editingSkill = skill
                } label: {
                    Image(systemName: "pencil")
                        .font(.title3)
                        .foregroundColor(.blue)
                        .padding(8)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            
            // Progress Bar
            if skill.targetLevel != nil {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 12)
                        
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: skill.colorHex))
                            .frame(width: geometry.size.width * skill.progress, height: 12)
                    }
                }
                .frame(height: 12)
            }
            
            // Level Control
            VStack(spacing: 12) {
                // Slider
                HStack {
                    Text("0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    let maxValue = skill.targetLevel ?? Double(skillContent.scale)
                    Slider(value: Binding(
                        get: { skill.currentLevel },
                        set: { newValue in
                            updateSkillLevel(skill, newLevel: newValue)
                        }
                    ), in: 0...maxValue, step: 0.1)
                    .tint(Color(hex: skill.colorHex))
                    
                    Text("\(String(format: "%.0f", maxValue))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Buttons
                HStack(spacing: 12) {
                    Button {
                        updateSkillLevel(skill, newLevel: max(0, skill.currentLevel - 0.1))
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .foregroundColor(Color(hex: skill.colorHex))
                    }
                    
                    Spacer()
                    
                    // Current Level (tap to edit)
                    Button {
                        showLevelEditor(for: skill)
                    } label: {
                        Text(String(format: "%.1f", skill.currentLevel))
                            .font(.title.bold())
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    Button {
                        let maxValue = skill.targetLevel ?? Double(skillContent.scale)
                        updateSkillLevel(skill, newLevel: min(maxValue, skill.currentLevel + 0.1))
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(Color(hex: skill.colorHex))
                    }
                }
            }
            
            // Notes
            if !skill.notes.isEmpty {
                Text(skill.notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // Full History
            VStack(alignment: .leading, spacing: 12) {
                Text("История")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if skill.history.isEmpty {
                    Text("История пока пуста")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    ForEach(skill.history.sorted(by: { $0.date > $1.date })) { entry in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.date, style: .date)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                
                                if !entry.note.isEmpty {
                                    Text(entry.note)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Text(String(format: "%.1f", entry.level))
                                .font(.headline)
                                .foregroundColor(Color(hex: skill.colorHex))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(hex: skill.colorHex).opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }
    
    // MARK: - Statistics View
    @ViewBuilder
    private func statisticsView(skill: MemoSkillContent.SkillItem) -> some View {
        VStack(spacing: 16) {
            Text("Статистика")
                .font(.headline)
            
            // Chart
            if !skill.history.isEmpty {
                ChartView(
                    data: skill.history.map { ChartDataPoint(date: $0.date, value: $0.level) },
                    title: skill.name,
                    color: Color(hex: skill.colorHex),
                    unit: ""
                )
                .frame(height: 200)
            }
            
            // Stats cards
            HStack(spacing: 12) {
                SkillStatCard(
                    title: "Текущий уровень",
                    value: String(format: "%.1f", skill.currentLevel),
                    icon: "star.fill",
                    color: Color(hex: skill.colorHex)
                )
                
                if let target = skill.targetLevel {
                    SkillStatCard(
                        title: "Прогресс",
                        value: String(format: "%.0f%%", skill.progress * 100),
                        icon: "chart.bar.fill",
                        color: .blue
                    )
                }
                
                if !skill.history.isEmpty {
                    SkillStatCard(
                        title: "Записей",
                        value: "\(skill.history.count)",
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
    
    // MARK: - Helper Methods
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
                note: "Начальный уровень"
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
    
    private func showLevelEditor(for skill: MemoSkillContent.SkillItem) {
        let alert = UIAlertController(title: "Изменить уровень", message: skill.name, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.text = String(format: "%.1f", skill.currentLevel)
            textField.keyboardType = .decimalPad
            textField.placeholder = "Введите уровень"
        }
        
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Сохранить", style: .default) { _ in
            if let text = alert.textFields?.first?.text,
               let newLevel = Double(text) {
                let maxAllowed = skill.targetLevel ?? Double(skillContent.scale)
                let clamped = min(max(0, newLevel), maxAllowed)
                updateSkillLevel(skill, newLevel: clamped)
            }
        })
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alert, animated: true)
        }
    }
}

// MARK: - Skill Stat Card
struct SkillStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3.bold())
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Skill Editor Sheet
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
    @State private var showIconPicker = false
    
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
                Section("Основное") {
                    TextField("Название навыка", text: $name)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Текущий уровень")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Slider(value: $currentLevel, in: 0...(Double(targetLevel) ?? 100.0), step: 0.1)
                            Text(String(format: "%.1f", currentLevel))
                                .font(.headline)
                                .frame(width: 50)
                        }
                    }
                    
                    TextField("Целевой уровень (опционально)", text: $targetLevel)
                        .keyboardType(.decimalPad)
                }
                
                // Максимум шкалы задается целевым значением, единицы измерения убраны
                
                Section("Дополнительно") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Заметки")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        TextEditor(text: $notes)
                            .frame(minHeight: 80)
                    }
                }
                
                Section("Внешний вид") {
                    Button {
                        showIconPicker = true
                    } label: {
                        HStack {
                            Text("Иконка")
                            Spacer()
                            if let imageData = customImageData,
                               let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24, height: 24)
                            } else {
                                Image(systemName: iconName)
                                    .foregroundColor(Color(hex: colorHex))
                            }
                        }
                    }
                    
                    ColorPicker("Цвет", selection: Binding(
                        get: { Color(hex: colorHex) },
                        set: { colorHex = $0.toHex() ?? "#5E5CE6" }
                    ))
                }
            }
            .navigationTitle(skill == nil ? "Новый навык" : "Редактировать")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        saveSkill()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showIconPicker) {
                IconPickerView(
                    selectedIcon: $iconName,
                    isPresented: $showIconPicker
                )
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
                    note: "Начальный уровень"
                )
            )
        }
        
        onSave(newSkill)
        dismiss()
    }
}
