import Foundation
import SwiftData

// MARK: - Папка `Services/Backup` (этап 3)
//
// Один прикладной сервис — одна директория: так проще найти резервное копирование и не смешивать с UI.
// См. также `Services/SampleData`, `Services/VisionAnalytics`.

// MARK: - Сервис резервного копирования (Application / Infrastructure)
//
// Экспорт/импорт JSON поверх SwiftData — отдельная зона ответственности (**SRP**).
// Реализация как синглтон; при желании можно обернуть протоколом и отдать из `AppDependencies`.

/// Экспорт и импорт данных приложения в JSON (резервная копия).
final class BackupService {
    static let shared = BackupService()
    
    private init() {}
    
    // MARK: - Backup Data Structure
    
    struct AppBackup: Codable {
        let version: String
        let exportDate: Date
        let spheres: [SphereBackup]
        let goals: [GoalBackup]
        let tasks: [TaskBackup]
        let habits: [HabitBackup]
        let memoItems: [MemoBackup]
    }
    
    struct SphereBackup: Codable {
        let id: UUID
        let title: String
        let iconName: String
        let colorHex: String
        let satisfaction: Double
        let orderIndex: Int
    }
    
    struct GoalBackup: Codable {
        let id: UUID
        let title: String
        let descript: String?
        let colorHex: String?
        let creationDate: Date
        let dueDate: Date?
        let reward: String?
        let status: String
        let orderIndex: Int
        let sphereID: UUID?
        let positiveImpact: Double
        let negativeImpact: Double
        let isFlagged: Bool
        /// Older backups omit this — treat as `0`.
        let visionGridOrder: Int?
        let tags: [String]
    }
    
    struct TaskBackup: Codable {
        let id: UUID
        let title: String
        let descript: String?
        let colorHex: String?
        let creationDate: Date
        let dueDate: Date?
        let priority: Int?  // Optional for backwards compatibility with old backups
        let repeating: String
        let status: String
        let orderIndex: Int
        let sphereID: UUID?
        let positiveImpact: Double
        let negativeImpact: Double
        let goalID: UUID?
        let estimatedDuration: Int
        let actualDuration: Int
        let tags: [String]
        let subtasks: [SubtaskBackup]
    }
    
    struct SubtaskBackup: Codable {
        let id: UUID
        let title: String
        let isCompleted: Bool
        let orderIndex: Int
    }
    
    struct HabitBackup: Codable {
        let id: UUID
        let title: String
        let colorHex: String
        let iconName: String
        let creationDate: Date
        let orderIndex: Int
        let sphereID: UUID?
        let positiveImpact: Double
        let negativeImpact: Double
        let requiredRepetitions: Int
        /// Старые бэкапы без поля декодируют как `nil` → при импорте считается `false`.
        let isArchived: Bool?
        let tags: [String]
        let completions: [CompletionBackup]
        let repeatingRules: [RepeatingRuleBackup]
    }
    
    struct CompletionBackup: Codable {
        let date: Date
        let count: Int
    }
    
    struct RepeatingRuleBackup: Codable {
        let startDate: Date
        let weeklyFrequency: [Int]
        let monthlySpecificDays: [Int]
    }
    
    struct MemoBackup: Codable {
        let id: UUID
        let title: String
        let descript: String?
        let creationDate: Date
        let orderIndex: Int
        let itemTypeRawValue: String
        let contentData: Data?
        let tags: [String]
        let statusRawValue: String
        let isMockData: Bool
    }
    
    // MARK: - Export
    
