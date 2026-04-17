import Foundation

// MARK: - Реализация ImpactEngineProtocol (Interactor)
//
// **Роль:** «тяжёлый» движок доменной логики — агрегирует цели, задачи, привычки и **все** типы Memo
// в один показатель удовлетворённости сферы. Один файл — одна ответственность (**SRP**), но большой объём.
//
// **Паттерны:**
// - Реализует `ImpactEngineProtocol` (**POP**) — подмена в тестах / превью.
// - В продакшене не обращайтесь к `shared` из View: используйте `AppFactory.makeSphereSatisfactionFacade()` /
//   `AppDependencies.sphereSatisfactionFacade`. В **unit-тестах** подставляйте заглушку:
//   `AppFactory.makeSphereSatisfactionFacade(engine: yourMock)`.
// - Для экрана Vision снаружи лучше вызывать `SphereSatisfactionFacade`, чтобы не тянуть детали сюда из ViewModel.
//
// Centralized engine for calculating progress and impact across the app.
/// It provides a single, extendable place where sphere satisfaction can be
/// recomputed from goals, tasks, habits and all memo types.
final class ImpactEngine: ImpactEngineProtocol {
    static let shared = ImpactEngine()
    
    private init() {}
    
    struct Profile {
        let goalCompletedWeight: Double
        let goalInProgressWeight: Double
        let taskCompletedWeight: Double
        let habitCompletionWeight: Double
        let memoPositiveWeight: Double
        let memoNegativeWeight: Double
        let memoActivityWeight: Double
    }
    
    private let profile = Profile(
        goalCompletedWeight: 3.0,
        goalInProgressWeight: 1.5,
        taskCompletedWeight: 0.5,
        habitCompletionWeight: 0.8,
        memoPositiveWeight: 1.0,
        memoNegativeWeight: 1.0,
        memoActivityWeight: 0.5
    )
    
    // MARK: - Public API
    
    func calculateSatisfaction(
        for sphere: Sphere,
        goals: [Goal],
        tasks: [SuperTask],
        habits: [Habit],
        memoItems: [MemoItem]
    ) -> Double {
        var score: Double = 0
        
        // Goals impact
        let sphereGoals = goals.filter { $0.sphereID == sphere.id }
        for goal in sphereGoals {
            switch goal.status {
            case .completed:
                score += profile.goalCompletedWeight * (1.0 + max(0.0, goal.positiveImpact - goal.negativeImpact))
            case .inProgress:
                score += profile.goalInProgressWeight * (1.0 + max(0.0, goal.positiveImpact - goal.negativeImpact))
            default:
                break
            }
        }
        
        // Tasks impact
        let sphereTasks = tasks.filter { $0.sphereID == sphere.id }
        for task in sphereTasks {
            let status = SuperTask.Status(rawValue: task.status) ?? .inProgress
            if status == .completed {
                score += profile.taskCompletedWeight * (1.0 + max(0.0, task.positiveImpact - task.negativeImpact))
            }
        }
        
        // Habits impact – use completion statistics for the last 30 days
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let startDate = calendar.date(byAdding: .day, value: -30, to: today) ?? today
        
        let sphereHabits = habits.filter { $0.sphereID == sphere.id && !$0.isArchived }
        for habit in sphereHabits {
            let logic = HabitLogicService(habit: habit)
            var completedDays = 0
            var scheduledDays = 0
            var date = startDate
            while date <= today {
                if logic.isScheduled(on: date) {
                    scheduledDays += 1
                    if habit.isCompletedHabit(on: date) {
                        completedDays += 1
                    }
                }
                date = calendar.date(byAdding: .day, value: 1, to: date) ?? today
            }
            if scheduledDays > 0 {
                let ratio = Double(completedDays) / Double(scheduledDays)
                score += profile.habitCompletionWeight * ratio * (1.0 + max(0.0, habit.positiveImpact - habit.negativeImpact))
            }
        }
        
        // All memo types impact
        let memoScore = totalMemoImpact(for: sphere, memoItems: memoItems)
        score += memoScore
        
        // Normalize to 0...100 and blend with stored satisfaction as baseline
        let normalized = max(0.0, min(100.0, score))
        let blended = (sphere.satisfaction * 0.6) + (normalized * 0.4)
        
        return max(0.0, min(100.0, blended))
    }
    
    // MARK: - Private helpers
    
    private func totalMemoImpact(for sphere: Sphere, memoItems: [MemoItem]) -> Double {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let last30Days = calendar.date(byAdding: .day, value: -30, to: today) ?? today
        
        return memoItems.reduce(0.0) { partial, memo in
            guard let data = memo.contentData else { return partial }
            var total = partial
            
            switch memo.itemType {
            case .counter:
                total += counterImpact(for: sphere, data: data)
                
            case .streak:
                total += streakImpact(for: sphere, data: data, since: last30Days)
                
            case .mood:
                total += moodImpact(for: sphere, data: data, since: last30Days)
                
            case .health:
                total += healthImpact(for: sphere, data: data, since: last30Days)
                
            case .skill:
                total += skillImpact(for: sphere, data: data, since: last30Days)
                
            case .budget:
                total += budgetImpact(for: sphere, data: data)
                
            case .time:
                total += timeImpact(for: sphere, data: data, since: last30Days)
                
            case .list:
                total += listImpact(for: sphere, data: data)
                
            case .noteAlbum:
                break
                
            case .calendar:
                total += calendarImpact(for: sphere, data: data)
            }
            
            return total
        }
    }
    
