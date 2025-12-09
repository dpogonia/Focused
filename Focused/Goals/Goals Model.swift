import SwiftUI
import SwiftData

// MARK: - GOAL MODEL
@Model
final class Goal: Identifiable {
    var id: UUID
    var title: String
    var descript: String?
    var imageData: Data?
    var colorHex: String?
    var creationDate: Date
    var dueDate: Date?
    var reward: String?
    var status: Status
    @Relationship(deleteRule: .cascade) var subtasks: [SubTask]
    @Relationship(deleteRule: .cascade) var counters: [Counter]
    var orderIndex: Int
    @Relationship(deleteRule: .cascade) var tags: [Tag] = []
    var sphereID: UUID?
    var positiveImpact: Double = 0.0
    var negativeImpact: Double = 0.0
    var isFlagged: Bool = false
    
    enum Status: String, Codable, CaseIterable, Comparable {
        case pending, inProgress, missed, completed
        
        static func < (lhs: Status, rhs: Status) -> Bool {
            switch (lhs, rhs) {
            case (.pending, .inProgress), (.pending, .missed), (.pending, .completed),
                (.inProgress, .missed), (.inProgress, .completed),
                (.missed, .completed): return true
            default: return false
            }
        }
    }
    
    init(title: String, description: String? = nil, imageData: Data? = nil, colorHex: String? = nil, dueDate: Date? = nil, reward: String? = nil, status: Status = .pending, orderIndex: Int, subtasks: [SubTask] = [], counters: [Counter] = [], sphereID: UUID? = nil, positiveImpact: Double = 0.0, negativeImpact: Double = 0.0, isFlagged: Bool = false) {
        self.id = UUID()
        self.title = title
        self.descript = description
        self.imageData = imageData
        self.colorHex = colorHex
        self.creationDate = Date()
        self.dueDate = dueDate
        self.reward = reward
        self.status = status
        self.orderIndex = orderIndex
        self.subtasks = subtasks
        self.counters = counters
        self.sphereID = sphereID
        self.positiveImpact = positiveImpact
        self.negativeImpact = negativeImpact
        self.isFlagged = isFlagged
    }
    
    func isCompleted(on date: Date) -> Bool {
        return status == .completed
    }
    
    func updateStatus(to newStatus: Status) {
        self.status = newStatus
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

// MARK: - GOALS SETTINGS
@Model
final class GoalsSettings {
    var designString: String
    var showCompletedGoals: Bool = true
    
    init(design: AllGoalsViewDesign = .basic, showCompletedGoals: Bool = true) {
        self.designString = design.rawValue
        self.showCompletedGoals = showCompletedGoals
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
        NotificationCenter.default.post(name: .goalStatusDidChange, object: nil)
    }
}




