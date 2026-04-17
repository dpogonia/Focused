import Foundation

// MARK: - Справочник этапов рефакторинга и карта каталогов
//
// Этот файл **только документирует** договорённости; исполняемая логика — в `AppDependencies`, `AppFactory` и остальных модулях.
// Новичку: читайте сверху вниз, затем откройте указанные файлы в Xcode.
// Подробный разбор для обучения — файл **LEARNING_GUIDE.md** в этой же папке `Core/`.
//
// **Имена папок в духе VIPER:** `Interactor` (сценарии и контракты репозиториев), `Repository` (реализации доступа к SwiftData),
// `View` (SwiftUI и ViewModel — во многих модулях ViewModel выполняет роль **Presenter** без отдельной папки).
// Отдельно не выделены `Entity` (модели в `Shared/Models/` и рядом с UI) и `Router` (навигация в `Core/Navigation/`).

// MARK: Статус этапов 0…6 (честно)
//
// **Этап 0 — карта модулей; пустой AppDependencies / Factory; подключение без смены поведения**  
// ✅ Сделано: `AppDependencies`, `AppFactory`, `.appDependencies(...)` в `ContentView` (`App/FocusedApp.swift`).
//
// **Этап 1 — Repository + протоколы для одного feature; ViewModel → use cases**  
// ✅ Сделано: образец применён к Goals, Tasks, Habits, Memo — `Features/<Имя>/Interactor` + `Repository/SwiftData*Repository.swift`, ViewModel’ы вызывают `Filter*UseCase`.
//
// **Этап 2 — остальные features по шаблону; Impact в Interactor + Facade**  
// ✅ Сделано: `Features/Impact/Interactor` (`ImpactEngineProtocol`, `SphereSatisfactionFacade`), реализация движка в `Shared/Models/ImpactEngine.swift`.
//
// **Этап 3 — сервисы в отдельные папки; Vision: протокол + реализация + конфиг извне**  
// ✅ Сделано: `Services/Backup`, `Services/SampleData`, `Services/VisionAnalytics` (+ `VisionAnalyticsConfiguration`, секреты не в коде).
//
// **Этап 4 — Coordinator для табов; единый модуль Vision**  
// ✅ Сделано: `RootCoordinator`, `AppRootTab`, UI и `VisionsViewModel` в `Features/Vision/View/` (отдельно от `Services/VisionAnalytics`).
//
// **Этап 5 — Observer; стратегии фильтров; зачистка синглтонов из домена**  
// ⚠️ Частично: типизированные события `AppEvent` + `postAppEvent`, протокол `CalendarDayFiltering` (**Strategy**) в `Shared/Models/Calendar Filters.swift`.  
// Полная «зачистка» `.shared` из слоя View не завершена: осознанно остаются `HapticSoundManager`, `SampleDataSeeder`, `BackupService`, `VisionAnalyticsService`, `ImpactEngine` и т.д. — следующий шаг: постепенно пробрасывать через `AppDependencies` там, где нужны тесты/подмена.
//
// **Этап 6 — полировка тестов; краткие границы в коде; опционально SPM**  
// ⚠️ Частично: таргет `FocusedTests`, общая схема с Test action. **SPM-пакеты не выделены** — при росте проекта имеет смысл вынести `Core` + `Features/*/Interactor` в пакеты.

// MARK: Карта каталогов (куда смотреть)
//
// | Папка | Роль |
// |-------|------|
// | `Core/` | Composition root (`AppDependencies`, `AppFactory`), события (`AppEvent`), навигация вкладок (`RootCoordinator`, `AppRootTab`), этот справочник |
// | `App/` | Точка входа (`@main`), ассеты, ресурсы |
// | `Features/<Feature>/Interactor/` | Протоколы репозиториев, **Use Case**’ы, структуры ввода фильтров (**VIPER I** + границы домена) |
// | `Features/<Feature>/Repository/` | **Адаптеры** к SwiftData: `SwiftData*Repository` + `ModelContext` (**доступ к данным**; не путать с корневым `Services/`) |
// | `Features/<Feature>/View/` | SwiftUI, ViewModel, карточки и формы (**VIPER V**; ViewModel ≈ Presenter). Пример **Memo**: `AllMemo/`, `EditMemo/`, `Cards/` (карточка в сетке), `MemoKinds/` (UI по типу мемо) |
// | `Services/` | Инфраструктура приложения: бэкап, сид, HTTP Vision (**не** смешивать с расчётом satisfaction) |
// | `Shared/Models/`, `Shared/Views/` | Пересечение вкладок: календарь, уведомления, движок impact, общие вью |

// MARK: - English: folder map & refactor stages (for beginners)
//
// This file is **documentation only**. Executable code lives in `AppDependencies`, `AppFactory`, and feature modules.
//
// **How to read the app (learning path):**
// 1. `App/FocusedApp.swift` → `ContentView` (TabView, `.appDependencies`, `CalendarManager`).
// 2. `Core/AppDependencies.swift` + `Core/AppFactory.swift` → how repositories and use cases are created (DI / composition root).
// 3. Pick one feature, e.g. `Features/Goals/`: `View/` (SwiftUI) → `Interactor/` (filter use case, protocols) → `Repository/` (SwiftData).
// 4. Cross-cutting UI: `Shared/Views/`; cross-cutting models: `Shared/Models/`.
//
// **Folder roles (VIPER-ish naming):**
// | Folder | Role |
// |--------|------|
// | `Core/` | Composition root, `AppEvent`, tab navigation (`RootCoordinator`, `AppRootTab`), this map |
// | `App/` | `@main`, assets |
// | `Features/<Name>/Interactor/` | Repository protocols, **use cases**, filter input structs (**domain boundary**) |
// | `Features/<Name>/Repository/` | SwiftData adapters (`SwiftData*Repository`) — **persistence**, not `Services/` |
// | `Features/<Name>/View/` | SwiftUI + ViewModels (often act as **Presenter**) |
// | `Services/` | App infrastructure: backup, sample seed, Vision analytics HTTP |
// | `Shared/` | Shared models, calendar filters, reusable views |
//
// **Refactor stages 0…6 (honest status):**
// - **0** Done: `AppDependencies`, `AppFactory`, `.appDependencies` in `ContentView`.
// - **1** Done: Goals, Tasks, Habits, Memo use `Interactor` + `Repository` + ViewModels calling `Filter*UseCase`.
// - **2** Done: Impact in `Features/Impact/Interactor`, engine in `Shared/Models/ImpactEngine.swift`.
// - **3** Done: `Services/Backup`, `SampleData`, `VisionAnalytics`.
// - **4** Done: `RootCoordinator`, `AppRootTab`, Vision UI in `Features/Vision/`.
// - **5** Partial: `AppEvent` + `postAppEvent`, `CalendarDayFiltering` strategy; some singletons still used from views.
// - **6** Partial: tests target exists; SPM split not done.
//
// **Search tip:** type `ArchitectureStagesReference` in Xcode (⇧⌘O) to jump here.

/// Якорь для поиска в проекте: введите «ArchitectureStagesReference» в Xcode (⇧⌘O).
/// Подробный текст — в комментариях **в начале этого файла** (см. `MARK` выше).
enum ArchitectureStagesReference {
    /// Единственный кейс-заглушка: смысл файла — в комментариях сверху, не в этом типе.
    case documentationAnchor
}
