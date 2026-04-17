import Foundation
import SwiftData
import SwiftUI

// MARK: - Сид стартового набора данных
//
// Один раз при первом запуске (пустая БД): 6 сфер и по одной цели, задаче, привычке и мемо на сферу.
// Шесть мемо — шесть разных типов. Пользователь дальше редактирует или удаляет вручную.

struct SampleDataSeeder {
    static let shared = SampleDataSeeder()

    private init() {}

    private let seedKey = "defaultSampleDataAdded"
    private let spheresKey = "defaultsSpheresAdded"

    private func makeSixDefaultSpheres() -> [Sphere] {
        [
            Sphere(title: "Mental", satisfaction: 35.0, colorHex: "#AF52DE", iconName: "lightbulb.fill", orderIndex: 0),
            Sphere(title: "Social", satisfaction: 45.5, colorHex: "#FF9500", iconName: "person.2.fill", orderIndex: 1),
            Sphere(title: "Finance", satisfaction: 50.0, colorHex: "#00C7BE", iconName: "dollarsign.circle.fill", orderIndex: 2),
            Sphere(title: "Skills", satisfaction: 40.0, colorHex: "#32ADE6", iconName: "book.fill", orderIndex: 3),
            Sphere(title: "Health", satisfaction: 75.0, colorHex: "#FF2D55", iconName: "heart.fill", orderIndex: 4),
            Sphere(title: "Sports", satisfaction: 80.0, colorHex: "#FFCC00", iconName: "dumbbell.fill", orderIndex: 5)
        ]
    }

    func seedIfNeeded(using modelContext: ModelContext) {
        let defaults = UserDefaults.standard

        if defaults.bool(forKey: seedKey) {
            return
        }

        let goalsCount = (try? modelContext.fetch(FetchDescriptor<Goal>()).count) ?? 0
        let tasksCount = (try? modelContext.fetch(FetchDescriptor<SuperTask>()).count) ?? 0
        let habitsCount = (try? modelContext.fetch(FetchDescriptor<Habit>()).count) ?? 0
        let memoCount = (try? modelContext.fetch(FetchDescriptor<MemoItem>()).count) ?? 0

        guard goalsCount == 0, tasksCount == 0, habitsCount == 0, memoCount == 0 else {
            defaults.set(true, forKey: seedKey)
            return
        }

        if !defaults.bool(forKey: spheresKey), (try? modelContext.fetch(FetchDescriptor<Sphere>()).isEmpty) != false {
            for sphere in makeSixDefaultSpheres() {
                modelContext.insert(sphere)
            }
            defaults.set(true, forKey: spheresKey)
        }

        let sphereSort = SortDescriptor(\Sphere.orderIndex, order: .forward)
        let spheres = (try? modelContext.fetch(FetchDescriptor<Sphere>(sortBy: [sphereSort]))) ?? []
        guard !spheres.isEmpty else {
            defaults.set(true, forKey: seedKey)
            return
        }

        let today = Calendar.current.startOfDay(for: Date())
        let ruleDaily = RepeatingRule(startDate: today, weeklyFrequency: Array(1...7), monthlySpecificDays: [])

        var orderIndex = 0
        for (sphereIndex, sphere) in spheres.enumerated() {
            let g = sampleGoalLine(for: sphere.title)
            let goal = Goal(
                title: g.title,
                description: g.description,
                colorHex: sphere.colorHex,
                dueDate: today,
                reward: g.reward,
                status: .inProgress,
                orderIndex: orderIndex,
                sphereID: sphere.id,
                positiveImpact: 40,
                negativeImpact: 0
            )
            orderIndex += 1
            modelContext.insert(goal)

            let t = sampleTaskLine(for: sphere.title)
            let task = SuperTask(
                title: t.title,
                descript: t.detail,
                colorHex: sphere.colorHex,
                dueDate: today,
                repeating: sphereIndex % 2 == 0 ? .none : .weekly,
                status: .inProgress,
                orderIndex: orderIndex,
                subTasks: [],
                sphereID: sphere.id,
                goalID: goal.id,
                positiveImpact: 25,
                negativeImpact: 0,
                estimatedDuration: 30
            )
            orderIndex += 1
            modelContext.insert(task)

            let h = sampleHabitLine(for: sphere.title)
            let habit = Habit(
                title: h.title,
                colorHex: sphere.colorHex,
                iconName: h.icon,
                orderIndex: orderIndex,
                creationDate: today,
                initialRule: ruleDaily,
                sphereID: sphere.id,
                positiveImpact: 20,
                negativeImpact: 5
            )
            orderIndex += 1
            modelContext.insert(habit)

            let memo = makeSampleMemo(for: sphere, sphereIndex: sphereIndex, orderIndex: orderIndex, today: today)
            orderIndex += 1
            modelContext.insert(memo)
        }

        do {
            try modelContext.save()
            defaults.set(true, forKey: seedKey)
        } catch {
            print("Error seeding sample data:", error)
        }
    }

    // MARK: - Memo (6 типов по порядку сфер)

