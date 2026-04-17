import Foundation
import SwiftData

// MARK: - Interactor: расчёт удовлетворённости сферы
//
// Этот файл — граница **Interactor** для «impact» (влияние целей/задач/привычек/мемо на сферу).
//
// Паттерны:
// - **Protocol-Oriented Programming (POP)**: абстракция без привязки к конкретному классу
//   `ImpactEngine` → проще подменять в **unit-тестах** и превью.
// - Реализация по умолчанию: `ImpactEngine` в `Shared/Models/ImpactEngine.swift`
//   (тяжёлая математика по всем типам мемо).
//
// Связь с Clean Architecture: Use Case / Presenter (Vision) зависят от протокола,
// а не от деталей хранения или UI.

/// Контракт движка, который по снимку данных приложения оценивает «синтетическую»
/// удовлетворённость жизненной сферы (`Sphere`) в диапазоне 0…100.
protocol ImpactEngineProtocol {
    func calculateSatisfaction(
        for sphere: Sphere,
        goals: [Goal],
        tasks: [SuperTask],
        habits: [Habit],
        memoItems: [MemoItem]
    ) -> Double
}
