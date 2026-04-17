import Foundation
import SwiftData

// MARK: - Календарные фильтры (Strategy по фичам)
//
// **Этап 5:** общий протокол `CalendarDayFiltering` — явная **Strategy** для «отбор по выбранному дню».
// Реализации остаются прежними; use case’ы создают конкретный класс как раньше.

/// Стратегия отбора элементов по календарному дню (без SwiftUI / SwiftData запросов).
protocol CalendarDayFiltering {
    associatedtype Element
    func filterForDate(_ date: Date) -> [Element]
}

// MARK: - Goals Calendar Filter
class GoalsCalendarFilter: CalendarDayFiltering {
    typealias Element = Goal

    private let goals: [Goal]
    
    init(goals: [Goal]) {
        self.goals = goals
    }
    
    func filterForDate(_ date: Date) -> [Goal] {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        
        return goals.filter { goal in
            // Демо-цели из сида: дедлайн привязан к дню первого запуска — при смене дня в календаре иначе пропадали бы навсегда.
            if goal.isMockData {
                return true
            }
            // Фильтруем цели по дате создания или дедлайну
            if let dueDate = goal.dueDate {
                return calendar.isDate(dueDate, inSameDayAs: normalizedDate)
            }
            return calendar.isDate(goal.creationDate, inSameDayAs: normalizedDate)
        }
    }
}

// MARK: - Tasks Calendar Filter
class TasksCalendarFilter: CalendarDayFiltering {
    typealias Element = SuperTask

    private let tasks: [SuperTask]
    
    init(tasks: [SuperTask]) {
        self.tasks = tasks
    }
    
    func filterForDate(_ date: Date) -> [SuperTask] {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        
        return tasks.filter { task in
            if task.isMockData {
                return true
            }
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
class HabitsCalendarFilter: CalendarDayFiltering {
    typealias Element = Habit

    private let habits: [Habit]
    
    init(habits: [Habit]) {
        self.habits = habits
    }
    
    func filterForDate(_ date: Date) -> [Habit] {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        
        return habits.filter { habit in
            guard !habit.isArchived else { return false }
            return HabitLogicService(habit: habit).isScheduled(on: normalizedDate)
        }
    }
}

// MARK: - Memo Calendar Filter
class MemoCalendarFilter: CalendarDayFiltering {
    typealias Element = MemoItem

    private let memoItems: [MemoItem]
    
    init(memoItems: [MemoItem]) {
        self.memoItems = memoItems
    }
    
    func filterForDate(_ date: Date) -> [MemoItem] {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        
        return memoItems.filter { memo in
            if memo.isMockData {
                return true
            }
            // Фильтруем мемо по дате создания
            return calendar.isDate(memo.creationDate, inSameDayAs: normalizedDate)
        }
    }
}

