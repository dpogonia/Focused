import SwiftUI // 28!!
import SwiftData
import Charts

// MARK: - Data Models
enum MemoItemType: String, Codable, CaseIterable, Identifiable {
    case noteAlbum = "Альбом заметок"
    case list = "Список"
    case counter = "Счетчик"
    case streak = "Стрик"
    case mood = "Настроение"
    case skill = "Навык"
    case budget = "Бюджет"
    case time = "Время"
    case health = "Здоровье"
    case tracker = "Трекер"
    
    var id: String { self.rawValue }
    
    var iconName: String {
        switch self {
        case .noteAlbum: "note.text"
        case .list: "list.bullet"
        case .counter: "number.circle"
        case .streak: "flame"
        case .mood: "face.smiling"
        case .skill: "brain.head.profile"
        case .budget: "dollarsign.circle"
        case .time: "clock"
        case .health: "heart.circle"
        case .tracker: "chart.line.uptrend.xyaxis"
        }
    }
    
    var color: Color {
        switch self {
        case .noteAlbum: Color(hex: "#007AFF") // iOS blue
        case .list: Color(hex: "#34C759") // iOS green
        case .counter: Color(hex: "#FF9500") // iOS orange
        case .streak: Color(hex: "#FF3B30") // iOS red
        case .mood: Color(hex: "#FF2D55") // iOS pink
        case .skill: Color(hex: "#5E5CE6") // iOS indigo
        case .budget: Color(hex: "#00C7BE") // iOS mint
        case .time: Color(hex: "#32ADE6") // iOS cyan
        case .health: Color(hex: "#E6332A") // Health red
        case .tracker: Color(hex: "#30B0C7") // iOS teal
        }
    }

    var gradient: LinearGradient {
        LinearGradient(
            colors: [color.opacity(0.8), color],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var displayName: String {
        switch self {
        case .noteAlbum: "Альбом заметок"
        case .list: "Список"
        case .counter: "Счетчик"
        case .streak: "Стрик"
        case .mood: "Настроение"
        case .skill: "Навык"
        case .budget: "Бюджет"
        case .time: "Время"
        case .health: "Здоровье"
        case .tracker: "Трекер"
        }
    }
}

enum MemoStatus: String, Codable {
    case active = "active"
    case archived = "archived"
}

@Model
final class MemoItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var creationDate: Date
    var orderIndex: Int
    var itemTypeRawValue: String
    @Attribute(.externalStorage) var contentData: Data?
    var tags: [String] = []
    var statusRawValue: String = MemoStatus.active.rawValue
    
    init(title: String, orderIndex: Int, type: MemoItemType, tags: [String] = [], status: MemoStatus = .active) {
        self.id = UUID()
        self.title = title
        self.creationDate = Date()
        self.orderIndex = orderIndex
        self.itemTypeRawValue = type.rawValue
        self.tags = tags
        self.statusRawValue = status.rawValue
    }
    
    var status: MemoStatus {
        get {
            MemoStatus(rawValue: statusRawValue) ?? .active
        }
        set {
            statusRawValue = newValue.rawValue
        }
    }
    
    var itemType: MemoItemType {
        if let type = MemoItemType(rawValue: itemTypeRawValue) {
            return type
        }
        if itemTypeRawValue == "Заметка" {
            return .noteAlbum
        }
        return .noteAlbum
    }
}

// MARK: - Memo Tap Behavior Modifier
struct MemoTapBehavior: ViewModifier {
    let item: MemoItem
    let openEditor: () -> Void
    let openViewer: () -> Void
    
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                TapGesture()
                    .onEnded { _ in openViewer() }
            )
            .simultaneousGesture(
                TapGesture(count: 2)
                    .onEnded { _ in openEditor() }
            )
    }
}

// MARK: - Memo Settings Model
@Model
final class MemoSettings {
    var showCompletedMemos: Bool
    
    init(showCompletedMemos: Bool = true) {
        self.showCompletedMemos = showCompletedMemos
    }
}
