import Foundation

// MARK: ViewModel списка мемо (MVVM)
//
// Оборачивает `FilterMemoItemsUseCase`.

final class MemoListViewModel: ObservableObject {
    private let filterMemoItems: FilterMemoItemsUseCase

    init(filterMemoItems: FilterMemoItemsUseCase = FilterMemoItemsUseCase()) {
        self.filterMemoItems = filterMemoItems
    }

    func filteredItems(
        memoItems: [MemoItem],
        selectedDate: Date,
        calendarVisible: Bool,
        searchText: String,
        selectedTypeFilter: MemoItemType?,
        selectedTagFilter: String?,
        showArchivedMemos: Bool
    ) -> [MemoItem] {
        let input = MemoListFilterInput(
            selectedDate: selectedDate,
            calendarVisible: calendarVisible,
            searchText: searchText,
            selectedTypeFilter: selectedTypeFilter,
            selectedTagFilter: selectedTagFilter,
            showArchivedMemos: showArchivedMemos
        )
        return filterMemoItems.execute(memoItems: memoItems, input: input)
    }
}
