import Foundation

// Interactor · Goals — сценарий списка целей; использует `GoalsCalendarFilter` и вход `GoalsListFilterInput`.

// MARK: - Use Case: фильтрация и сортировка целей
//
// **Use Case (Clean Architecture):** один сценарий приложения — «показать список целей с учётом фильтров».
// Внутри используется `GoalsCalendarFilter` (**CalendarDayFiltering** / Strategy; см. `Calendar Filters.swift`).
//
// Чистая функция от входа `GoalsListFilterInput` — без `ModelContext` и без SwiftUI.
//
// EN — **Use case:** “Given all goals + filter input, return the list the UI should show.”
// No SwiftUI, no `ModelContext` — easy to unit-test. **Pattern:** Strategy via `GoalsCalendarFilter`.

/// Фильтрует и сортирует цели для экрана «Все цели».
/// EN: Filters/sorts goals for `AllGoalsView`; called from `GoalsViewModel`.
struct FilterGoalsUseCase {
    func execute(goals: [Goal], input: GoalsListFilterInput) -> [Goal] {
        var tempGoals = goals

        if !input.localShowArchivedGoals {
            tempGoals = tempGoals.filter { $0.status != .archived }
        }

        if input.calendarVisible {
            let calendarFilter = GoalsCalendarFilter(goals: tempGoals)
            tempGoals = calendarFilter.filterForDate(input.selectedDate)
        }

        if !input.searchText.isEmpty {
            let lower = input.searchText.lowercased()
            tempGoals = tempGoals.filter {
                $0.title.lowercased().contains(lower) ||
                ($0.descript?.lowercased().contains(lower) ?? false)
            }
        }

        if let selectedSphereID = input.selectedSphereID {
            tempGoals = tempGoals.filter { $0.sphereID == selectedSphereID }
        }

        if let selectedTag = input.selectedTag {
            tempGoals = tempGoals.filter { $0.tags.contains(where: { $0.name == selectedTag }) }
        }

        if !input.localShowCompletedGoals {
            tempGoals = tempGoals.filter { $0.status != .completed && $0.status != .missed }
        }

        tempGoals.sort { g1, g2 in
            if g1.isFlagged != g2.isFlagged {
                return g1.isFlagged && !g2.isFlagged
            }
            let g1IsCompleted = g1.status == .completed || g1.status == .missed
            let g2IsCompleted = g2.status == .completed || g2.status == .missed
            if g1IsCompleted != g2IsCompleted {
                return !g1IsCompleted && g2IsCompleted
            }
            if g1.status != g2.status {
                return g1.status < g2.status
            }
            if g1IsCompleted && g2IsCompleted {
                let d1 = g1.completedAt ?? g1.creationDate
                let d2 = g2.completedAt ?? g2.creationDate
                return d1 > d2
            }
            // Manual ordering should win for active goals; otherwise drag-reorder snaps back.
            if g1.orderIndex != g2.orderIndex {
                return g1.orderIndex < g2.orderIndex
            }
            if let due1 = g1.dueDate, let due2 = g2.dueDate {
                return due1 < due2
            }
            return g1.creationDate < g2.creationDate
        }

        return tempGoals
    }
}
