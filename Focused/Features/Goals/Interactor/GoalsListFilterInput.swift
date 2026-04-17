import Foundation

// MARK: - Входные данные сценария «список целей»
//
// Структура без методов — **DTO / Input model** для `FilterGoalsUseCase`.
// Отделена от SwiftUI, чтобы правила фильтрации можно было unit-тестировать.

/// Параметры фильтрации списка целей (не зависят от View).
struct GoalsListFilterInput {
    var selectedDate: Date
    var calendarVisible: Bool
    /// Reserved for future calendar rules tied to global settings; kept for API compatibility with the previous `GoalsViewModel` signature.
    var globalCalendarSettings: [AppCalendarSettings]
    var searchText: String
    var selectedSphereID: UUID?
    var selectedTag: String?
    var localShowCompletedGoals: Bool
    var localShowArchivedGoals: Bool
}
