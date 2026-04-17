import Foundation
import SwiftData

// Data · Memo — SwiftData-адаптер для `MemoItemsRepository`.

// MARK: - Реализация MemoItemsRepository на SwiftData
//
// **Adapter:** изоляция persistence от `FilterMemoItemsUseCase`.

final class SwiftDataMemoItemsRepository: MemoItemsRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchAllSortedByCreationDateDescending() throws -> [MemoItem] {
        let descriptor = FetchDescriptor<MemoItem>(
            sortBy: [SortDescriptor(\MemoItem.creationDate, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchCount() throws -> Int {
        try modelContext.fetchCount(FetchDescriptor<MemoItem>())
    }
}
