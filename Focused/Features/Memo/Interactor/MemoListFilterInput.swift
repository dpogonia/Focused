import Foundation

// MARK: - Вход use case «список мемо»
//
// DTO для `FilterMemoItemsUseCase`.

struct MemoListFilterInput {
    var selectedDate: Date
    var calendarVisible: Bool
    var searchText: String
    var selectedTypeFilter: MemoItemType?
    var selectedTagFilter: String?
    var showArchivedMemos: Bool
}
