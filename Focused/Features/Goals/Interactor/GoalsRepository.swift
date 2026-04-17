import Foundation
import SwiftData

// MARK: - Goals / слой Data (абстракция)
//
// **Repository (DDD / Clean Architecture):** скрывает SwiftData от Use Case и ViewModel.
// View по-прежнему может использовать `@Query`, а репозиторий — для явных запросов (count, тесты, фон).
//
// **POP:** протокол позволяет подставить in-memory реализацию в тестах.

/// Доступ к агрегату «цели»: выборки и количество записей.
protocol GoalsRepository: AnyObject {
    func fetchAllSortedByOrderIndex() throws -> [Goal]
    func fetchCount() throws -> Int
}
