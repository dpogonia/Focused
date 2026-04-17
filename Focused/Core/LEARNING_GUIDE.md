# Focused — гид по коду для начинающих

Этот документ дополняет комментарии в `ArchitectureStagesAndMap.swift` и в файлах папки `Core/`. Полный перевод каждого файла в репозитории не делается осознанно: правила и структура описаны здесь и в **двуязычных** блоках у ядра приложения.

**Шаблон для остальных модулей:** в `Features/Goals/` добавлены англоязычные пояснения у `FilterGoalsUseCase` и `SwiftDataGoalsRepository` — остальные фичи (Tasks, Habits, Memo) устроены так же: `Interactor` = сценарии, `Repository` = SwiftData.

---

## С чего начать (10–15 минут)

1. **`FocusedApp.swift`** — точка входа: `WindowGroup` → `ContentView`.
2. **`ContentView`** (в том же файле) — пять вкладок, `AppDependencies.live(modelContext:)`, `RootCoordinator`, общий календарь.
3. **`Core/ArchitectureStagesAndMap.swift`** — карта папок и этапы рефакторинга (RU вверху, **EN** внизу в том же файле).
4. Один фича-модуль целиком, например **`Features/Goals/`**:
   - `View/All Goals View.swift` — список;
   - `Interactor/FilterGoalsUseCase.swift` — отбор без UI;
   - `Repository/SwiftDataGoalsRepository.swift` — чтение/запись SwiftData;
   - `View/GoalsViewModel.swift` — связка экран ↔ use case.

---

## Зачем такие папки (простыми словами)

| Идея | Где в проекте | Зачем |
|------|----------------|--------|
| **Экран (UI)** | `Features/.../View/` | Кнопки, списки, формы. Не должны знать детали базы. |
| **Сценарий (use case)** | `Features/.../Interactor/` | «Показать цели на дату с фильтром» — чистая логика, без SwiftUI. |
| **Доступ к данным** | `Features/.../Repository/` | Реализация протоколов через `ModelContext` (SwiftData). |
| **Сборка зависимостей** | `Core/AppDependencies.swift`, `AppFactory.swift` | Один «контейнер»: что подставить в экраны и тесты. |
| **Общие штуки между вкладками** | `Shared/` | Календарь, общие модели, переиспользуемые view. |
| **Инфраструктура приложения** | `Services/` | Бэкап, демо-данные, сетевой Vision — не путать с «репозиторием одной сущности». |

Это близко к **VIPER/Clean**: **V**iew → **I**nteractor (use cases) → **R**epository → хранилище. Отдельной папки Presenter часто нет: **ViewModel** играет эту роль.

---

## Поток данных (упрощённо)

```
Пользователь тапает фильтр
    → View / ViewModel меняет состояние
    → ViewModel вызывает Filter*UseCase.execute(...)
    → Use case фильтрует массив моделей (или дергает Repository)
    → SwiftUI перерисовывает список
```

События «список мог устареть» иногда идут через **`NotificationCenter`** и тип **`AppEvent`** (`Core/Events/AppEvent.swift`), чтобы разные вкладки обновились без жёсткой связи.

---

## Навигация по вкладкам

- **`AppRootTab`** — перечисление вкладок (числа- теги для `TabView`).
- **`RootCoordinator`** — кто сейчас выбранная вкладка; позже сюда можно добавить маршруты (sheets).

---

## Словарь (RU ↔ EN)

| English | Русский |
|---------|---------|
| Composition root | Корень композиции / место, где собираются зависимости |
| Dependency injection (DI) | Внедрение зависимостей |
| Use case | Сценарий / прикладной случай |
| Repository | Репозиторий (абстракция хранилища) |
| Facade | Фасад (один простой вход к сложной подсистеме) |
| Coordinator | Координатор навигации |

---

## Где не искать логику домена

- **`Services/VisionAnalytics`** — конфигурация и вызовы аналитики Vision, не расчёт satisfaction сферы в UI.
- **`ImpactEngine`** — тяжёлая логика impact; для Vision предпочтительно **`SphereSatisfactionFacade`** из `AppDependencies`.

---

## Как добавить новую фичу в том же стиле

1. `Features/<Имя>/Interactor/` — протокол репозитория + use case(ы) + структуры фильтров.
2. `Features/<Имя>/Repository/` — `SwiftData*Repository`.
3. `Features/<Имя>/View/` — экраны и ViewModel.
4. Зарегистрировать фабрику в **`AppFactory`** и свойства в **`AppDependencies`**.
5. При необходимости — новое значение в **`AppEvent`** и подписка во view.

---

*Файл можно держать открытым рядом с Xcode при чтении кода.*
