import SwiftUI
import SwiftData

// MARK: - Доменная модель: цель (SwiftData)
//
// Агрегат экрана Goals. Фильтрация/сортировка списка — `FilterGoalsUseCase` + `GoalsCalendarFilter` (**Strategy**), не внутри модели.

// MARK: - GOAL MODEL
@Model
final class Goal: Identifiable {
    var id: UUID
    var title: String
    var descript: String?
    var imageData: Data?
    /// Optional user-selected SF Symbol for the goal (used when no photo is set).
    /// If nil, UI falls back to the related sphere icon (or a generic default).
    var iconName: String?
    var colorHex: String?
    var creationDate: Date
    var dueDate: Date?
    var reward: String?
    var status: Status
    @Relationship(deleteRule: .cascade) var subtasks: [SubTask]
    @Relationship(deleteRule: .cascade) var counters: [Counter]
    var orderIndex: Int
    var completedAt: Date?
    @Relationship(deleteRule: .cascade) var tags: [Tag] = []
    var sphereID: UUID?
    var positiveImpact: Double = 0.0
    var negativeImpact: Double = 0.0
    /// Shown as «Important» in UI; Vision grid lists only flagged goals. Order in that grid uses `visionGridOrder`.
    var isFlagged: Bool = false
    /// Order of this goal in the Vision tab goals grid (meaningful when `isFlagged`); lower = earlier.
    var visionGridOrder: Int = 0
    var isMockData: Bool = false
    
    enum Status: String, Codable, CaseIterable, Comparable {
        case pending, inProgress, missed, completed, archived
        
        static func < (lhs: Status, rhs: Status) -> Bool {
            switch (lhs, rhs) {
            case (.pending, .inProgress), (.pending, .missed), (.pending, .completed), (.pending, .archived),
                (.inProgress, .missed), (.inProgress, .completed), (.inProgress, .archived),
                (.missed, .completed), (.missed, .archived),
                (.completed, .archived): return true
            default: return false
            }
        }
    }
    
    init(title: String, description: String? = nil, imageData: Data? = nil, iconName: String? = nil, colorHex: String? = nil, dueDate: Date? = nil, reward: String? = nil, status: Status = .pending, orderIndex: Int, completedAt: Date? = nil, subtasks: [SubTask] = [], counters: [Counter] = [], sphereID: UUID? = nil, positiveImpact: Double = 0.0, negativeImpact: Double = 0.0, isFlagged: Bool = false, visionGridOrder: Int = 0, isMockData: Bool = false, id: UUID? = nil) {
        self.id = id ?? UUID()
        self.title = title
        self.descript = description
        self.imageData = imageData
        self.iconName = iconName
        self.colorHex = colorHex
        self.creationDate = Date()
        self.dueDate = dueDate
        self.reward = reward
        self.status = status
        self.orderIndex = orderIndex
        self.completedAt = completedAt
        self.subtasks = subtasks
        self.counters = counters
        self.sphereID = sphereID
        self.positiveImpact = positiveImpact
        self.negativeImpact = negativeImpact
        self.isFlagged = isFlagged
        self.visionGridOrder = visionGridOrder
        self.isMockData = isMockData
    }
    
    func isCompleted(on date: Date) -> Bool {
        return status == .completed
    }
    
    func updateStatus(to newStatus: Status) {
        self.status = newStatus
        if newStatus == .completed || newStatus == .missed {
            self.completedAt = Date()
        } else {
            self.completedAt = nil
        }
    }
    
