import Foundation

// MARK: - MVVM: ViewModel экрана «Задачи»
//
// См. `GoalsViewModel` — тот же шаблон: делегирование в `FilterTasksUseCase`.

final class TasksViewModel: ObservableObject {
    private let filterTasks: FilterTasksUseCase

    init(filterTasks: FilterTasksUseCase = FilterTasksUseCase()) {
        self.filterTasks = filterTasks
    }

    func filteredTasks(
        allTasks: [SuperTask],
        selectedDate: Date,
        calendarVisible: Bool,
        searchText: String,
        selectedSphereID: UUID?,
        selectedTag: String?,
        selectedStatus: SuperTask.Status?,
        localShowCompletedTasks: Bool,
        localShowArchivedTasks: Bool
    ) -> [SuperTask] {
        let input = TasksListFilterInput(
            selectedDate: selectedDate,
            calendarVisible: calendarVisible,
            searchText: searchText,
            selectedSphereID: selectedSphereID,
            selectedTag: selectedTag,
            selectedStatus: selectedStatus,
            localShowCompletedTasks: localShowCompletedTasks,
            localShowArchivedTasks: localShowArchivedTasks
        )
        return filterTasks.execute(tasks: allTasks, input: input)
    }
}
