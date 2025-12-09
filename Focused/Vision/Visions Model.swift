import SwiftUI
import SwiftData

// MARK: - SPHERE DATA MODEL
@Model
final class Sphere: Identifiable, Equatable {
    @Attribute(.unique) var id: UUID
    var title: String
    var satisfaction: Double
    var colorHex: String
    var iconName: String
    var orderIndex: Int
    var analyticsAI: String = ""
    var visionAI: String = ""
    
    init(title: String, satisfaction: Double, colorHex: String, iconName: String, orderIndex: Int, analyticsAI: String = "", visionAI: String = "") {
        self.id = UUID()
        self.title = title
        self.satisfaction = satisfaction
        self.colorHex = colorHex
        self.iconName = iconName
        self.orderIndex = orderIndex
        self.analyticsAI = analyticsAI
        self.visionAI = visionAI
    }
    
    static func ==(lhs: Sphere, rhs: Sphere) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - VISIONS SETTINGS AND STYLE
@Model
final class VisionsSettings {
    var styleRawValue: String
    var showIcons: Bool
    var showDashedLines: Bool?
    var showFiftyPercent: Bool?
    
    init(style: VisionsStyle = .circle, showIcons: Bool = true, showDashedLines: Bool? = nil, showFiftyPercent: Bool? = nil) {
        self.styleRawValue = style.rawValue
        self.showIcons = showIcons
        self.showDashedLines = showDashedLines ?? false
        self.showFiftyPercent = showFiftyPercent ?? false
    }
    
    var style: VisionsStyle {
        get { VisionsStyle(rawValue: styleRawValue) ?? .circle }
        set { styleRawValue = newValue.rawValue }
    }
}

enum VisionsStyle: String, Codable, CaseIterable, Identifiable {
    case circle
    case bars
    case linear
    case radar
    var id: String { rawValue }
}

// MARK: - OPEN ROUTER RESPONSE MODEL
struct OpenRouterResponse: Decodable {
    let choices: [Choice]
    struct Choice: Decodable {
        let message: Message
        struct Message: Decodable {
            let content: String
        }
    }
}
