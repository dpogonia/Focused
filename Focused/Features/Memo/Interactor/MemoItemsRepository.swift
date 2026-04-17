import Foundation
import SwiftData

// MARK: - Memo / слой Data (абстракция)
//
// **Repository:** явные выборки для счётчиков и тестов; список на экране может по-прежнему идти из `@Query`.

protocol MemoItemsRepository: AnyObject {
    func fetchAllSortedByCreationDateDescending() throws -> [MemoItem]
    func fetchCount() throws -> Int
}
