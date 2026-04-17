import Foundation

// MARK: - Корневые вкладки TabView (этап 4: Coordinator)
//
// Один тип для **всех** `.tag(...)` в `ContentView`, чтобы не путать «магические числа» 1…5.
// `rawValue` совпадает с прежними тегами — поведение переключения вкладок не меняется.
//
// EN — **Tab identity:** replaces magic integers in `.tag(...)`; `Int` raw values stay compatible with old TabView tags.

/// Идентификатор вкладки главного `TabView` приложения.
/// EN: Main `TabView` tab tags (Vision=1 … Memo=5).
enum AppRootTab: Int, Hashable, CaseIterable, Identifiable {
    case vision = 1
    case goals = 2
    case tasks = 3
    case habits = 4
    case memo = 5

    var id: Int { rawValue }
}
