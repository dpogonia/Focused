import Foundation

// MARK: - Observer / уведомления между модулями
//
// **Observer** (через `NotificationCenter`): слабая связь — экраны и модели публикуют события
// (смена дизайна, статуса сущности, satisfaction сферы), подписчики обновляют UI без прямых ссылок друг на друга.
//
// **Этап 5:** типизированная обёртка — `Core/Events/AppEvent.swift` (`AppEvent`, `NotificationCenter.postAppEvent(_:)`).
// Имена здесь остаются источником правды для `AppEvent.notification`.

extension Notification.Name {
    static let appDesignDidChange = Notification.Name("AppDesignDidChangeNotification")
    static let appCalendarVisibilityDidChange = Notification.Name("AppCalendarVisibilityDidChangeNotification")
    static let taskStatusDidChange = Notification.Name("TaskStatusDidChangeNotification")
    static let goalStatusDidChange = Notification.Name("GoalStatusDidChangeNotification")
    static let habitStatusDidChange = Notification.Name("HabitStatusDidChangeNotification")
    static let memoStatusDidChange = Notification.Name("MemoStatusDidChangeNotification")
    static let sphereSatisfactionDidChange = Notification.Name("SphereSatisfactionDidChangeNotification")
}


