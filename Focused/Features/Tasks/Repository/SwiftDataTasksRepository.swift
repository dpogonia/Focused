import Foundation
import SwiftData

// Data · Tasks — SwiftData-адаптер для `TasksRepository` (создание через `AppFactory.makeTasksRepository`).

// MARK: - Реализация TasksRepository на SwiftData
//
// **Adapter:** см. `SwiftDataGoalsRepository` — тот же паттерн для `SuperTask`.

final class SwiftDataTasksRepository: TasksRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchAllSortedByOrderIndex() throws -> [SuperTask] {
        let descriptor = FetchDescriptor<SuperTask>(
            sortBy: [SortDescriptor(\SuperTask.orderIndex, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchCount() throws -> Int {
        try modelContext.fetchCount(FetchDescriptor<SuperTask>())
    }
}
