import Foundation

// MARK: - MVVM: ViewModel экрана «Привычки»
//
// Делегирует список на дату в `FilterHabitsUseCase`.

final class HabitsViewModel: ObservableObject {
    private let filterHabits: FilterHabitsUseCase

    init(filterHabits: FilterHabitsUseCase = FilterHabitsUseCase()) {
        self.filterHabits = filterHabits
    }

    func filteredHabits(
        allHabits: [Habit],
        selectedDate: Date,
        searchText: String,
        selectedSphereID: UUID?,
        selectedTag: String?,
        localShowCompletedHabits: Bool,
        localShowArchivedHabits: Bool
    ) -> [Habit] {
        let input = HabitsListFilterInput(
            selectedDate: selectedDate,
            searchText: searchText,
            selectedSphereID: selectedSphereID,
            selectedTag: selectedTag,
            localShowCompletedHabits: localShowCompletedHabits,
            localShowArchivedHabits: localShowArchivedHabits
        )
        return filterHabits.execute(habits: allHabits, input: input)
    }
}
