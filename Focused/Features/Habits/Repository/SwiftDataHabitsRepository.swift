import Foundation
import SwiftData

// Data · Habits — SwiftData-адаптер для `HabitsRepository`.

// MARK: - Реализация HabitsRepository на SwiftData
//
// **Adapter:** запросы к `ModelContext` по контракту `HabitsRepository` (Interactor не знает про SwiftData).

final class SwiftDataHabitsRepository: HabitsRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchAllSortedByOrderIndex() throws -> [Habit] {
        let descriptor = FetchDescriptor<Habit>(
            sortBy: [SortDescriptor(\Habit.orderIndex, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchCount() throws -> Int {
        try modelContext.fetchCount(FetchDescriptor<Habit>())
    }
}
