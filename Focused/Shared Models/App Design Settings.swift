import SwiftUI
import SwiftData

// MARK: - App-wide Design Enum
enum AppDesign: String, Codable, CaseIterable, Identifiable {
    case basic
    case rainbow
    var id: String { rawValue }
}

// MARK: - App-wide Design Settings (SwiftData)
@Model
final class AppDesignSettings {
    var designString: String
    
    init(design: AppDesign = .basic) {
        self.designString = design.rawValue
    }
    
    var design: AppDesign {
        get {
            return AppDesign(rawValue: designString) ?? .basic
        }
        set {
            designString = newValue.rawValue
        }
    }
}


