import Foundation
import SwiftData

// MARK: - Habits / слой Data (абстракция)
//
// **Repository:** см. `GoalsRepository` — тот же смысл для привычек (**POP** + тестовые подмены).

protocol HabitsRepository: AnyObject {
    func fetchAllSortedByOrderIndex() throws -> [Habit]
    func fetchCount() throws -> Int
}
