import Foundation
import SwiftData

// MARK: - Facade над ImpactEngine
//
// **Facade** (порождающий/структурный паттерн GoF): даёт **одну точку входа** для экрана Vision,
// не заставляя ViewModel знать про веса, типы мемо и внутренние helper’ы `ImpactEngine`.
//
// Зачем:
// - проще читать `VisionsViewModel` (вызов одного метода);
// - при необходимости можно добавить кэш, логирование или вторую стратегию расчёта,
//   не трогая UI;
// - тесты могут подставить лёгкий `ImpactEngineProtocol` без полного движка.
//
// Внутри делегирует тому же `ImpactEngineProtocol`, что и раньше — поведение приложения не меняется.
//
// EN — **Facade:** one method for Vision instead of importing `ImpactEngine` weights/helpers in the ViewModel.
// **Learning:** compare `VisionsViewModel` before/after — it should only talk to this type + `AppDependencies.sphereSatisfactionFacade`.

/// Единая обёртка для расчёта satisfaction сферы для модуля Vision.
/// EN: Thin wrapper around `ImpactEngineProtocol` for Vision tab and tests.
final class SphereSatisfactionFacade {
    private let engine: ImpactEngineProtocol

    init(engine: ImpactEngineProtocol = ImpactEngine.shared) {
        self.engine = engine
    }

    /// Делегирует `ImpactEngineProtocol.calculateSatisfaction` — семантика 1:1 с прежним кодом.
    func calculatedSatisfaction(
        for sphere: Sphere,
        goals: [Goal],
        tasks: [SuperTask],
        habits: [Habit],
        memoItems: [MemoItem]
    ) -> Double {
        engine.calculateSatisfaction(
            for: sphere,
            goals: goals,
            tasks: tasks,
            habits: habits,
            memoItems: memoItems
        )
    }
}
