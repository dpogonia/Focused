import SwiftUI
import SwiftData

// MARK: - Доменная модель: супер-задача (SwiftData)
//
// Агрегат экрана Tasks. Список «что показать» — `FilterTasksUseCase` + `TasksCalendarFilter`.

// MARK: - TASK MODEL
@Model
final class SuperTask: Identifiable {
    var id: UUID
    var title: String
    var descript: String?
    var colorHex: String?
    var creationDate: Date
    var dueDate: Date?
    var repeating: String
    var status: String
    var orderIndex: Int
    @Relationship(deleteRule: .cascade) var tags: [Tag] = []
    var sphereID: UUID?
    var positiveImpact: Double = 0.0
    var negativeImpact: Double = 0.0
    var goalID: UUID?
    var estimatedDuration: Int = 0
    var actualDuration: Int = 0
    var lastModifiedDate: Date
    var isMockData: Bool = false
    
    @Relationship(deleteRule: .cascade) var subTasks: [SubTask]
    
    enum Repeating: String, Codable, CaseIterable {
        case none = "None"
        case daily = "Daily"
        case weekly = "Weekly"
        case monthly = "Monthly"
        case yearly = "Yearly"
        
        var icon: String {
            switch self {
            case .none: return "xmark.circle"
            case .daily: return "sun.max"
            case .weekly: return "calendar.badge.clock"
            case .monthly: return "calendar"
            case .yearly: return "calendar.badge.plus"
            }
        }
    }
    
    enum Status: String, Codable, CaseIterable, Comparable {
        case inProgress = "In Progress"
        case completed = "Completed"
        case archived = "Archived"
        
        var displayString: String {
            return self.rawValue
        }
        
        var icon: String {
            switch self {
            case .inProgress: return "play.circle"
            case .completed: return "checkmark.circle"
            case .archived: return "archivebox"
            }
        }
        
        var color: String {
            switch self {
            case .inProgress: return "#007AFF"
            case .completed: return "#34C759"
            case .archived: return "#8E8E93"
            }
        }
        
        static func < (lhs: Status, rhs: Status) -> Bool {
            switch (lhs, rhs) {
            case (.inProgress, .completed), (.inProgress, .archived), (.completed, .archived): return true
            default: return false
            }
        }
    }
    
    init(title: String, descript: String? = nil, colorHex: String? = nil, dueDate: Date? = nil, repeating: Repeating = .none, status: Status = .inProgress, orderIndex: Int, subTasks: [SubTask] = [], sphereID: UUID? = nil, goalID: UUID? = nil, positiveImpact: Double = 0.0, negativeImpact: Double = 0.0, estimatedDuration: Int = 0, isMockData: Bool = false) {
        self.id = UUID()
        self.title = title
        self.descript = descript
        self.colorHex = colorHex
        self.creationDate = Date()
        self.dueDate = dueDate
        self.repeating = repeating.rawValue
        self.status = status.rawValue
        self.orderIndex = orderIndex
        self.subTasks = subTasks
        self.sphereID = sphereID
        self.goalID = goalID
        self.positiveImpact = positiveImpact
        self.negativeImpact = negativeImpact
        self.estimatedDuration = estimatedDuration
        self.actualDuration = 0
        self.lastModifiedDate = Date()
        self.isMockData = isMockData
    }
    
    var statusEnum: Status {
        get {
            // Миграция старых статусов
            switch status {
            case "Pending", "Review": return .inProgress
            case "Cancelled": return .archived
            case "In Progress", "Completed", "Archived": return Status(rawValue: status) ?? .inProgress
            default: return .inProgress
            }
        }
        set { status = newValue.rawValue }
    }
    
    var repeatingEnum: Repeating {
        get { Repeating(rawValue: repeating) ?? .none }
        set { repeating = newValue.rawValue }
    }
    
    func isCompleted(on date: Date) -> Bool {
        return statusEnum == .completed
    }
    
    func updateStatus(to newStatus: Status) {
        self.status = newStatus.rawValue
        self.lastModifiedDate = Date()
        
        // Если таск завершен, автоматически завершаем все субтаски
        if newStatus == .completed {
            for subTask in subTasks {
                subTask.isCompleted = true
            }
        }
    }
    
    func completionProgress() -> Double {
        guard !subTasks.isEmpty else { return statusEnum == .completed ? 1.0 : 0.0 }
        let completedCount = subTasks.filter { $0.isCompleted }.count
        return Double(completedCount) / Double(subTasks.count)
    }
    
    func isOverdue() -> Bool {
        guard let dueDate = dueDate else { return false }
        return dueDate < Date() && statusEnum != .completed
    }
    
