import SwiftUI

// MARK: - Корневой Coordinator (навигация по вкладкам)
//
// **Паттерн Coordinator:** отделяет решение «какая вкладка активна» от содержимого вкладок.
// Сейчас это тонкая обёртка над состоянием `TabView`; позже сюда же можно добавить
// глубокие маршруты (sheet, fullScreen) без раздувания `ContentView`.
//
// **Как подключать:** `@StateObject` в `ContentView`, проброс `.environmentObject(...)` вниз,
// чтобы любой экран мог вызвать `selectTab(_:)` (например, из дашборда).
//
// EN — **Coordinator pattern:** keeps tab selection out of each feature screen; `ContentView` binds `TabView` to `selectedTab`.
// **Beginner tip:** deep linking / global “go to Memo tab” can call `selectTab(.memo)` from any child with `@EnvironmentObject`.

@MainActor
final class RootCoordinator: ObservableObject {
    /// Текущая вкладка; по умолчанию Vision — как раньше при `selectedTab = 1`.
    /// EN: Backing property for `TabView(selection:)`; default `.vision` matches legacy tag `1`.
    @Published var selectedTab: AppRootTab = .vision

    func selectTab(_ tab: AppRootTab) {
        selectedTab = tab
    }
}