    func exportData(modelContext: ModelContext) throws -> Data {
        let spheres = (try? modelContext.fetch(FetchDescriptor<Sphere>())) ?? []
        let goals = (try? modelContext.fetch(FetchDescriptor<Goal>())) ?? []
        let tasks = (try? modelContext.fetch(FetchDescriptor<SuperTask>())) ?? []
        let habits = (try? modelContext.fetch(FetchDescriptor<Habit>())) ?? []
        let memoItems = (try? modelContext.fetch(FetchDescriptor<MemoItem>())) ?? []
        
        let backup = AppBackup(
            version: "1.0",
            exportDate: Date(),
            spheres: spheres.map { sphere in
                SphereBackup(
                    id: sphere.id,
                    title: sphere.title,
                    iconName: sphere.iconName,
                    colorHex: sphere.colorHex,
                    satisfaction: sphere.satisfaction,
                    orderIndex: sphere.orderIndex
                )
            },
            goals: goals.map { goal in
                GoalBackup(
                    id: goal.id,
                    title: goal.title,
                    descript: goal.descript,
                    colorHex: goal.colorHex,
                    creationDate: goal.creationDate,
                    dueDate: goal.dueDate,
                    reward: goal.reward,
                    status: goal.status.rawValue,
                    orderIndex: goal.orderIndex,
                    sphereID: goal.sphereID,
                    positiveImpact: goal.positiveImpact,
                    negativeImpact: goal.negativeImpact,
                    isFlagged: goal.isFlagged,
                    visionGridOrder: goal.visionGridOrder,
                    tags: goal.tags.map { $0.name }
                )
            },
            tasks: tasks.map { task in
                TaskBackup(
                    id: task.id,
                    title: task.title,
                    descript: task.descript,
                    colorHex: task.colorHex,
                    creationDate: task.creationDate,
                    dueDate: task.dueDate,
                    priority: nil,
                    repeating: task.repeating,
                    status: task.status,
                    orderIndex: task.orderIndex,
                    sphereID: task.sphereID,
                    positiveImpact: task.positiveImpact,
                    negativeImpact: task.negativeImpact,
                    goalID: task.goalID,
                    estimatedDuration: task.estimatedDuration,
                    actualDuration: task.actualDuration,
                    tags: task.tags.map { $0.name },
                    subtasks: task.subTasks.map { sub in
                        SubtaskBackup(
                            id: sub.id,
                            title: sub.title,
                            isCompleted: sub.isCompleted,
                            orderIndex: sub.orderIndex
                        )
                    }
                )
            },
            habits: habits.map { habit in
                HabitBackup(
                    id: habit.id,
                    title: habit.title,
                    colorHex: habit.colorHex,
                    iconName: habit.iconName,
                    creationDate: habit.creationDate,
                    orderIndex: habit.orderIndex,
                    sphereID: habit.sphereID,
                    positiveImpact: habit.positiveImpact,
                    negativeImpact: habit.negativeImpact,
                    requiredRepetitions: habit.requiredRepetitions,
                    isArchived: habit.isArchived,
                    tags: habit.tags.map { $0.name },
                    completions: habit.completions.map { CompletionBackup(date: $0.date, count: $0.count) },
                    repeatingRules: habit.repeatingRules.map { rule in
                        RepeatingRuleBackup(
                            startDate: rule.startDate,
                            weeklyFrequency: rule.weeklyFrequency,
                            monthlySpecificDays: rule.monthlySpecificDays
                        )
                    }
                )
            },
            memoItems: memoItems.map { memo in
                MemoBackup(
                    id: memo.id,
                    title: memo.title,
                    descript: memo.descript,
                    creationDate: memo.creationDate,
                    orderIndex: memo.orderIndex,
                    itemTypeRawValue: memo.itemTypeRawValue,
                    contentData: memo.contentData,
                    tags: memo.tags,
                    statusRawValue: memo.statusRawValue,
                    isMockData: memo.isMockData
                )
            }
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        return try encoder.encode(backup)
    }
    
    // MARK: - Import
    
    func importData(from data: Data, modelContext: ModelContext) throws -> ImportResult {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let backup = try decoder.decode(AppBackup.self, from: data)
        
        // Delete all existing data first (replace, not merge)
        let goals = (try? modelContext.fetch(FetchDescriptor<Goal>())) ?? []
        let tasks = (try? modelContext.fetch(FetchDescriptor<SuperTask>())) ?? []
        let habits = (try? modelContext.fetch(FetchDescriptor<Habit>())) ?? []
        let memos = (try? modelContext.fetch(FetchDescriptor<MemoItem>())) ?? []
        let spheres = (try? modelContext.fetch(FetchDescriptor<Sphere>())) ?? []
        
        for g in goals { modelContext.delete(g) }
        for t in tasks { modelContext.delete(t) }
        for h in habits { modelContext.delete(h) }
        for m in memos { modelContext.delete(m) }
        for s in spheres { modelContext.delete(s) }
        
        try modelContext.save()
        
        var result = ImportResult()
        
        // Import spheres (preserve IDs so sphereID references in goals/tasks/habits/memo stay valid)
        for sphereBackup in backup.spheres {
            let sphere = Sphere(
                title: sphereBackup.title,
                satisfaction: sphereBackup.satisfaction,
                colorHex: sphereBackup.colorHex,
                iconName: sphereBackup.iconName,
                orderIndex: sphereBackup.orderIndex,
                id: sphereBackup.id
            )
            modelContext.insert(sphere)
            result.spheresImported += 1
        }
        
        // Import goals (preserve IDs so goalID in tasks stays valid)
        for goalBackup in backup.goals {
            let goal = Goal(
                title: goalBackup.title,
                description: goalBackup.descript,
                colorHex: goalBackup.colorHex,
                dueDate: goalBackup.dueDate,
                reward: goalBackup.reward,
                status: Goal.Status(rawValue: goalBackup.status) ?? .pending,
                orderIndex: goalBackup.orderIndex,
                sphereID: goalBackup.sphereID,
                positiveImpact: goalBackup.positiveImpact,
                negativeImpact: goalBackup.negativeImpact,
                isFlagged: goalBackup.isFlagged,
                visionGridOrder: goalBackup.visionGridOrder ?? 0,
                id: goalBackup.id
            )
            
            for tagName in goalBackup.tags {
                let tag = Tag(name: tagName)
                goal.tags.append(tag)
            }
            
            modelContext.insert(goal)
            result.goalsImported += 1
        }
        
        // Import tasks
        for taskBackup in backup.tasks {
            let task = SuperTask(
                title: taskBackup.title,
                descript: taskBackup.descript,
                colorHex: taskBackup.colorHex,
                dueDate: taskBackup.dueDate,
                repeating: SuperTask.Repeating(rawValue: taskBackup.repeating) ?? .none,
                status: SuperTask.Status(rawValue: taskBackup.status) ?? .inProgress,
                orderIndex: taskBackup.orderIndex,
                sphereID: taskBackup.sphereID,
                goalID: taskBackup.goalID,
                positiveImpact: taskBackup.positiveImpact,
                negativeImpact: taskBackup.negativeImpact,
                estimatedDuration: taskBackup.estimatedDuration
            )
            
            for tagName in taskBackup.tags {
                let tag = Tag(name: tagName)
                task.tags.append(tag)
            }
            
            for subtaskBackup in taskBackup.subtasks {
                let subtask = SubTask(
                    title: subtaskBackup.title,
                    isCompleted: subtaskBackup.isCompleted,
                    orderIndex: subtaskBackup.orderIndex
                )
                task.subTasks.append(subtask)
            }
            
            modelContext.insert(task)
            result.tasksImported += 1
        }
        
        // Import habits
        for habitBackup in backup.habits {
            let initialRule: RepeatingRule
            if let firstRule = habitBackup.repeatingRules.first {
                initialRule = RepeatingRule(
                    startDate: firstRule.startDate,
                    weeklyFrequency: firstRule.weeklyFrequency,
                    monthlySpecificDays: firstRule.monthlySpecificDays
                )
            } else {
                initialRule = RepeatingRule(startDate: habitBackup.creationDate, weeklyFrequency: Array(1...7), monthlySpecificDays: [])
            }
            
            let habit = Habit(
                title: habitBackup.title,
                colorHex: habitBackup.colorHex,
                iconName: habitBackup.iconName,
                orderIndex: habitBackup.orderIndex,
                creationDate: habitBackup.creationDate,
                initialRule: initialRule,
                sphereID: habitBackup.sphereID,
                positiveImpact: habitBackup.positiveImpact,
                negativeImpact: habitBackup.negativeImpact,
                requiredRepetitions: habitBackup.requiredRepetitions
            )
            
            // Restore completions
            for completionBackup in habitBackup.completions {
                habit.completions.append(Completion(date: completionBackup.date, count: completionBackup.count))
            }
            
            // Restore additional repeating rules
            for (index, ruleBackup) in habitBackup.repeatingRules.enumerated() where index > 0 {
                let rule = RepeatingRule(
                    startDate: ruleBackup.startDate,
                    weeklyFrequency: ruleBackup.weeklyFrequency,
                    monthlySpecificDays: ruleBackup.monthlySpecificDays
                )
                habit.repeatingRules.append(rule)
            }
            
            for tagName in habitBackup.tags {
                let tag = Tag(name: tagName)
                habit.tags.append(tag)
            }
            
            habit.isArchived = habitBackup.isArchived ?? false
            
            modelContext.insert(habit)
            result.habitsImported += 1
        }
        
        // Import memo items
        for memoBackup in backup.memoItems {
            let memoType = MemoItemType(rawValue: memoBackup.itemTypeRawValue) ?? .noteAlbum
            let memoStatus = MemoStatus(rawValue: memoBackup.statusRawValue) ?? .active
            let memo = MemoItem(
                title: memoBackup.title,
                description: memoBackup.descript,
                orderIndex: memoBackup.orderIndex,
                type: memoType,
                tags: memoBackup.tags,
                status: memoStatus,
                isMockData: memoBackup.isMockData
            )
            memo.id = memoBackup.id
            memo.creationDate = memoBackup.creationDate
            memo.itemTypeRawValue = memoBackup.itemTypeRawValue
            memo.statusRawValue = memoBackup.statusRawValue
            memo.contentData = memoBackup.contentData
            modelContext.insert(memo)
            result.memosImported += 1
        }
        
        try modelContext.save()
        
        return result
    }
    
    struct ImportResult {
        var spheresImported: Int = 0
        var goalsImported: Int = 0
        var tasksImported: Int = 0
        var habitsImported: Int = 0
        var memosImported: Int = 0
        
        var totalImported: Int {
            spheresImported + goalsImported + tasksImported + habitsImported + memosImported
        }
        
        var summary: String {
            """
            Imported successfully:
            • \(spheresImported) spheres
            • \(goalsImported) goals
            • \(tasksImported) tasks
            • \(habitsImported) habits
            • \(memosImported) memo items
            """
        }
    }
}
