import SwiftData

// MARK: - AppFactory (явная фабрика зависимостей)
//
// Контекст этапов 0–6: `ArchitectureStagesAndMap.swift`.
//
// **Зачем отдельный файл:** `AppDependencies` хранит только `ModelContext` и **делегирует** создание
// конкретных типов сюда — так видно единое место, где выбираются реализации (**Factory Method** /
// **Abstract Factory** в терминах GoF).
//
// **Что создаём:**
// - репозитории SwiftData (**Adapter** к persistence);
// - use case’ы (чистая логика);
// - Facade’ы домена (`SphereSatisfactionFacade`);
// - при необходимости тесты подставляют другие фабрики или моки через отдельные `make*` с параметрами.
//
// **Не дублировать:** синглтоны вроде `ImpactEngine.shared` допустимы **только** как значения по умолчанию
// аргументов фабрики — UI не импортирует их напрямую.
//
// EN — **Factory:** single place that chooses concrete types (which `*Repository`, which use case).
// **Why:** tests can swap a `make*` overload or inject mocks without editing every screen.

/// Централизованное создание объектов для composition root (`AppDependencies`).
/// EN: Centralized constructors for everything `AppDependencies` exposes.
enum AppFactory {

    // MARK: - Composition root

    /// Собирает контейнер зависимостей на один жизненный цикл `ModelContext` (как прежний `live`).
    @MainActor
    static func makeAppDependencies(modelContext: ModelContext) -> AppDependencies {
        AppDependencies(modelContext: modelContext)
    }

    // MARK: - Impact / Vision

    /// Дефолтный движок impact — `ImpactEngine.shared`; в тестах передайте заглушку `ImpactEngineProtocol`.
    static func makeSphereSatisfactionFacade(engine: ImpactEngineProtocol = ImpactEngine.shared) -> SphereSatisfactionFacade {
        SphereSatisfactionFacade(engine: engine)
    }

    // MARK: - Repositories

    static func makeGoalsRepository(modelContext: ModelContext) -> GoalsRepository {
        SwiftDataGoalsRepository(modelContext: modelContext)
    }

    static func makeTasksRepository(modelContext: ModelContext) -> TasksRepository {
        SwiftDataTasksRepository(modelContext: modelContext)
    }

    static func makeHabitsRepository(modelContext: ModelContext) -> HabitsRepository {
        SwiftDataHabitsRepository(modelContext: modelContext)
    }

    static func makeMemoItemsRepository(modelContext: ModelContext) -> MemoItemsRepository {
        SwiftDataMemoItemsRepository(modelContext: modelContext)
    }

    // MARK: - Use cases

    static func makeFilterGoalsUseCase() -> FilterGoalsUseCase {
        FilterGoalsUseCase()
    }

    static func makeFilterTasksUseCase() -> FilterTasksUseCase {
        FilterTasksUseCase()
    }

    static func makeFilterHabitsUseCase() -> FilterHabitsUseCase {
        FilterHabitsUseCase()
    }

    static func makeFilterMemoItemsUseCase() -> FilterMemoItemsUseCase {
        FilterMemoItemsUseCase()
    }
}
