import Foundation

// Interactor · Tasks — use case списка задач; чистая функция от `TasksListFilterInput` и массива `SuperTask`.

// MARK: - Use Case: фильтрация задач
//
// Аналог `FilterGoalsUseCase`: календарь через `TasksCalendarFilter` (**Strategy** по дате).

struct FilterTasksUseCase {
    func execute(tasks: [SuperTask], input: TasksListFilterInput) -> [SuperTask] {
        var tempTasks = tasks

        if !input.localShowArchivedTasks {
            tempTasks = tempTasks.filter { $0.statusEnum != .archived }
        }

        if input.calendarVisible {
            let calendarFilter = TasksCalendarFilter(tasks: tempTasks)
            tempTasks = calendarFilter.filterForDate(input.selectedDate)
        }

        if !input.searchText.isEmpty {
            let lower = input.searchText.lowercased()
            tempTasks = tempTasks.filter {
                $0.title.lowercased().contains(lower) ||
                ($0.descript?.lowercased().contains(lower) ?? false)
            }
        }

        if let selectedSphereID = input.selectedSphereID {
            tempTasks = tempTasks.filter { $0.sphereID == selectedSphereID }
        }

        if let selectedTag = input.selectedTag {
            tempTasks = tempTasks.filter { $0.tags.contains(where: { $0.name == selectedTag }) }
        }

        if let selectedStatus = input.selectedStatus {
            tempTasks = tempTasks.filter { $0.statusEnum == selectedStatus }
        }

        if !input.localShowCompletedTasks {
            tempTasks = tempTasks.filter { $0.statusEnum != .completed }
        }

        tempTasks.sort { t1, t2 in
            if t1.statusEnum != t2.statusEnum {
                return t1.statusEnum < t2.statusEnum
            }
            if let due1 = t1.dueDate, let due2 = t2.dueDate {
                return due1 < due2
            }
            return t1.orderIndex < t2.orderIndex
        }

        return tempTasks
    }
}
