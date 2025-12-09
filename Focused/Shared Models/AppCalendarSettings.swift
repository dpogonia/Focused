import SwiftUI
import SwiftData

// MARK: - App-wide Calendar Settings (SwiftData)
@Model
final class AppCalendarSettings {
    var isVisible: Bool
    
    init(isVisible: Bool = true) {
        self.isVisible = isVisible
    }
}