    // MARK: - Counter Impact
    private func counterImpact(for sphere: Sphere, data: Data) -> Double {
        guard let content = try? JSONDecoder().decode(MemoCounterContent.self, from: data) else {
            return 0.0
        }

        // Impact from counters is counted only when the target is reached
        guard
            let target = content.targetValue,
            target > 0,
            content.currentValue >= target
        else {
            return 0.0
        }
        
        var impact = 0.0
        
        if content.sphereID == sphere.id {
            impact += profile.memoPositiveWeight * max(0.0, content.positiveImpact)
        }
        
        for imp in content.additionalImpacts where imp.sphereID == sphere.id {
            impact += profile.memoPositiveWeight * max(0.0, imp.positiveImpact)
        }
        
        return impact
    }
    
    // MARK: - Streak Impact
    private func streakImpact(for sphere: Sphere, data: Data, since startDate: Date) -> Double {
        guard let content = try? JSONDecoder().decode(MemoStreakContent.self, from: data) else {
            return 0.0
        }
        
        var impact = 0.0
        
        // Direct sphere impact from positive/negative settings
        if content.sphereID == sphere.id {
            impact += profile.memoPositiveWeight * max(0.0, content.positiveImpact)
            impact -= profile.memoNegativeWeight * max(0.0, content.negativeImpact)
            
            // Bonus for streak consistency in last 30 days (count check entries)
            let recentChecks = content.checkHistory.filter { entry in
                entry.date >= startDate
            }
            let streakBonus = Double(recentChecks.count) * 0.1
            impact += profile.memoActivityWeight * streakBonus
        }
        
        for imp in content.additionalImpacts where imp.sphereID == sphere.id {
            impact += profile.memoPositiveWeight * max(0.0, imp.positiveImpact)
            impact -= profile.memoNegativeWeight * max(0.0, imp.negativeImpact)
        }
        
        return impact
    }
    
    // MARK: - List Impact
    private func listImpact(for sphere: Sphere, data: Data) -> Double {
        guard let content = try? JSONDecoder().decode(MemoListContent.self, from: data),
              content.sphereID == sphere.id else {
            return 0.0
        }
        
        var impact = 0.0
        impact += profile.memoPositiveWeight * max(0.0, content.positiveImpact)
        impact -= profile.memoNegativeWeight * max(0.0, content.negativeImpact)
        
        for imp in content.additionalImpacts where imp.sphereID == sphere.id {
            impact += profile.memoPositiveWeight * max(0.0, imp.positiveImpact)
            impact -= profile.memoNegativeWeight * max(0.0, imp.negativeImpact)
        }
        
        return impact
    }
    
    // MARK: - Mood Impact
    private func moodImpact(for sphere: Sphere, data: Data, since startDate: Date) -> Double {
        guard let content = try? JSONDecoder().decode(MemoMoodContent.self, from: data),
              content.sphereID == sphere.id else {
            return 0.0
        }
        
        var impact = 0.0
        
        // Direct sphere impact from positive/negative settings
        impact += profile.memoPositiveWeight * max(0.0, content.positiveImpact)
        impact -= profile.memoNegativeWeight * max(0.0, content.negativeImpact)
        
        for imp in content.additionalImpacts where imp.sphereID == sphere.id {
            impact += profile.memoPositiveWeight * max(0.0, imp.positiveImpact)
            impact -= profile.memoNegativeWeight * max(0.0, imp.negativeImpact)
        }
        
        let recentEntries = content.entries.filter { $0.date >= startDate }
        if !recentEntries.isEmpty {
            let avgMood = Double(recentEntries.reduce(0) { $0 + $1.value }) / Double(recentEntries.count)
            let normalizedMood = avgMood / Double(content.scale)
            if normalizedMood >= 0.6 {
                impact += profile.memoActivityWeight * (normalizedMood - 0.5) * 2.0
            } else if normalizedMood < 0.4 {
                impact -= profile.memoActivityWeight * (0.5 - normalizedMood) * 2.0
            }
        }
        
        return impact
    }
    
