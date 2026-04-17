import Foundation

// MARK: - Вход use case «список привычек на дату»
//
// `selectedDate` должен быть нормализован (startOfDay), как раньше в `HabitsViewModel`.

struct HabitsListFilterInput {
    /// Normalized to start of day (callers match previous `HabitsViewModel` contract).
    var selectedDate: Date
    var searchText: String
    var selectedSphereID: UUID?
    var selectedTag: String?
    var localShowCompletedHabits: Bool
    var localShowArchivedHabits: Bool
}
