import Foundation

// MARK: - Типизированный слой над NotificationCenter (этап 5)
//
// **Observer:** подписчики по-прежнему используют `Notification.Name` — обратная совместимость.
// `AppEvent` даёт **перечисление** известных событий приложения: автодополнение, меньше опечаток в строках,
// проще искать все места публикации.
//
// Новый код предпочитает `AppEvent.*` и `NotificationCenter.default.postAppEvent(...)`.
// Старый код с `Notification.Name.appDesignDidChange` можно мигрировать постепенно.
//
// EN — **Typed notifications:** avoids string typos; `postAppEvent(.memoStatusDidChange)` is easier to find than raw `Notification.Name`.
// **When to use:** refresh lists on another tab after save/delete without tight coupling between modules.

/// Известные межмодульные события (сопоставлены с `Notification.Name` в `Notifications.swift`).
/// EN: Strongly typed app-wide events; each case maps 1:1 to a `Notification.Name` in `Notifications.swift`.
enum AppEvent: String, CaseIterable {
    case appDesignDidChange
    case appCalendarVisibilityDidChange
    case taskStatusDidChange
    case goalStatusDidChange
    case habitStatusDidChange
    case memoStatusDidChange
    case sphereSatisfactionDidChange

    /// Тот же объект `Notification.Name`, что и раньше — один канал доставки.
    var notification: Notification.Name {
        switch self {
        case .appDesignDidChange: return .appDesignDidChange
        case .appCalendarVisibilityDidChange: return .appCalendarVisibilityDidChange
        case .taskStatusDidChange: return .taskStatusDidChange
        case .goalStatusDidChange: return .goalStatusDidChange
        case .habitStatusDidChange: return .habitStatusDidChange
        case .memoStatusDidChange: return .memoStatusDidChange
        case .sphereSatisfactionDidChange: return .sphereSatisfactionDidChange
        }
    }

    /// Обратное сопоставление для отладки / логов.
    init?(notification: Notification.Name) {
        guard let match = AppEvent.allCases.first(where: { $0.notification == notification }) else {
            return nil
        }
        self = match
    }
}

extension NotificationCenter {
    /// Публикация типизированного события (обёртка над `post(name:object:userInfo:)`).
    /// Имя `postAppEvent` — чтобы не пересекаться по смыслу с `post(Notification)`.
    func postAppEvent(_ event: AppEvent, object: Any? = nil, userInfo: [AnyHashable: Any]? = nil) {
        post(name: event.notification, object: object, userInfo: userInfo)
    }
}