    private func makeSampleMemo(for sphere: Sphere, sphereIndex: Int, orderIndex: Int, today: Date) -> MemoItem {
        let encoder = JSONEncoder()
        let idx = sphereIndex % 6

        switch idx {
        case 0:
            let memo = MemoItem(title: "Starter notes", orderIndex: orderIndex, type: .noteAlbum, tags: ["sample"])
            let content = MemoNoteAlbumContent(
                notes: [
                    MemoNoteAlbumContent.NoteItem(
                        title: "Welcome",
                        content: "Sample notes for \(sphere.title).",
                        creationDate: today,
                        lastModified: today,
                        tags: []
                    )
                ],
                iconName: "note.text",
                customImageData: nil,
                colorHex: MemoItemType.noteAlbum.color.toHex() ?? "#007AFF",
                sphereID: sphere.id
            )
            memo.contentData = try? encoder.encode(content)
            return memo

        case 1:
            let memo = MemoItem(title: "Quick list", orderIndex: orderIndex, type: .list, tags: ["sample"])
            let content = MemoListContent(
                items: [
                    MemoListItem(text: "Reach out to someone", iconName: "message.fill"),
                    MemoListItem(text: "Plan a small outing", iconName: "calendar")
                ],
                iconName: "list.bullet",
                colorHex: sphere.colorHex,
                sphereID: sphere.id
            )
            memo.contentData = try? encoder.encode(content)
            return memo

        case 2:
            let memo = MemoItem(title: "Simple budget", orderIndex: orderIndex, type: .budget, tags: ["sample"])
            var content = MemoBudgetContent(
                budgets: [
                    MemoBudgetContent.BudgetItem(name: "Main", currentBalance: 2000, colorHex: sphere.colorHex)
                ],
                iconName: "dollarsign.circle",
                colorHex: sphere.colorHex,
                sphereID: sphere.id
            )
            content.initialBalance = 2000
            content.stepValue = 50
            memo.contentData = try? encoder.encode(content)
            return memo

        case 3:
            let memo = MemoItem(title: "Learning tracker", orderIndex: orderIndex, type: .skill, tags: ["sample"])
            var content = MemoSkillContent(
                skills: [
                    MemoSkillContent.SkillItem(
                        name: "Core practice",
                        currentLevel: 3,
                        targetLevel: 10,
                        iconName: "star.fill",
                        colorHex: sphere.colorHex
                    )
                ],
                iconName: "brain.head.profile",
                colorHex: sphere.colorHex,
                sphereID: sphere.id
            )
            content.stepValue = 1.0
            memo.contentData = try? encoder.encode(content)
            return memo

        case 4:
            let memo = MemoItem(title: "Health log", orderIndex: orderIndex, type: .health, tags: ["sample"])
            var content = MemoHealthContent()
            content.sphereID = sphere.id
            content.colorHex = sphere.colorHex
            content.initialValue = 70
            content.currentValue = 70
            content.unit = "kg"
            content.stepValue = 0.5
            content.entries = [MemoHealthContent.HealthEntry(date: today, value: 70, note: "Baseline")]
            memo.contentData = try? encoder.encode(content)
            return memo

        default:
            let memo = MemoItem(title: "Training time", orderIndex: orderIndex, type: .time, tags: ["sample"])
            var content = MemoTimeContent()
            content.sphereID = sphere.id
            content.colorHex = sphere.colorHex
            content.iconName = "clock.fill"
            content.initialMinutes = 0
            content.stepMinutes = 5
            content.currentMinutes = 30
            content.entries = [MemoTimeContent.TimeEntry(date: today, minutes: 30, note: "Sample session")]
            memo.contentData = try? encoder.encode(content)
            return memo
        }
    }

    // MARK: - Тексты для целей / задач / привычек

    private struct GoalLine { let title: String, description: String, reward: String }
    private struct TaskLine { let title: String, detail: String }
    private struct HabitLine { let title: String, icon: String }

    private func sampleGoalLine(for sphereTitle: String) -> GoalLine {
        switch sphereTitle {
        case "Mental":
            return GoalLine(title: "Morning meditation", description: "Short daily practice for focus.", reward: "Calm streak")
        case "Social":
            return GoalLine(title: "Meaningful connection", description: "Stay in touch with people who matter.", reward: "Quality time")
        case "Finance":
            return GoalLine(title: "Review spending", description: "Know where money goes each week.", reward: "Peace of mind")
        case "Skills":
            return GoalLine(title: "Deliberate practice", description: "Consistent time on one skill.", reward: "New project")
        case "Health":
            return GoalLine(title: "Move every day", description: "Walks, stretching, or workouts.", reward: "More energy")
        case "Sports":
            return GoalLine(title: "Train consistently", description: "Regular sessions you can sustain.", reward: "New gear")
        default:
            return GoalLine(title: "Starter goal", description: "Sample goal for \(sphereTitle).", reward: "Reward")
        }
    }

    private func sampleTaskLine(for sphereTitle: String) -> TaskLine {
        switch sphereTitle {
        case "Mental":
            return TaskLine(title: "10-minute breathing", detail: "Quiet spot, slow breaths.")
        case "Social":
            return TaskLine(title: "Send a check-in message", detail: "Text someone you miss.")
        case "Finance":
            return TaskLine(title: "Log recent expenses", detail: "Categories and totals.")
        case "Skills":
            return TaskLine(title: "One focused block", detail: "Timer on, phone away.")
        case "Health":
            return TaskLine(title: "20-minute walk", detail: "After lunch or evening.")
        case "Sports":
            return TaskLine(title: "Warm-up and session", detail: "Light mobility, then workout.")
        default:
            return TaskLine(title: "Sample task", detail: "For \(sphereTitle).")
        }
    }

    private func sampleHabitLine(for sphereTitle: String) -> HabitLine {
        switch sphereTitle {
        case "Mental":
            return HabitLine(title: "Evening reflection", icon: "moon.stars.fill")
        case "Social":
            return HabitLine(title: "One message a day", icon: "message.fill")
        case "Finance":
            return HabitLine(title: "Check balances", icon: "dollarsign.circle.fill")
        case "Skills":
            return HabitLine(title: "Learn 20 minutes", icon: "book.fill")
        case "Health":
            return HabitLine(title: "Drink water", icon: "drop.fill")
        case "Sports":
            return HabitLine(title: "Mobility round", icon: "figure.flexibility")
        default:
            return HabitLine(title: "Daily habit", icon: "star.fill")
        }
    }
}
