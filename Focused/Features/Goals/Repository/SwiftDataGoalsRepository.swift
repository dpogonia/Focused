import Foundation
import SwiftData

// Data · Goals — адаптер `GoalsRepository` к SwiftData (`FetchDescriptor`). Создаётся из `AppFactory`.

// MARK: - Реализация GoalsRepository на SwiftData
//
// **Adapter:** переводит вызовы репозитория в `FetchDescriptor` / `modelContext.fetch`.
// Знает о `@Model Goal`, но Use Case — нет.
//
// EN — **Repository implementation:** the only place here that touches SwiftData for goals.
// **Interactor** depends on `GoalsRepository` protocol, not this class — swap for mocks in tests.

final class SwiftDataGoalsRepository: GoalsRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchAllSortedByOrderIndex() throws -> [Goal] {
        let descriptor = FetchDescriptor<Goal>(
            sortBy: [SortDescriptor(\Goal.orderIndex, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchCount() throws -> Int {
        try modelContext.fetchCount(FetchDescriptor<Goal>())
    }
}
