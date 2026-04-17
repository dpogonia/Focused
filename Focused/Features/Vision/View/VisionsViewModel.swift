import Foundation
import SwiftData

// MARK: - View: ViewModel вкладки Vision
//
// Файл лежит в **`Features/Vision/View/`** вместе с остальным модулем экрана (этап 4: единое место для Vision).
//
// **MVVM:** View (`VisionsView`) держит `@StateObject` на этот тип; здесь нет SwiftUI, только оркестрация.
//
// Зависимости (внедряются через init — **Dependency Injection**):
// - `VisionAnalyticsServicing` — сеть/AI (**Adapter** к внешнему API), реализация в `Services/VisionAnalytics/VisionAnalyticsService.swift`;
// - `SphereSatisfactionFacade` — **Facade** над доменным расчётом satisfaction (см. `Features/Impact`).
//
// Так ViewModel не знает ни URL, ни весов в `ImpactEngine` — проще тестировать и менять реализации.

final class VisionsViewModel: ObservableObject {
    private let analyticsService: VisionAnalyticsServicing
    private let sphereSatisfaction: SphereSatisfactionFacade

    init(
        analyticsService: VisionAnalyticsServicing = VisionAnalyticsService.shared,
        sphereSatisfaction: SphereSatisfactionFacade = SphereSatisfactionFacade()
    ) {
        self.analyticsService = analyticsService
        self.sphereSatisfaction = sphereSatisfaction
    }

    /// UI-метка для визуализаций (круг, линейка, …). Делегирует Facade → `ImpactEngine`.
    func computedSatisfaction(
        for sphere: Sphere,
        goals: [Goal],
        tasks: [SuperTask],
        habits: [Habit],
        memoItems: [MemoItem]
    ) -> Double {
        sphereSatisfaction.calculatedSatisfaction(
            for: sphere,
            goals: goals,
            tasks: tasks,
            habits: habits,
            memoItems: memoItems
        )
    }

    func generateAIVision(
        for sphere: Sphere,
        type: VisionsView.AIType,
        goals: [Goal],
        tasks: [SuperTask],
        habits: [Habit],
        memoItems: [MemoItem]
    ) async -> String {
        switch type {
        case .visionAI:
            return await analyticsService.generateLifetimeVision(
                for: sphere,
                goals: goals,
                tasks: tasks,
                habits: habits
            )
        case .analyticsAI:
            return await analyticsService.generateAnalyticsAdvice(
                for: sphere,
                goals: goals,
                tasks: tasks,
                habits: habits,
                memoItems: memoItems
            )
        }
    }
}
