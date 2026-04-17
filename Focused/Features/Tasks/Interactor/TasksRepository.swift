import Foundation
import SwiftData

// MARK: - Tasks / слой Data (абстракция доступа к данным)
//
// **Repository + POP:** как `GoalsRepository` — сокрытие SwiftData от use case и тестовая подмена.

protocol TasksRepository: AnyObject {
    func fetchAllSortedByOrderIndex() throws -> [SuperTask]
    func fetchCount() throws -> Int
}
