import Foundation

// MARK: - MVVM: ViewModel экрана «Цели»
//
// **Роль:** тонкий адаптер между SwiftUI и доменом — собирает `GoalsListFilterInput` и отдаёт его в
// `FilterGoalsUseCase` (**Use Case**). Сам по себе не ходит в SwiftData: данные приходят из `@Query` во View.
//
// **DI:** в init можно подставить другой `FilterGoalsUseCase` (например, с мок-правилами) для тестов.

final class GoalsViewModel: ObservableObject {
    private let filterGoals: FilterGoalsUseCase

    init(filterGoals: FilterGoalsUseCase = FilterGoalsUseCase()) {
        self.filterGoals = filterGoals
    }

    func filteredGoals(
        allGoals: [Goal],
        selectedDate: Date,
        calendarVisible: Bool,
        globalCalendarSettings: [AppCalendarSettings],
        searchText: String,
        selectedSphereID: UUID?,
        selectedTag: String?,
        localShowCompletedGoals: Bool,
        localShowArchivedGoals: Bool
    ) -> [Goal] {
        let input = GoalsListFilterInput(
            selectedDate: selectedDate,
            calendarVisible: calendarVisible,
            globalCalendarSettings: globalCalendarSettings,
            searchText: searchText,
            selectedSphereID: selectedSphereID,
            selectedTag: selectedTag,
            localShowCompletedGoals: localShowCompletedGoals,
            localShowArchivedGoals: localShowArchivedGoals
        )
        return filterGoals.execute(goals: allGoals, input: input)
    }
}
