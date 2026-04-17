import SwiftData
import SwiftUI

// MARK: - Composition Root (внедрение зависимостей)
//
// Сводка этапов и карта папок: `ArchitectureStagesAndMap.swift`.
//
// **Что это:** единая «фабрика» зависимостей на один `ModelContext`, живёт в SwiftUI **Environment**
// (см. `ContentView.appDependencies(...)`).
//
// **Паттерны:**
// - **Dependency Injection (DI)** — экраны получают репозитории/use case’ы не через синглтоны внутри View,
//   а из одного места (проще подменять в тестах).
// - **Factory** — конкретные классы создаёт `AppFactory` (`Core/AppFactory.swift`); этот тип только хранит
//   `modelContext` и проксирует вызовы фабрики.
// - **Repository** — абстракции доступа к данным; **Use Case** — чистые сценарии без UI.
//
// **Слои (VIPER-ориентир):** View → Interactor (use cases / facades) → Repository → SwiftData.
//
// **Сервисы приложения** (бэкап, сид, Vision AI) лежат в `Focused/Services/...` — см. этап 3 рефакторинга.
// Навигация по корневым вкладкам — `Core/Navigation/RootCoordinator` (этап 4).
//
// EN — **Composition root:** holds one `ModelContext` and exposes factories for repositories/use cases.
// Views use `@Environment(\.appDependencies)` instead of calling singletons for data access.
// **Learning:** open `LEARNING_GUIDE.md` in this folder for a step-by-step tour.

/// Корневой контейнер зависимостей приложения. Собирается в `ContentView` и наследуется вкладками TabView.
/// EN: App-wide DI container; built once per `ContentView` and passed down via `.appDependencies(...)`.
struct AppDependencies {
    let modelContext: ModelContext

    /// Удобная фабрика для превью и тестов (делегирует `AppFactory.makeAppDependencies`).
    @MainActor
    static func live(modelContext: ModelContext) -> AppDependencies {
        AppFactory.makeAppDependencies(modelContext: modelContext)
    }

    // MARK: - Impact / Vision (Facade + Interactor)

    /// **Facade** над `ImpactEngine` — предпочтительная зависимость для Vision-слоя.
    var sphereSatisfactionFacade: SphereSatisfactionFacade {
        AppFactory.makeSphereSatisfactionFacade()
    }

    // MARK: - Goals

    var goalsRepository: GoalsRepository {
        AppFactory.makeGoalsRepository(modelContext: modelContext)
    }

    var filterGoalsUseCase: FilterGoalsUseCase {
        AppFactory.makeFilterGoalsUseCase()
    }

    // MARK: - Tasks

    var tasksRepository: TasksRepository {
        AppFactory.makeTasksRepository(modelContext: modelContext)
    }

    var filterTasksUseCase: FilterTasksUseCase {
        AppFactory.makeFilterTasksUseCase()
    }

    // MARK: - Habits

    var habitsRepository: HabitsRepository {
        AppFactory.makeHabitsRepository(modelContext: modelContext)
    }

    var filterHabitsUseCase: FilterHabitsUseCase {
        AppFactory.makeFilterHabitsUseCase()
    }

    // MARK: - Memo

    var memoItemsRepository: MemoItemsRepository {
        AppFactory.makeMemoItemsRepository(modelContext: modelContext)
    }

    var filterMemoItemsUseCase: FilterMemoItemsUseCase {
        AppFactory.makeFilterMemoItemsUseCase()
    }
}

// MARK: - SwiftUI Environment
//
// Зависимости пробрасываются вниз по дереву View **без глобальных синглтонов** для данных
// (синглтоны вроде `ImpactEngine.shared` допустимы внутри фабрик, но не в каждой View).
//
// Если `appDependencies == nil` (например, превью), экраны используют `AppDependencies.live(modelContext:)`.

private enum AppDependenciesKey: EnvironmentKey {
    static let defaultValue: AppDependencies? = nil
}

extension EnvironmentValues {
    var appDependencies: AppDependencies? {
        get { self[AppDependenciesKey.self] }
        set { self[AppDependenciesKey.self] = newValue }
    }
}

extension View {
    /// Подключает контейнер ко всем дочерним View (аналог «корня DI» в SwiftUI).
    func appDependencies(_ dependencies: AppDependencies) -> some View {
        environment(\.appDependencies, dependencies)
    }
}
