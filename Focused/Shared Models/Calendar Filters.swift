import Foundation
import SwiftData

// MARK: - Goals Calendar Filter
class GoalsCalendarFilter {
    private let goals: [Goal]
    
    init(goals: [Goal]) {
        self.goals = goals
    }
    
    func filterForDate(_ date: Date) -> [Goal] {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        
        return goals.filter { goal in
            // Фильтруем цели по дате создания или дедлайну
            if let dueDate = goal.dueDate {
                return calendar.isDate(dueDate, inSameDayAs: normalizedDate)
            }
            return calendar.isDate(goal.creationDate, inSameDayAs: normalizedDate)
        }
    }
}

// MARK: - Tasks Calendar Filter
class TasksCalendarFilter {
    private let tasks: [SuperTask]
    
    init(tasks: [SuperTask]) {
        self.tasks = tasks
    }
    
    func filterForDate(_ date: Date) -> [SuperTask] {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        
        return tasks.filter { task in
            // Фильтруем задачи по дате создания, дедлайну или последнему изменению
            if let dueDate = task.dueDate {
                return calendar.isDate(dueDate, inSameDayAs: normalizedDate)
            }
            return calendar.isDate(task.creationDate, inSameDayAs: normalizedDate) ||
                   calendar.isDate(task.lastModifiedDate, inSameDayAs: normalizedDate)
        }
    }
}

// MARK: - Habits Calendar Filter
class HabitsCalendarFilter {
    private let habits: [Habit]
    
    init(habits: [Habit]) {
        self.habits = habits
    }
    
    func filterForDate(_ date: Date) -> [Habit] {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        
        return habits.filter { habit in
            // Фильтруем привычки, которые запланированы на эту дату
            return HabitLogicService(habit: habit).isScheduled(on: normalizedDate)
        }
    }
}

// MARK: - Memo Calendar Filter
class MemoCalendarFilter {
    private let memoItems: [MemoItem]
    
    init(memoItems: [MemoItem]) {
        self.memoItems = memoItems
    }
    
    func filterForDate(_ date: Date) -> [MemoItem] {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        
        return memoItems.filter { memo in
            // Фильтруем мемо по дате создания
            return calendar.isDate(memo.creationDate, inSameDayAs: normalizedDate)
        }
    }
}

