import Foundation

// MARK: - Сортировка списка Memo (Interactor + UI)
//
// Вынесено из `AllMemoView`, чтобы **Use Case** не зависел от конкретного View.
// `CaseIterable` — для меню и Picker в SwiftUI.

/// Порядок сортировки элементов на экране «Все мемо».
enum MemoListSortOrder: String, CaseIterable, Identifiable {
    case newest
    case oldest
    case alphabetical
    case type
    /// Порядок из `MemoItem.orderIndex` (после перетаскивания в списке).
    case manual

    var id: String { rawValue }
}
