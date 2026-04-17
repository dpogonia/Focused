import SwiftUI
import SwiftData

// Domain + Persistence — видимость календаря на экранах списков. Изменения → `AppEvent.appCalendarVisibilityDidChange`.

// MARK: - App-wide Calendar Settings (SwiftData)
@Model
final class AppCalendarSettings {
    var isVisible: Bool
    /// Сфера, цвет которой используется для точки «сегодня» в календаре (синхронизируется с выбором на Vision).
    var accentSphereID: UUID?
    
    init(isVisible: Bool = true, accentSphereID: UUID? = nil) {
        self.isVisible = isVisible
        self.accentSphereID = accentSphereID
    }
}
