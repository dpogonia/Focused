import Foundation

// Interactor · Memo — сценарий «список мемо с фильтрами» (Clean Architecture / Use Case).
// Зависит от `MemoListFilterInput`, `MemoCalendarFilter` (Strategy).

// MARK: - Use Case: фильтрация мемо
//
// Календарный фильтр: `MemoCalendarFilter`.

struct FilterMemoItemsUseCase {
    func execute(memoItems: [MemoItem], input: MemoListFilterInput) -> [MemoItem] {
        var items = memoItems

        if input.calendarVisible {
            let calendarFilter = MemoCalendarFilter(memoItems: items)
            items = calendarFilter.filterForDate(input.selectedDate)
        }

        if !input.searchText.isEmpty {
            let lower = input.searchText.lowercased()
            items = items.filter { item in
                item.title.lowercased().contains(lower) ||
                (item.contentData != nil &&
                 String(data: item.contentData!, encoding: .utf8)?
                    .lowercased()
                    .contains(lower) == true)
            }
        }

        if let selectedType = input.selectedTypeFilter {
            items = items.filter { $0.itemType == selectedType }
        }

        if let selectedTag = input.selectedTagFilter {
            items = items.filter { $0.tags.contains(selectedTag) }
        }

        if !input.showArchivedMemos {
            items = items.filter { $0.status == .active }
        }

        // Единственный источник порядка — `orderIndex` (как в Goals/Tasks/Habits):
        // это обеспечивает «возврат на прежнюю позицию» при archive/unarchive и любых status-переключениях,
        // без дополнительных сущностей состояния.
        items.sort { item1, item2 in
            if item1.status != item2.status {
                return item1.status == .active
            }
            if item1.orderIndex != item2.orderIndex {
                return item1.orderIndex < item2.orderIndex
            }
            if item1.creationDate != item2.creationDate {
                return item1.creationDate > item2.creationDate
            }
            return item1.id.uuidString < item2.id.uuidString
        }

        return items
    }
}
