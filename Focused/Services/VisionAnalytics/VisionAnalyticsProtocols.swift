import Foundation
import SwiftData

// MARK: - Папка `Services/VisionAnalytics` (этап 3)
//
// Здесь: протокол `VisionAnalyticsServicing`, реализация `VisionAnalyticsService`, `VisionAnalyticsConfiguration`.
// Расчёт satisfaction по-прежнему в `Features/Impact` — не смешиваем домен и HTTP.
//
// **Паттерн:** протокол = контракт (**POP**), реализация = **Adapter** к внешнему API.

protocol VisionAnalyticsServicing {
    func generateLifetimeVision(
        for sphere: Sphere,
        goals: [Goal],
        tasks: [SuperTask],
        habits: [Habit]
    ) async -> String
    
    func generateAnalyticsAdvice(
        for sphere: Sphere,
        goals: [Goal],
        tasks: [SuperTask],
        habits: [Habit],
        memoItems: [MemoItem]
    ) async -> String
}
