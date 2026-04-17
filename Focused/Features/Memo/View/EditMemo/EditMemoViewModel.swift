import SwiftUI
import SwiftData
import Foundation

// MARK: ViewModel формы — декодирование контента, сохранение, вспомогательная логика
class EditMemoViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var descript: String = ""
    @Published var selectedTags: [String] = []

    // Content states
    @Published var noteAlbumContent: MemoNoteAlbumContent = MemoNoteAlbumContent()
    @Published var noteAlbumColorHex: String = "#007AFF" // Default iOS blue
    @Published var noteAlbumColorForPicker: Color = .blue
    @Published var noteAlbumSphereID: UUID? = nil
    @Published var noteAlbumColorManuallyChanged: Bool = false
    var isUpdatingColorFromSphere: Bool = false
    
    // List content
    @Published var listContent: MemoListContent = MemoListContent()
    @Published var listColorHex: String = "#34C759" // Default green
    @Published var listColorForPicker: Color = .green
    @Published var listColorManuallyChanged: Bool = false
    var isUpdatingListColorFromSphere: Bool = false

    // Counter content
    @Published var counterContent: MemoCounterContent = MemoCounterContent()
    @Published var counterColorHex: String = "#FF9500" // Default orange
    @Published var counterColorForPicker: Color = .orange
    @Published var counterColorManuallyChanged: Bool = false
    var isUpdatingCounterColorFromSphere: Bool = false

    // Streak content
    @Published var streakContent: MemoStreakContent = MemoStreakContent()
    @Published var streakColorHex: String = "#FF3B30" // Default red
    @Published var streakColorForPicker: Color = .red
    @Published var streakColorManuallyChanged: Bool = false
    var isUpdatingStreakColorFromSphere: Bool = false
    
    // Mood content
    @Published var moodContent: MemoMoodContent = MemoMoodContent()
    @Published var moodColorHex: String = "#FF2D55" // Default iOS pink
    @Published var moodColorForPicker: Color = .pink
    @Published var moodColorManuallyChanged: Bool = false
    var isUpdatingMoodColorFromSphere: Bool = false
    @Published var tempMoodValue: Double = 5.0
    @Published var savedMoodValue: Double = 5.0
    @Published var skillContent: MemoSkillContent = MemoSkillContent()
    @Published var skillColorHex: String = "#5E5CE6" // Default indigo
    @Published var skillColorForPicker: Color = .indigo
    @Published var skillColorManuallyChanged: Bool = false
    var isUpdatingSkillColorFromSphere: Bool = false
    @Published var tempSkillLevel: Double = 0.0
    @Published var savedSkillLevel: Double = 0.0
    @Published var budgetContent: MemoBudgetContent = MemoBudgetContent()
    @Published var budgetColorHex: String = "#00C7BE" // Default mint
    @Published var budgetColorForPicker: Color = Color(hex: "#00C7BE")
    @Published var budgetColorManuallyChanged: Bool = false
    var isUpdatingBudgetColorFromSphere: Bool = false
    
    // Time content
    @Published var timeContent: MemoTimeContent = MemoTimeContent()
    @Published var timeColorHex: String = "#0A84FF" // Default blue
    @Published var timeColorForPicker: Color = .blue
    @Published var timeColorManuallyChanged: Bool = false
    var isUpdatingTimeColorFromSphere: Bool = false
    
    // Health content
    @Published var healthContent: MemoHealthContent = MemoHealthContent()
    @Published var healthColorHex: String = "#E6332A" // Default red
    @Published var healthColorForPicker: Color = .red
    @Published var healthColorManuallyChanged: Bool = false
    var isUpdatingHealthColorFromSphere: Bool = false
    
    // Calendar content
    @Published var calendarContent: MemoCalendarContent = MemoCalendarContent()
    @Published var calendarColorHex: String = "#5856D6" // iOS purple
    @Published var calendarColorForPicker: Color = Color(hex: "#5856D6")
    @Published var calendarColorManuallyChanged: Bool = false
    var isUpdatingCalendarColorFromSphere: Bool = false

    // UI states (removed showStreakIconPicker as we use IconSelectionView now)

    private let memoToEdit: MemoItem?
    private let memoType: MemoItemType

    init(memoToEdit: MemoItem?, memoType: MemoItemType) {
        self.memoToEdit = memoToEdit
        self.memoType = memoType

        if let existingMemo = memoToEdit {
            loadExistingMemoData(existingMemo)
        } else {
            initializeNewMemoData()
        }
    }

    private func loadExistingMemoData(_ memo: MemoItem) {
        title = memo.title
        descript = memo.descript ?? ""
        selectedTags = memo.tags

        switch memo.itemType {
        case .noteAlbum:
            if let data = memo.contentData {
                // Try MemoNoteAlbumContent first (saved by Edit Memo)
                if let content = try? JSONDecoder().decode(MemoNoteAlbumContent.self, from: data) {
                    noteAlbumContent = content
                    noteAlbumColorHex = content.colorHex
                    noteAlbumColorForPicker = Color(hex: content.colorHex)
                    noteAlbumSphereID = content.sphereID
                } else if let albumItems = try? JSONDecoder().decode([MemoNoteAlbumItem].self, from: data) {
                    let noteItems = albumItems.enumerated().map { idx, item in
                        MemoNoteAlbumContent.NoteItem(
                            id: item.id,
                            title: item.title,
                            content: item.content,
                            creationDate: item.creationDate,
                            lastModified: item.lastModified,
                            tags: [],
                            isArchived: item.isArchived,
                            orderIndex: item.orderIndex
                        )
                    }
                    var content = MemoNoteAlbumContent()
                    content.notes = noteItems
                    noteAlbumContent = content
                    noteAlbumColorHex = content.colorHex
                    noteAlbumColorForPicker = Color(hex: content.colorHex)
                    noteAlbumSphereID = nil
                } else if let text = try? JSONDecoder().decode(String.self, from: data) {
                    noteAlbumContent = MemoNoteAlbumContent(notes: [MemoNoteAlbumContent.NoteItem(title: "", content: text)])
                    noteAlbumColorHex = noteAlbumContent.colorHex
                    noteAlbumColorForPicker = Color(hex: noteAlbumContent.colorHex)
                    noteAlbumSphereID = nil
                }
            }
        case .list:
            if let data = memo.contentData {
                // Сначала попробуем загрузить новую структуру
                if let content = try? JSONDecoder().decode(MemoListContent.self, from: data) {
                    listContent = content
                    listColorHex = content.colorHex
                    listColorForPicker = Color(hex: content.colorHex)
                } else if let items = try? JSONDecoder().decode([MemoListItem].self, from: data) {
                    // Для обратной совместимости - конвертируем старый массив в новую структуру
                    listContent = MemoListContent(items: items, colorHex: listColorHex)
                    listColorForPicker = Color(hex: listColorHex)
                }
            }
        case .counter:
            if let data = memo.contentData, let content = try? JSONDecoder().decode(MemoCounterContent.self, from: data) {
                var mutable = content
                // нормализуем шаг: минимум 0.01 и не более 2 знаков после запятой
                let raw = mutable.stepValue
                let positive = raw > 0 ? raw : 1
                let clamped = max(0.01, positive)
                mutable.stepValue = (clamped * 100).rounded() / 100
                counterContent = mutable
                counterColorHex = content.colorHex
                counterColorForPicker = Color(hex: content.colorHex)
            }
        case .streak:
            if let data = memo.contentData, var content = try? JSONDecoder().decode(MemoStreakContent.self, from: data) {
                if content.targetStreak == nil {
                    let digits = content.goal.compactMap { $0.wholeNumberValue }
                    if !digits.isEmpty {
                        let value = digits.reduce(0) { $0 * 10 + $1 }
                        if value > 0 { content.targetStreak = value }
                    }
                }
                streakContent = content
                streakColorHex = content.colorHex
                streakColorForPicker = Color(hex: content.colorHex)
            }
        case .mood:
            if let data = memo.contentData, let content = try? JSONDecoder().decode(MemoMoodContent.self, from: data) {
                moodContent = content
                moodContent.scale = 10
                moodColorHex = content.colorHex
                moodColorForPicker = Color(hex: content.colorHex)
                tempMoodValue = 5.0
                savedMoodValue = 5.0
            }
        case .skill:
            if let data = memo.contentData, let content = try? JSONDecoder().decode(MemoSkillContent.self, from: data) {
                skillContent = content
                // Ensure scale is valid
                if skillContent.scale < 1 {
                    skillContent.scale = 10
                }
                skillColorHex = content.colorHex
                skillColorForPicker = Color(hex: content.colorHex)
                let validScale = max(1, skillContent.scale)
                
                // If no skills exist, create one with card title
                if skillContent.skills.isEmpty {
                    let newSkill = MemoSkillContent.SkillItem(
                        name: memo.title,
                        currentLevel: skillContent.currentLevel,
                        targetLevel: nil,
                        iconName: skillContent.iconName,
                        customImageData: skillContent.customImageData,
                        colorHex: skillColorHex,
                        notes: skillContent.notes,
                        history: []
                    )
                    skillContent.skills = [newSkill]
                    tempSkillLevel = min(Double(validScale), max(0.0, skillContent.currentLevel))
                } else {
                    // Use first skill's level
                    tempSkillLevel = min(Double(validScale), max(0.0, skillContent.skills[0].currentLevel))
                }
                savedSkillLevel = tempSkillLevel
            }
        case .budget:
            if let data = memo.contentData, let content = try? JSONDecoder().decode(MemoBudgetContent.self, from: data) {
                budgetContent = content
                budgetColorHex = content.colorHex
                budgetColorForPicker = Color(hex: content.colorHex)
                
                // If no budgets exist, create one with card title
                if budgetContent.budgets.isEmpty {
                    let newBudget = MemoBudgetContent.BudgetItem(
                        name: memo.title,
                        currentBalance: budgetContent.initialBalance,
                        iconName: budgetContent.iconName,
                        customImageData: budgetContent.customImageData,
                        colorHex: budgetColorHex,
                        notes: budgetContent.notes,
                        transactions: []
                    )
                    budgetContent.budgets = [newBudget]
                }
            }
        case .time:
            if let data = memo.contentData, let content = try? JSONDecoder().decode(MemoTimeContent.self, from: data) {
                timeContent = content
                // Если currentMinutes не установлено, устанавливаем из initialMinutes
                if timeContent.currentMinutes == 0.0 && timeContent.initialMinutes > 0.0 {
                    timeContent.currentMinutes = timeContent.initialMinutes
                }
                timeColorHex = content.colorHex
                timeColorForPicker = Color(hex: content.colorHex)
            }
        case .health:
            if let data = memo.contentData, let content = try? JSONDecoder().decode(MemoHealthContent.self, from: data) {
                healthContent = content
                // Если currentValue не установлено, устанавливаем из initialValue
                if healthContent.currentValue == 0.0 && healthContent.initialValue != 0.0 {
                    healthContent.currentValue = healthContent.initialValue
                }
                healthColorHex = content.colorHex
                healthColorForPicker = Color(hex: content.colorHex)
            }
        case .calendar:
            if let data = memo.contentData, let content = try? JSONDecoder().decode(MemoCalendarContent.self, from: data) {
                calendarContent = content
                calendarColorHex = content.colorHex
                calendarColorForPicker = Color(hex: content.colorHex)
            }
        }
    }

    private func initializeNewMemoData() {
        title = ""
        descript = ""
        switch memoType {
        case .noteAlbum:
            noteAlbumContent = MemoNoteAlbumContent()
            noteAlbumColorHex = noteAlbumContent.colorHex
            noteAlbumColorForPicker = Color(hex: noteAlbumContent.colorHex)
        case .list:
            listContent = MemoListContent(items: [])
            listColorHex = listContent.colorHex
            listColorForPicker = Color(hex: listContent.colorHex)
        case .counter:
            counterContent = MemoCounterContent()
            counterColorHex = counterContent.colorHex
            counterColorForPicker = Color(hex: counterContent.colorHex)
        case .streak:
            streakContent = MemoStreakContent()
            streakColorHex = streakContent.colorHex
            streakColorForPicker = Color(hex: streakContent.colorHex)
        case .mood:
            moodContent = MemoMoodContent()
            moodContent.scale = 10
            moodColorHex = moodContent.colorHex
            moodColorForPicker = Color(hex: moodContent.colorHex)
            tempMoodValue = 5.0
            savedMoodValue = 5.0
        case .skill:
            skillContent = MemoSkillContent()
            // Ensure scale is valid
            if skillContent.scale < 1 {
                skillContent.scale = 10
            }
            skillColorHex = skillContent.colorHex
            skillColorForPicker = Color(hex: skillContent.colorHex)
            let validScale = max(1, skillContent.scale)
            tempSkillLevel = min(Double(validScale), max(0.0, Double(validScale) / 2.0))
            savedSkillLevel = tempSkillLevel
            
            // Create initial skill with card title
            let initialSkill = MemoSkillContent.SkillItem(
                name: title.isEmpty ? "New Skill" : title,
                currentLevel: tempSkillLevel,
                targetLevel: nil,
                iconName: skillContent.iconName,
                customImageData: skillContent.customImageData,
                colorHex: skillColorHex,
                notes: skillContent.notes,
                history: []
            )
            skillContent.skills = [initialSkill]
        case .budget:
            budgetContent = MemoBudgetContent()
            budgetColorHex = budgetContent.colorHex
            budgetColorForPicker = Color(hex: budgetContent.colorHex)
            
            // Create initial budget with card title
            let initialBudget = MemoBudgetContent.BudgetItem(
                name: title.isEmpty ? "New Budget" : title,
                currentBalance: budgetContent.initialBalance,
                iconName: budgetContent.iconName,
                customImageData: budgetContent.customImageData,
                colorHex: budgetColorHex,
                notes: budgetContent.notes,
                transactions: []
            )
            budgetContent.budgets = [initialBudget]
        case .time:
            timeContent = MemoTimeContent()
            // При создании нового мемо currentMinutes = initialMinutes (оба 0)
            timeContent.currentMinutes = timeContent.initialMinutes
            timeColorHex = timeContent.colorHex
            timeColorForPicker = Color(hex: timeContent.colorHex)
        case .health:
            healthContent = MemoHealthContent()
            healthColorHex = healthContent.colorHex
            healthColorForPicker = Color(hex: healthContent.colorHex)
        case .calendar:
            calendarContent = MemoCalendarContent()
            calendarColorHex = calendarContent.colorHex
            calendarColorForPicker = Color(hex: calendarContent.colorHex)
        }
    }

    func createMemoItem() throws -> MemoItem {
        let data = try getData()
        let orderIndex = Int(Date().timeIntervalSince1970)
        let trimmedDescription = descript.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedDescription: String? = trimmedDescription.isEmpty ? nil : trimmedDescription

        if let existingMemo = memoToEdit {
            // Обновляем существующий объект
            existingMemo.title = title
            existingMemo.descript = normalizedDescription
            existingMemo.tags = selectedTags
            existingMemo.contentData = data
            return existingMemo
        } else {
            // Создаем новый объект
            let newMemo = MemoItem(
                title: title,
                description: normalizedDescription,
                orderIndex: orderIndex,
                type: memoType,
                tags: selectedTags
            )
            newMemo.contentData = data
            return newMemo
        }
    }

    private func getData() throws -> Data {
        switch memoType {
        case .noteAlbum:
            // Обновляем цвет и sphereID перед сохранением
            noteAlbumContent.colorHex = noteAlbumColorHex
            noteAlbumContent.sphereID = noteAlbumSphereID
            return try JSONEncoder().encode(noteAlbumContent)
        case .list:
            // Обновляем цвет перед сохранением
            listContent.colorHex = listColorHex
            return try JSONEncoder().encode(listContent)
        case .counter:
            // Обновляем цвет перед сохранением
            // и нормализуем шаг: минимум 0.01, максимум 2 знака после запятой
            counterContent.colorHex = counterColorHex
            counterContent.unit = normalizeCounterUnit(counterContent.unit)
            let raw = counterContent.stepValue
            let positive = raw > 0 ? raw : 1
            let clamped = max(0.01, positive)
            counterContent.stepValue = (clamped * 100).rounded() / 100
            return try JSONEncoder().encode(counterContent)
        case .streak:
            // Обновляем цвет перед сохранением
            streakContent.colorHex = streakColorHex
            return try JSONEncoder().encode(streakContent)
        case .mood:
            moodContent.scale = 10
            moodContent.colorHex = moodColorHex
            return try JSONEncoder().encode(moodContent)
        case .skill:
            // Обновляем цвет и текущий уровень перед сохранением
            skillContent.colorHex = skillColorHex
            let validScale = Double(max(1, skillContent.scale))
            let clampedLevel = min(max(0, tempSkillLevel), validScale)
            skillContent.currentLevel = clampedLevel
            
            // Ensure there's exactly one skill with the card's title
            if skillContent.skills.isEmpty {
                let newSkill = MemoSkillContent.SkillItem(
                    name: title.isEmpty ? "New Skill" : title,
                    currentLevel: clampedLevel,
                    targetLevel: nil,
                    iconName: skillContent.iconName,
                    customImageData: skillContent.customImageData,
                    colorHex: skillColorHex,
                    notes: skillContent.notes,
                    history: []
                )
                // Add initial history entry
                var skillWithHistory = newSkill
                skillWithHistory.history.append(
                    MemoSkillContent.SkillItem.SkillEntry(
                        date: Date(),
                        level: clampedLevel,
                        note: "Initial level"
                    )
                )
                skillContent.skills = [skillWithHistory]
            } else {
                // Update the first skill's name to match the card title
                skillContent.skills[0].name = title.isEmpty ? skillContent.skills[0].name : title
                skillContent.skills[0].currentLevel = clampedLevel
                skillContent.skills[0].colorHex = skillColorHex
            }
            
            return try JSONEncoder().encode(skillContent)
        case .budget:
            // Обновляем цвет перед сохранением
            budgetContent.colorHex = budgetColorHex
            
            // Ensure there's exactly one budget with the card's title
            if budgetContent.budgets.isEmpty {
                let newBudget = MemoBudgetContent.BudgetItem(
                    name: title.isEmpty ? "New Budget" : title,
                    currentBalance: budgetContent.initialBalance,
                    iconName: budgetContent.iconName,
                    customImageData: budgetContent.customImageData,
                    colorHex: budgetColorHex,
                    notes: budgetContent.notes,
                    transactions: []
                )
                budgetContent.budgets = [newBudget]
            } else {
                // Update the first budget's name and appearance to match
                budgetContent.budgets[0].name = title.isEmpty ? budgetContent.budgets[0].name : title
                budgetContent.budgets[0].iconName = budgetContent.iconName
                budgetContent.budgets[0].customImageData = budgetContent.customImageData
                budgetContent.budgets[0].colorHex = budgetColorHex
                budgetContent.budgets[0].notes = budgetContent.notes
            }
            
            return try JSONEncoder().encode(budgetContent)
        case .time:
            // Обновляем цвет перед сохранением
            timeContent.colorHex = timeColorHex
            // Если currentMinutes не был установлен, устанавливаем из initialMinutes
            if timeContent.currentMinutes == 0.0 && timeContent.initialMinutes > 0.0 {
                timeContent.currentMinutes = timeContent.initialMinutes
            }
            return try JSONEncoder().encode(timeContent)
        case .health:
            // Обновляем цвет перед сохранением
            healthContent.colorHex = healthColorHex
            // Если currentValue не был установлен, устанавливаем из initialValue
            if healthContent.currentValue == 0.0 && healthContent.initialValue != 0.0 {
                healthContent.currentValue = healthContent.initialValue
            }
            return try JSONEncoder().encode(healthContent)
        case .calendar:
            calendarContent.colorHex = calendarColorHex
            calendarContent.iconName = calendarContent.iconName.isEmpty ? "calendar" : calendarContent.iconName
            return try JSONEncoder().encode(calendarContent)
        }
    }
    
    private func normalizeCounterUnit(_ unit: String) -> String {
        let trimmed = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let limited = String(trimmed.prefix(10))
        if limited == limited.uppercased() {
            return limited
        }
        let first = limited.prefix(1).lowercased()
        let rest = limited.dropFirst()
        return String(first + rest)
    }
    
    // MARK: Иконки и порядок пунктов списка (list-мемо)
    func applyIconToAllListItems(iconName: String) {
        for i in 0..<listContent.items.count {
            listContent.items[i].iconName = iconName
            listContent.items[i].useCustomImage = false
            listContent.items[i].customImageData = nil
        }
    }
    
    func applyImageToAllListItems(imageData: Data) {
        for i in 0..<listContent.items.count {
            listContent.items[i].customImageData = imageData
            listContent.items[i].useCustomImage = true
            listContent.items[i].iconName = nil
        }
    }
    
    func resetAllListItemsToNumbers() {
        for i in 0..<listContent.items.count {
            listContent.items[i].iconName = nil
            listContent.items[i].useCustomImage = false
            listContent.items[i].customImageData = nil
        }
    }
    
    // MARK: Данные настроения (mood-мемо)
    func confirmMoodChange() {
        savedMoodValue = tempMoodValue
    }
    
    func cancelMoodChange() {
        tempMoodValue = savedMoodValue
    }
    
    // MARK: Навыки и записи прогресса (skills-мемо)
    func confirmSkillChange() {
        savedSkillLevel = tempSkillLevel
    }
    
    func cancelSkillChange() {
        tempSkillLevel = savedSkillLevel
    }
}