    /// Обновляет satisfaction связанной сферы при смене статуса цели (Completion Increase / Apply Miss Decrease).
    static func adjustSphereSatisfaction(goal: Goal, oldStatus: Status, newStatus: Status, modelContext: ModelContext) {
        guard let sphereID = goal.sphereID else { return }
        let descriptor = FetchDescriptor<Sphere>(predicate: #Predicate<Sphere> { $0.id == sphereID })
        guard let sphere = try? modelContext.fetch(descriptor).first else { return }
        
        if oldStatus == .completed {
            sphere.satisfaction -= max(0, goal.positiveImpact)
        } else if oldStatus == .missed {
            sphere.satisfaction += max(0, goal.negativeImpact)
        }
        
        if newStatus == .completed {
            sphere.satisfaction += max(0, goal.positiveImpact)
        } else if newStatus == .missed {
            sphere.satisfaction -= max(0, goal.negativeImpact)
        }
        
        sphere.satisfaction = max(0, min(100, sphere.satisfaction))
    }
    
    func completionProgress() -> Double {
        let subtaskProgress: Double
        if !subtasks.isEmpty {
            let completedCount = subtasks.filter { $0.isCompleted }.count
            subtaskProgress = Double(completedCount) / Double(subtasks.count)
        } else {
            subtaskProgress = 0.0
        }
        
        let counterProgress: Double
        if !counters.isEmpty {
            let totalCurrent = counters.reduce(0) { $0 + $1.current }
            let totalTarget = counters.reduce(0) { $0 + $1.target }
            counterProgress = totalTarget > 0 ? Double(totalCurrent) / Double(totalTarget) : 0.0
        } else {
            counterProgress = 0.0
        }
        
        let combinedProgress = (subtaskProgress + counterProgress) / 2.0
        return status == .completed ? 1.0 : combinedProgress
    }
}

// MARK: - Goal → Sphere satisfaction adjustment (Completion Increase / Apply Miss Decrease)
func adjustSphereSatisfactionForGoal(_ goal: Goal, oldStatus: Goal.Status, newStatus: Goal.Status, modelContext: ModelContext) {
    guard let sphereID = goal.sphereID else { return }
    let descriptor = FetchDescriptor<Sphere>(predicate: #Predicate<Sphere> { $0.id == sphereID })
    guard let sphere = try? modelContext.fetch(descriptor).first else { return }
    
    if oldStatus == .completed {
        sphere.satisfaction -= goal.positiveImpact
    } else if oldStatus == .missed {
        sphere.satisfaction += goal.negativeImpact
    }
    
    if newStatus == .completed {
        sphere.satisfaction += goal.positiveImpact
    } else if newStatus == .missed {
        sphere.satisfaction -= goal.negativeImpact
    }
    
    sphere.satisfaction = max(0.0, min(100.0, sphere.satisfaction))
}

// MARK: - GOALS SETTINGS
@Model
final class GoalsSettings {
    var designString: String
    var showCompletedGoals: Bool = true
    var showArchivedGoals: Bool = false
    
    init(design: AllGoalsViewDesign = .basic, showCompletedGoals: Bool = true, showArchivedGoals: Bool = false) {
        self.designString = design.rawValue
        self.showCompletedGoals = showCompletedGoals
        self.showArchivedGoals = showArchivedGoals
    }
    
    var design: AllGoalsViewDesign {
        get {
            return AllGoalsViewDesign(rawValue: designString) ?? .basic
        }
        set {
            designString = newValue.rawValue
        }
    }
}

// MARK: - GOALS VIEW DESIGN ENUM
enum AllGoalsViewDesign: String, Codable, CaseIterable, Identifiable {
    case basic
    case rainbow
    
    var id: String { self.rawValue }
}

// MARK: - GOAL DROP DELEGATE
struct GoalDropDelegate: DropDelegate {
    let goal: Goal
    let goals: [Goal]
    let modelContext: ModelContext
    
    func performDrop(info: DropInfo) -> Bool {
        guard let itemProvider = info.itemProviders(for: [.text]).first else { return false }
        
        itemProvider.loadObject(ofClass: NSString.self) { string, _ in
            guard let uuidString = string as? String,
                  let draggedGoalID = UUID(uuidString: uuidString),
                  let draggedGoal = goals.first(where: { $0.id == draggedGoalID }),
                  draggedGoal.id != goal.id else { return }
            
            DispatchQueue.main.async {
                reorderGoals(draggedGoal: draggedGoal, targetGoal: goal)
            }
        }
        return true
    }
    
    private func reorderGoals(draggedGoal: Goal, targetGoal: Goal) {
        guard let draggedIndex = goals.firstIndex(where: { $0.id == draggedGoal.id }),
              let targetIndex = goals.firstIndex(where: { $0.id == targetGoal.id }) else { return }
        
        var tempGoals = goals
        tempGoals.move(fromOffsets: IndexSet(integer: draggedIndex), toOffset: targetIndex)
        
        // Update order indices
        for (index, goal) in tempGoals.enumerated() {
            goal.orderIndex = index
        }
        
        HapticSoundManager.shared.selectionChanged()
        try? modelContext.save()
        // Уведомляем об изменении для обновления анимации
        NotificationCenter.default.postAppEvent(.goalStatusDidChange)
    }
}