    func daysUntilDue() -> Int? {
        guard let dueDate = dueDate else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let due = calendar.startOfDay(for: dueDate)
        return calendar.dateComponents([.day], from: today, to: due).day
    }
}

// MARK: - SUBTASK MODEL
@Model
final class SubTask: Identifiable {
    var id: UUID
    var title: String
    var isCompleted: Bool
    var orderIndex: Int
    var estimatedDuration: Int = 0 // В минутах
    var actualDuration: Int = 0 // В минутах
    var notes: String?
    var creationDate: Date
    var dueDate: Date?
    var reminderDate: Date?
    var priority: String = Priority.medium.rawValue
    var checklist: [String] = []
    
    init(title: String, isCompleted: Bool = false, orderIndex: Int = 0, estimatedDuration: Int = 0, notes: String? = nil, dueDate: Date? = nil, reminderDate: Date? = nil, priority: Priority = .medium, checklist: [String] = []) {
        self.id = UUID()
        self.title = title
        self.isCompleted = isCompleted
        self.orderIndex = orderIndex
        self.estimatedDuration = estimatedDuration
        self.actualDuration = 0
        self.notes = notes
        self.creationDate = Date()
        self.dueDate = dueDate
        self.reminderDate = reminderDate
        self.priority = priority.rawValue
        self.checklist = checklist
    }
    
    func toggleCompletion() {
        isCompleted.toggle()
    }
    
    func updateEstimatedDuration(_ duration: Int) {
        estimatedDuration = duration
    }
    
    func updateNotes(_ newNotes: String?) {
        notes = newNotes
    }
    
    func markAsCompleted() {
        isCompleted = true
    }
    
    func markAsIncomplete() {
        isCompleted = false
    }
}

// MARK: - SUBTASK PRIORITY
enum Priority: String, Codable, CaseIterable, Identifiable {
    case low
    case medium
    case high
    
    var id: String { self.rawValue }
    var title: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }
}

// MARK: - TASKS SETTINGS
@Model
final class TasksSettings {
    var designString: String
    var showCompletedTasks: Bool = true
    var showArchivedTasks: Bool = false
    
    init(design: TasksViewDesign = .basic, showCompletedTasks: Bool = true, showArchivedTasks: Bool = false) {
        self.designString = design.rawValue
        self.showCompletedTasks = showCompletedTasks
        self.showArchivedTasks = showArchivedTasks
    }
    
    var design: TasksViewDesign {
        get {
            return TasksViewDesign(rawValue: designString) ?? .basic
        }
        set {
            designString = newValue.rawValue
        }
    }
}

// MARK: - TASKS VIEW DESIGN ENUM
enum TasksViewDesign: String, Codable, CaseIterable, Identifiable {
    case basic
    case rainbow
    
    var id: String { self.rawValue }
}

// MARK: - TASK DROP DELEGATE
struct TaskDropDelegate: DropDelegate {
    let task: SuperTask
    let tasks: [SuperTask]
    let modelContext: ModelContext
    
    func dropEntered(info: DropInfo) {
        // Visual feedback when dragging over a task
        withAnimation(.easeInOut(duration: 0.2)) {
            // Можно добавить состояние для visual feedback
        }
    }
    
    func dropExited(info: DropInfo) {
        // Reset visual state when leaving
        withAnimation(.easeInOut(duration: 0.2)) {
            // Reset visual state
        }
    }
    
    func performDrop(info: DropInfo) -> Bool {
        guard let itemProvider = info.itemProviders(for: [.text]).first else { return false }
        
        itemProvider.loadObject(ofClass: NSString.self) { string, _ in
            guard let uuidString = string as? String,
                  let draggedTaskID = UUID(uuidString: uuidString),
                  let draggedTask = tasks.first(where: { $0.id == draggedTaskID }),
                  draggedTask.id != task.id else { return }
            
            DispatchQueue.main.async {
                reorderTasks(draggedTask: draggedTask, targetTask: task)
            }
        }
        return true
    }
    
    private func reorderTasks(draggedTask: SuperTask, targetTask: SuperTask) {
        guard let draggedIndex = tasks.firstIndex(where: { $0.id == draggedTask.id }),
              let targetIndex = tasks.firstIndex(where: { $0.id == targetTask.id }) else { return }
        
        var tempTasks = tasks
        tempTasks.move(fromOffsets: IndexSet(integer: draggedIndex), toOffset: targetIndex)
        
        for (index, task) in tempTasks.enumerated() {
            task.orderIndex = index
        }
        
        HapticSoundManager.shared.selectionChanged()
        
        try? modelContext.save()
        // Уведомляем об изменении для обновления анимации
        NotificationCenter.default.postAppEvent(.taskStatusDidChange)
    }
}
