import SwiftUI
import SwiftData
import AVFoundation

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
let availableHabitIcons = [
    // Основные и популярные
    "star.fill", "heart.fill", "leaf.fill", "flame.fill", "bolt.fill", "drop.fill", "sun.max.fill", "moon.fill",
    "cloud.fill", "snowflake", "umbrella.fill", "sparkles", "star.circle.fill", "heart.circle.fill",
    
    // Образование и обучение
    "book.fill", "pencil", "graduationcap.fill", "book.closed.fill", "textbook", "note.text", "doc.text.fill",
    "pencil.and.outline", "highlighter", "pencil.tip", "bookmark.fill",
    
    // Работа и продуктивность
    "briefcase.fill", "laptopcomputer", "desktopcomputer", "iphone", "ipad", "apple.logo", "keyboard.fill",
    "printer.fill", "paperclip", "folder.fill", "doc.fill", "doc.on.doc.fill", "chart.bar.fill",
    "chart.line.uptrend.xyaxis", "checkmark.circle.fill", "list.bullet", "checklist", "calendar",
    "clock.fill", "alarm.fill", "timer", "stopwatch.fill", "hourglass", "bell.fill", "bell.badge.fill",
    "target", "flag.fill", "flag.checkered", "trophy.fill", "medal.fill", "crown.fill", "award.fill",
    
    // Спорт и фитнес
    "dumbbell.fill", "figure.run", "figure.walk", "figure.strengthtraining.traditional", "figure.yoga",
    "figure.flexibility", "figure.core.training", "figure.dance", "figure.climbing", "sportscourt.fill",
    "bicycle", "figure.outdoor.cycle", "figure.skiing.downhill", "figure.snowboarding", "soccerball",
    "basketball.fill", "football.fill", "baseball.fill", "tennis.racket", "figure.swimming",
    
    // Здоровье и медицина
    "cross.fill", "cross.case.fill", "heart.circle.fill", "heart.text.square.fill", "waveform.path.ecg",
    "lungs.fill", "pills.fill", "cross.vial.fill", "bandage.fill", "staroflife.fill", "heart.text.square",
    "figure.mind.and.body", "bed.double.fill", "moon.zzz.fill", "zzz", "eye.fill", "ear.fill",
    
    // Еда и напитки
    "fork.knife", "cup.and.saucer.fill", "wineglass.fill", "takeoutbag.and.cup.and.straw.fill",
    "birthday.cake.fill", "carrot.fill", "leaf.fill", "apple.logo", "fish.fill",
    
    // Транспорт
    "car.fill", "airplane", "tram.fill", "bus.fill", "tram.fill.tunnel", "scooter", "figure.walk.motion",
    "fuelpump.fill", "car.2.fill", "bicycle.circle.fill",
    
    // Развлечения и хобби
    "gamecontroller.fill", "music.note", "music.mic", "headphones", "mic.fill", "camera.fill",
    "photo.fill", "film.fill", "tv.fill", "play.rectangle.fill", "paintbrush.fill", "paintpalette.fill",
    "theatermasks.fill", "guitars.fill", "pianokeys", "figure.socialdance", "figure.archery",
    
    // Социальное и общение
    "face.smiling", "hand.thumbsup.fill", "hand.raised.fill", "bubble.left.and.bubble.right.fill",
    "message.fill", "envelope.fill", "phone.fill", "video.fill", "person.2.fill", "person.3.fill",
    "person.crop.circle.fill", "person.2.circle.fill", "figure.2.arms.open", "hands.sparkles.fill",
    
    // Природа и окружающая среда
    "tree.fill", "leaf.fill", "sun.max.fill", "moon.stars.fill", "cloud.rain.fill", "snowflake",
    "tornado", "flame.fill", "drop.fill", "water.waves", "mountain.2.fill", "beach.umbrella.fill",
    "pawprint.fill", "bird.fill", "fish.fill", "tortoise.fill", "ladybug.fill", "ant.fill",
    
    // Финансы и покупки
    "cart.fill", "bag.fill", "creditcard.fill", "dollarsign.circle.fill", "yensign.circle.fill",
    "eurosign.circle.fill", "bitcoinsign.circle.fill", "banknote.fill", "chart.pie.fill",
    "chart.bar.xaxis", "building.columns.fill", "building.2.fill",
    
    // Дом и быт
    "house.fill", "house.lodge.fill", "building.2.fill", "key.fill", "lock.fill", "lock.open.fill",
    "lightbulb.fill", "lightbulb.2.fill", "lamp.desk.fill", "bed.double.fill", "sofa.fill",
    "washer.fill", "refrigerator.fill", "oven.fill", "microwave.fill", "airpodsmax",
    
    // Путешествия и география
    "globe", "map.fill", "location.fill", "mappin.circle.fill", "safari.fill", "binoculars.fill",
    "camera.metering.matrix", "figure.hiking", "backpack.fill", "suitcase.fill", "suitcase.rolling.fill",
    
    // Технологии и инструменты
    "wrench.and.screwdriver.fill", "hammer.fill", "screwdriver.fill", "paintbrush.pointed.fill",
    "scissors", "wrench.fill", "gearshape.fill", "gearshape.2.fill", "slider.horizontal.3",
    "dial.high.fill", "gauge.open.with.lines.needle.33percent", "cpu.fill", "memorychip.fill",
    
    // Разное
    "gift.fill", "balloon.fill", "party.popper.fill", "confetti", "fireworks", "candle.fill",
    "tag.fill", "bookmark.fill", "flag.fill", "pin.fill", "paperplane.fill", "arrow.triangle.2.circlepath",
    "repeat", "shuffle", "arrow.clockwise", "arrow.counterclockwise", "arrow.up.arrow.down",
    "magnifyingglass", "plus.circle.fill", "minus.circle.fill", "xmark.circle.fill", "checkmark.seal.fill",
    "exclamationmark.triangle.fill", "questionmark.circle.fill", "info.circle.fill", "link.circle.fill",
    "square.and.arrow.up.fill", "square.and.arrow.down.fill", "square.and.pencil", "pencil.and.list.clipboard",
    "archivebox.fill", "trash.fill", "folder.fill", "folder.badge.plus", "doc.on.clipboard.fill",
    "note.text", "list.bullet.rectangle", "text.alignleft", "text.aligncenter", "text.alignright",
    "textformat", "textformat.size", "bold", "italic", "underline", "strikethrough",
    "paintbrush.fill", "eyedropper.full", "paintpalette.fill", "pencil.tip", "highlighter",
    "hand.draw.fill", "scribble", "pencil.and.outline", "square.and.pencil", "square.and.arrow.up.on.square.fill"
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
