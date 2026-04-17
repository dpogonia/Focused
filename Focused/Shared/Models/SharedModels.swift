import SwiftUI
import SwiftData
import AVFoundation

// MARK: - Общие доменные и вспомогательные типы
//
// Теги, счётчики и др., которые делят несколько вкладок. **Persistence:** SwiftData `@Model` / value types.
// Правила отображения списков и календаря живут в **Use Case** и `Calendar Filters`, не здесь — иначе нарушится **SRP**.

// MARK: - Tag Model
@Model
class Tag {
    var name: String
    
    init(name: String) {
        self.name = name
    }
}

// MARK: - COUNTER MODEL
@Model
final class Counter: Identifiable {
    var id: UUID
    var name: String
    var current: Int
    var target: Int
    
    init(name: String, current: Int = 0, target: Int) {
        self.id = UUID()
        self.name = name
        self.current = current
        self.target = target
    }
    
    func increment() {
        if current < target {
            current += 1
        }
    }
    
    func decrement() {
        if current > 0 {
            current -= 1
        }
    }
}

// MARK: - App Constants
/// Единый каталог SF Symbols для выбора иконки во всём приложении (Goals, Habits, Spheres, Memo, `MediaCirclePicker`).
let availableHabitIcons: [String] = [
    "heart", "face.smiling", "person", "person.2", "person.3.sequence", "person.crop.square.on.square.angled",
    "figure.stand", "figure.stand.dress", "figure.2.and.child.holdinghands", "figure.and.child.holdinghands",
    "bubble.left", "stroller", "teddybear", "eyebrow", "comb", "mouth",
    "figure.run", "figure.run.treadmill", "figure.mind.and.body", "figure.gymnastics", "figure.flexibility",
    "figure.yoga", "figure.strengthtraining.traditional", "dumbbell", "figure.barre", "figure.dance",
    "figure.skiing.crosscountry", "figure.skiing.downhill", "figure.boxing", "figure.kickboxing",
    "figure.ice.hockey", "figure.ice.skating", "figure.open.water.swim", "figure.outdoor.cycle",
    "soccerball", "basketball", "american.football", "tennis.racket", "hockey.puck", "snowboard", "skis", "surfboard",
    "trophy", "medal", "cross", "pills", "heart.text.square",
    "airplane", "car", "convertible.side", "sailboat", "motorcycle", "figure.hiking",
    "location.north", "signpost.right.and.left", "map", "suitcase.rolling", "tent", "building.2", "building.columns",
    "mountain.2", "sun.max", "sun.horizon", "sun.haze", "moon", "zzz", "sparkle", "sparkles", "star.fill", "snowflake",
    "aqi.medium", "rainbow", "water.waves", "drop", "flame", "bolt", "umbrella", "apple.meditate", "leaf",
    "dog", "cat", "bird", "fish", "pawprint", "frying.pan", "popcorn", "cup.and.saucer",
    "takeoutbag.and.cup.and.straw", "wineglass", "carrot", "fork.knife", "birthday.cake", "party.popper", "balloon",
    "laser.burst", "fireworks", "giftcard", "gift", "cart", "creditcard", "wallet.bifold", "house", "suitcase",
    "key.2.on.ring", "banknote", "bitcoinsign", "dollarsign", "eurosign", "rublesign", "yensign", "text.document",
    "custom.book", "custom.book.closed", "custom.books.vertical", "graduationcap", "magazine", "pencil.and.ruler",
    "backpack", "list.clipboard", "bookmark", "photo.artframe", "swift", "lightbulb.max", "brain.head.profile",
    "music.note", "music.quarternote.3", "music.microphone", "pianokeys", "paintbrush.pointed", "paintpalette",
    "film", "movieclapper", "camera", "inset.filled.leadinghalf.toptrailing.bottomtrailing.rectangle",
    "apple.intelligence", "display", "macbook", "iphone.gen1", "applewatch", "vision.pro", "airpods.max", "earbuds",
    "gamecontroller", "paperplane", "calendar", "clock", "list.bullet", "number", "flag", "square", "circlebadge",
    "rhombus", "circle.grid.2x2", "circle.hexagonpath", "circle.hexagongrid"
]

struct AppConstants {
    enum Colors {
        static let palette: [String] = [
            "#FF2D55", "#FF9500", "#FFCC00", "#00C7BE",
            "#32ADE6", "#AF52DE", "#8E8E93"
        ]
    }
    
    enum Chart {
        static let maxBarHeight: CGFloat = 120
        static let labelSpaceAboveBar: CGFloat = 25
        static let periodLabelAreaHeight: CGFloat = 20
    }
}

// MARK: - Extension Color
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgb)
        
        self.init(
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0
        )
    }
    
    static let placeholderColor = Color(UIColor.placeholderText)
    
    func toHex() -> String? {
        let uic = UIColor(self)
        guard let components = uic.cgColor.components, components.count >= 3 else {
            return nil
        }
        let r = Int(components[0] * 255.0)
        let g = Int(components[1] * 255.0)
        let b = Int(components[2] * 255.0)
        
        return String(format: "#%02x%02x%02x", r, g, b)
    }
}

// Infrastructure / UI feedback — тактильные отклики и звуки. Синглтон для удобства; не смешивать с доменной логикой данных.
// Долгосрочно можно пробросить протокол через `AppDependencies` для тестов (этап 5 рефакторинга).

class HapticSoundManager {
    static let shared = HapticSoundManager()
    private var audioPlayer: AVAudioPlayer?
    
    private init() {}
    
    func playHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    func playNotificationHaptic(type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
    
    func playSound(soundName: String, fileType: String) {
        guard let path = Bundle.main.path(forResource: soundName, ofType: fileType) else {
            print("Sound file not found: \(soundName).\(fileType)")
            return
        }
        let url = URL(fileURLWithPath: path)
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } catch {
            print("Error playing sound: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Combined Effects
    
    func completionSuccess() {
        playNotificationHaptic(type: .success)
        playSound(soundName: "sound_complete", fileType: "wav") // Пример имени файла
    }
    
    func actionUndone() {
        playHaptic(style: .light)
        playSound(soundName: "sound_undo", fileType: "wav") // Пример имени файла
    }
    
    func itemSkipped() {
        playHaptic(style: .medium)
        playSound(soundName: "sound_skip", fileType: "aiff") // Пример имени файла
    }
    
    func itemDeleted() {
        playNotificationHaptic(type: .warning)
        playSound(soundName: "sound_delete", fileType: "wav") // Пример имени файла
    }
    
    func selectionChanged() {
        playHaptic(style: .light)
    }
    
    func openPage() {
        playHaptic(style: .soft)
    }
}

// MARK: - Repeating Rule
struct RepeatingRule: Codable, Equatable {
    var startDate: Date
    var weeklyFrequency: [Int]
    var monthlySpecificDays: [Int]
}

// MARK: - Status Enum (shared for Tasks and Goals)
enum Status: String, Codable, CaseIterable, Comparable {
    case pending, inProgress, skipped, missed, completed
    
    static func < (lhs: Status, rhs: Status) -> Bool {
        switch (lhs, rhs) {
        case (.pending, .inProgress), (.pending, .skipped), (.pending, .missed), (.pending, .completed),
            (.inProgress, .skipped), (.inProgress, .missed), (.inProgress, .completed),
            (.skipped, .missed), (.skipped, .completed),
            (.missed, .completed): return true
        default: return false
        }
    }
    
    var color: Color {
        switch self {
        case .pending: return .gray
        case .inProgress: return .orange
        case .skipped: return .yellow
        case .missed: return .red
        case .completed: return .green
        }
    }
}