    // MARK: - Health Impact
    private func healthImpact(for sphere: Sphere, data: Data, since startDate: Date) -> Double {
        guard let content = try? JSONDecoder().decode(MemoHealthContent.self, from: data),
              content.sphereID == sphere.id else {
            return 0.0
        }
        
        let recentEntries = content.entries.filter { $0.date >= startDate }
        guard !recentEntries.isEmpty else { return 0.0 }
        
        // Positive changes = good, negative changes = bad
        let netChange = recentEntries.reduce(0.0) { $0 + $1.value }
        
        if netChange > 0 {
            return profile.memoActivityWeight * min(netChange * 0.1, 2.0)
        } else if netChange < 0 {
            return -profile.memoActivityWeight * min(abs(netChange) * 0.1, 2.0)
        }
        
        return 0.0
    }
    
    // MARK: - Skill Impact
    private func skillImpact(for sphere: Sphere, data: Data, since startDate: Date) -> Double {
        guard let content = try? JSONDecoder().decode(MemoSkillContent.self, from: data),
              content.sphereID == sphere.id else {
            return 0.0
        }
        
        var impact = 0.0
        
        // Direct sphere impact from positive/negative settings
        impact += profile.memoPositiveWeight * max(0.0, content.positiveImpact)
        impact -= profile.memoNegativeWeight * max(0.0, content.negativeImpact)
        
        for imp in content.additionalImpacts where imp.sphereID == sphere.id {
            impact += profile.memoPositiveWeight * max(0.0, imp.positiveImpact)
            impact -= profile.memoNegativeWeight * max(0.0, imp.negativeImpact)
        }
        
        for skill in content.skills {
            let recentHistory = skill.history.filter { $0.date >= startDate }
            guard !recentHistory.isEmpty else { continue }
            
            // Calculate level growth
            let sortedHistory = recentHistory.sorted { $0.date < $1.date }
            if let first = sortedHistory.first, let last = sortedHistory.last {
                let growth = last.level - first.level
                if growth > 0 {
                    impact += profile.memoActivityWeight * growth * 0.5
                }
            }
            
            // Bonus for activity frequency
            let activityBonus = Double(recentHistory.count) * 0.05
            impact += profile.memoActivityWeight * activityBonus
        }
        
        return impact
    }
    
    // MARK: - Budget Impact
    private func budgetImpact(for sphere: Sphere, data: Data) -> Double {
        guard let content = try? JSONDecoder().decode(MemoBudgetContent.self, from: data),
              content.sphereID == sphere.id else {
            return 0.0
        }
        
        var impact = 0.0
        
        for budget in content.budgets {
            // Positive balance = good financial health
            if budget.currentBalance > 0 {
                impact += profile.memoActivityWeight * min(budget.currentBalance / 1000.0, 2.0)
            } else if budget.currentBalance < 0 {
                impact -= profile.memoActivityWeight * min(abs(budget.currentBalance) / 1000.0, 2.0)
            }
        }
        
        return impact
    }
    
    // MARK: - Calendar Impact
    private func calendarImpact(for sphere: Sphere, data: Data) -> Double {
        guard let content = try? JSONDecoder().decode(MemoCalendarContent.self, from: data),
              content.sphereID == sphere.id else {
            return 0.0
        }
        
        var impact = 0.0
        impact += profile.memoPositiveWeight * max(0.0, content.positiveImpact)
        impact -= profile.memoNegativeWeight * max(0.0, content.negativeImpact)
        
        for imp in content.additionalImpacts where imp.sphereID == sphere.id {
            impact += profile.memoPositiveWeight * max(0.0, imp.positiveImpact)
            impact -= profile.memoNegativeWeight * max(0.0, imp.negativeImpact)
        }
        
        // Activity bonus based on number of days with entries (last 30 days)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let last30Days = calendar.date(byAdding: .day, value: -30, to: today) ?? today
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let recentEntriesCount = content.entries.keys.filter { key in
            guard let d = formatter.date(from: key), d >= last30Days else { return false }
            return !(content.entries[key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }.count
        impact += profile.memoActivityWeight * Double(recentEntriesCount) * 0.05
        
        return impact
    }
    
    // MARK: - Time Impact
    private func timeImpact(for sphere: Sphere, data: Data, since startDate: Date) -> Double {
        guard let content = try? JSONDecoder().decode(MemoTimeContent.self, from: data),
              content.sphereID == sphere.id else {
            return 0.0
        }
        
        var impact = 0.0
        
        // Direct sphere impact from positive/negative settings
        impact += profile.memoPositiveWeight * max(0.0, content.positiveImpact)
        impact -= profile.memoNegativeWeight * max(0.0, content.negativeImpact)
        
        for imp in content.additionalImpacts where imp.sphereID == sphere.id {
            impact += profile.memoPositiveWeight * max(0.0, imp.positiveImpact)
            impact -= profile.memoNegativeWeight * max(0.0, imp.negativeImpact)
        }
        
        let recentEntries = content.entries.filter { $0.date >= startDate }
        if !recentEntries.isEmpty {
            // Time invested = positive impact
            let totalMinutes = recentEntries.reduce(0.0) { $0 + max(0, $1.minutes) }
            let hoursInvested = totalMinutes / 60.0
            impact += profile.memoActivityWeight * min(hoursInvested * 0.1, 3.0)
        }
        
        return impact
    }
}
