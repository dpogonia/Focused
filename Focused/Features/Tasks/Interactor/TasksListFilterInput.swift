import Foundation

// MARK: - Вход use case «список задач»
//
// DTO для `FilterTasksUseCase` — отвязан от SwiftUI state.

struct TasksListFilterInput {
    var selectedDate: Date
    var calendarVisible: Bool
    var searchText: String
    var selectedSphereID: UUID?
    var selectedTag: String?
    var selectedStatus: SuperTask.Status?
    var localShowCompletedTasks: Bool
    var localShowArchivedTasks: Bool
}
