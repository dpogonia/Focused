import SwiftUI
import SwiftData
import Charts

// MARK: Доменные типы и модели мемо
//
// Разные виды мемо (заметка, счётчик, время, …) и общие перечисления. Фильтрация списка — `FilterMemoItemsUseCase` + `MemoCalendarFilter`.
// Оглавление: период статистики → тип мемо и `MemoItem` → модификатор тапов → настройки.

// MARK: Период статистики (Counter, Time, Health, Streak, Budget, Skills)
enum MemoStatsPeriod: String, CaseIterable, Identifiable {
    case week = "Week"
    case month = "Month"
    case year = "Year"
    case all = "All"
    
    var id: String { rawValue }
    
    func startDate(from endDate: Date = Date()) -> Date? {
        let calendar = Calendar.current
        switch self {
        case .week: return calendar.date(byAdding: .day, value: -7, to: endDate)
        case .month: return calendar.date(byAdding: .month, value: -1, to: endDate)
        case .year: return calendar.date(byAdding: .year, value: -1, to: endDate)
        case .all: return nil
        }
    }
}

// MARK: Тип мемо, статус, SwiftData `MemoItem`
enum MemoItemType: String, Codable, CaseIterable, Identifiable {
    case noteAlbum = "Note Album"
    case list = "List"
    case counter = "Counter"
    case streak = "Streak"
    case mood = "Mood"
    case skill = "Skill"
    case budget = "Budget"
    case time = "Time"
    case health = "Health"
    case calendar = "Calendar"
    
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
        case .calendar: "calendar"
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
        case .calendar: Color(hex: "#5856D6") // iOS purple
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
        case .noteAlbum: "Note Album"
        case .list: "List"
        case .counter: "Counter"
        case .streak: "Streak"
        case .mood: "Mood"
        case .skill: "Skill"
        case .budget: "Budget"
        case .time: "Time"
        case .health: "Health"
        case .calendar: "Calendar"
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
    var descript: String?
    var creationDate: Date
    var orderIndex: Int
    var itemTypeRawValue: String
    @Attribute(.externalStorage) var contentData: Data?
    var tags: [String] = []
    var statusRawValue: String = MemoStatus.active.rawValue
    var isMockData: Bool = false
    
    init(title: String, description: String? = nil, orderIndex: Int, type: MemoItemType, tags: [String] = [], status: MemoStatus = .active, isMockData: Bool = false) {
        self.id = UUID()
        self.title = title
        self.descript = description
        self.creationDate = Date()
        self.orderIndex = orderIndex
        self.itemTypeRawValue = type.rawValue
        self.tags = tags
        self.statusRawValue = status.rawValue
        self.isMockData = isMockData
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
        switch itemTypeRawValue {
        case "Заметка", "Альбом заметок": return .noteAlbum
        case "Список": return .list
        case "Счетчик": return .counter
        case "Стрик": return .streak
        case "Настроение": return .mood
        case "Навык": return .skill
        case "Бюджет": return .budget
        case "Время": return .time
        case "Здоровье": return .health
        case "Calendar", "Календарь": return .calendar
        default: return .noteAlbum
        }
    }
}

// MARK: Модификатор: одинарный тап — просмотр, двойной — редактор
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

// MARK: Настройки списка мемо (SwiftData)
@Model
final class MemoSettings {
    /// Storage name kept for backwards compatibility (historically used as "completed").
    var showCompletedMemos: Bool
    
    /// Semantic alias: controls visibility of archived memo items.
    var showArchivedMemos: Bool {
        get { showCompletedMemos }
        set { showCompletedMemos = newValue }
    }
    /// `MemoListSortOrder.rawValue`; `nil` — как раньше, по сути «newest» в UI.
    var listSortOrderRaw: String?

    init(showArchivedMemos: Bool = false, listSortOrderRaw: String? = nil) {
        self.showCompletedMemos = showArchivedMemos
        self.listSortOrderRaw = listSortOrderRaw
    }
}
