import SwiftUI //
import SwiftData

// Presentation · Goals — карточка одной цели в списке «Все цели».
// Данные: `@Query`, `ModelContext`. Фильтрация/сортировка списка — на родителе: `GoalsViewModel` → `FilterGoalsUseCase` (не в этом файле).
// Паттерны: MVVM на экране списка; здесь — отображение и локальные жесты. События статуса — через модель/`AppEvent` (см. `Notifications.swift`).
// Обзор слоёв: `Core/ArchitectureStagesAndMap.swift`.

// MARK: - GOAL CARD VIEW
struct GoalCardView: View {
    let goal: Goal
    let goalDesign: AllGoalsViewDesign
    /// Пока `nil` — стиль заголовка из `goal.status`; иначе переопределение (анимация свайпа «выполнено»).
    let visualTitleCompleted: Bool?
    let onEdit: (() -> Void)?
    
    @Query private var spheres: [Sphere]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    private let hapticManager = HapticSoundManager.shared
    @State private var showAdditionalInfo: Bool = false
    @State private var outerPulse = false
    @State private var animationTask: Task<Void, Never>?
    
    init(goal: Goal, goalDesign: AllGoalsViewDesign, visualTitleCompleted: Bool? = nil, onEdit: (() -> Void)? = nil) {
        self.goal = goal
        self.goalDesign = goalDesign
        self.visualTitleCompleted = visualTitleCompleted
        self.onEdit = onEdit
    }
    
    private var color: Color {
        Color(hex: goal.colorHex ?? AppConstants.Colors.palette.first!)
    }
    
    /// Цвет обводки/акцента карточки — для иконок в информационных чипах расширенного вида.
    private var cardAccentColor: Color {
        (goal.colorHex ?? sphere?.colorHex).map { Color(hex: $0) } ?? color
    }
    
    private var sphere: Sphere? {
        if let sphereID = goal.sphereID {
            return spheres.first { $0.id == sphereID }
        }
        return nil
    }
    
    private var isCompleted: Bool {
        goal.status == .completed || goal.status == .missed || goal.status == .archived
    }
    
    private var titleLooksCompleted: Bool {
        if let v = visualTitleCompleted { return v }
        return isCompleted
    }
    
    private var isDueDateOverdue: Bool {
        guard let dueDate = goal.dueDate else { return false }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dueDay = calendar.startOfDay(for: dueDate)
        return dueDay < today && !titleLooksCompleted
    }
    
    private func overdueAbsoluteDateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }
    
    private var overduePaleRed: Color {
        Color(red: 1.0, green: 0.35, blue: 0.35)
    }

    /// Мини-чипы под заголовком — как `memoDetails` у Memo: размер `caption2`, отступы 6×2, фон по стилю карточки.
    private var goalDetailChipBackground: Color {
        if titleLooksCompleted { return Color(UIColor.systemGray5) }
        if goalDesign == .rainbow, colorScheme == .dark { return Color.white.opacity(0.14) }
        if goalDesign == .rainbow, colorScheme == .light { return Color.white.opacity(0.22) }
        return cardAccentColor.opacity(0.2)
    }

    private var goalDetailChipIconColor: Color {
        if titleLooksCompleted { return Color.secondary }
        if goalDesign == .rainbow, colorScheme == .dark { return Color.white.opacity(0.9) }
        if goalDesign == .rainbow, colorScheme == .light { return Color.white.opacity(0.95) }
        return cardAccentColor
    }

    private var goalDetailChipTextColor: Color {
        if titleLooksCompleted { return Color.secondary }
        if goalDesign == .rainbow, colorScheme == .dark { return Color.white.opacity(0.9) }
        if goalDesign == .rainbow, colorScheme == .light { return Color.white.opacity(0.95) }
        return cardAccentColor
    }
    
    /// Rainbow: как у `TaskCardView.rainbowDesign` — выполненная карточка серая, активная — цвет акцента.
    private var rainbowCardFillColor: Color {
        if titleLooksCompleted {
            return Color(UIColor.systemGray4)
        }
        return (goal.colorHex ?? sphere?.colorHex).map { Color(hex: $0) } ?? Color.accentColor
    }
    
    private var rainbowCardStrokeColor: Color {
        if titleLooksCompleted {
            return Color.gray.opacity(0.35)
        }
        let base = (goal.colorHex ?? sphere?.colorHex).map { Color(hex: $0) } ?? Color.accentColor
        return base.opacity(0.35)
    }
    
    var body: some View {
        Group {
            if showAdditionalInfo {
                expandedLayout
            } else {
                collapsedLayout
            }
        }
        .contentTransition(.opacity)
        .frame(minHeight: 72, alignment: .center)
        .mainListCardChrome(
            fill: goalDesign == .rainbow ? rainbowCardFillColor : Color(UIColor.systemBackground),
            stroke: goalDesign == .rainbow ? rainbowCardStrokeColor : Color(UIColor.systemGray5)
        )
        .scaleEffect(1.0)
        .onTapGesture {
            hapticManager.selectionChanged()
            withAnimation(CardExpansionAnimation.spring) {
                showAdditionalInfo.toggle()
            }
        }
    }
    
    @ViewBuilder
    private var collapsedLayout: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack {
                Spacer(minLength: 0)
                goalIconView()
                Spacer(minLength: 0)
            }
            .frame(width: 60, alignment: .leading)
            Text(goal.title)
                .font(.headline)
                .foregroundColor(goalDesign == .rainbow ? (titleLooksCompleted ? .gray.opacity(0.7) : .white) : (titleLooksCompleted ? Color.gray.opacity(0.5) : Color.primary.opacity(0.8)))
                .strikethrough(titleLooksCompleted, color: titleLooksCompleted ? .gray : nil)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: titleLooksCompleted)
            Spacer()
        }
        .padding(.leading, 16)
        .padding(.trailing, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 50)
    }
    
    @ViewBuilder
    private var expandedLayout: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack {
                Spacer(minLength: 0)
                goalIconView(expanded: true)
                Spacer(minLength: 0)
            }
            .frame(width: 120)
            
            VStack(alignment: .leading, spacing: 10) {
                Spacer(minLength: 0)
                Text(goal.title)
                    .font(.headline)
                    .foregroundColor(goalDesign == .rainbow ? (titleLooksCompleted ? .gray.opacity(0.7) : .white) : (titleLooksCompleted ? Color.gray.opacity(0.5) : Color.primary.opacity(0.8)))
                    .strikethrough(titleLooksCompleted, color: titleLooksCompleted ? .gray : nil)
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: titleLooksCompleted)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // 1. Due date
                        if let dueDate = goal.dueDate {
                            let isOverdue = isDueDateOverdue
                            let textColor = isOverdue ? overduePaleRed : goalDetailChipTextColor
                            let calendarIconColor = isOverdue ? overduePaleRed : goalDetailChipIconColor
                            ListDetailChip(background: goalDetailChipBackground) {
                                HStack(spacing: 4) {
                                    Image(systemName: "calendar")
                                        .font(.caption2)
                                        .foregroundColor(calendarIconColor)
                                    Text(isOverdue ? overdueAbsoluteDateString(for: dueDate) : relativeDateString(for: dueDate))
                                        .font(.caption2)
                                        .foregroundColor(textColor)
                                }
                            }
                        }
                        // 4. Reward (всегда после Due Date)
                        if let reward = goal.reward, !reward.isEmpty {
                            ListDetailChip(background: goalDetailChipBackground) {
                                HStack(spacing: 4) {
                                    Image(systemName: "trophy")
                                        .font(.caption2)
                                        .foregroundColor(goalDetailChipIconColor)
                                    Text(reward)
                                        .font(.caption2)
                                        .foregroundColor(goalDetailChipTextColor)
                                }
                            }
                        }
                        // 5. Area + Impact (иконка сферы и проценты в одном поле, без названия сферы)
                        if let sphere = sphere {
                            ListDetailChip(background: goalDetailChipBackground) {
                                HStack(spacing: 4) {
                                    Image(systemName: sphere.iconName)
                                        .font(.caption2)
                                        .foregroundColor(goalDetailChipIconColor)
                                    if goal.positiveImpact > 0 || goal.negativeImpact > 0 {
                                        Text(impactDisplayString(positive: goal.positiveImpact, negative: goal.negativeImpact))
                                            .font(.caption2)
                                            .foregroundColor(goalDetailChipTextColor)
                                    }
                                }
                            }
                        } else if goal.positiveImpact > 0 || goal.negativeImpact > 0 {
                            ListDetailChip(background: goalDetailChipBackground) {
                                Text(impactDisplayString(positive: goal.positiveImpact, negative: goal.negativeImpact))
                                    .font(.caption2)
                                    .foregroundColor(goalDetailChipTextColor)
                            }
                        }
                        // Tags (after area)
                        if !goal.tags.isEmpty {
                            ForEach(goal.tags) { tag in
                                ListDetailChip(background: goalDetailChipBackground) {
                                    HStack(spacing: 0) {
                                        Text("#")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .foregroundColor(goalDetailChipIconColor)
                                        Text(tag.name)
                                            .font(.caption2)
                                            .foregroundColor(goalDetailChipTextColor)
                                    }
                                }
                            }
                        }
                        // 6. Important (Vision spotlight)
                        if goal.isFlagged {
                            ListDetailChip(background: goalDetailChipBackground) {
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .font(.caption2)
                                        .foregroundColor(goalDetailChipIconColor)
                                    Text("Important")
                                        .font(.caption2)
                                        .foregroundColor(goalDetailChipTextColor)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                
                if let info = goal.descript, !info.isEmpty {
                    Text(info)
                        .font(.caption2)
                        .foregroundColor(goalDesign == .rainbow ? Color.white.opacity(0.9) : .secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
            .padding(.trailing, 16)
        }
        .padding(.leading, 16)
        .padding(.vertical, 10)
    }
    
    @ViewBuilder
    private func goalIconView(expanded: Bool = false) -> some View {
        let sizeScale: CGFloat = expanded ? 2.0 : 1.0
        let outerSize: CGFloat = 48 * sizeScale
        let innerSize: CGFloat = 40 * sizeScale
        let iconFontSize: CGFloat = 20 * sizeScale
        let baseAccent: Color = (goal.colorHex ?? sphere?.colorHex).map { Color(hex: $0) } ?? color
        let isRainbow = goalDesign == .rainbow
        /// На цветной Rainbow-карточке — белые кольца/глиф; выполненная карточка — серый «хром», только глиф цвета цели (как Habits).
        let useRainbowBrightStyle = isRainbow && !titleLooksCompleted

        ZStack {
            let ringStrokeOpacity: CGFloat = outerPulseScale > 1.0 ? 0.6 : 0.3
            let ringStrokeColor: Color = {
                if titleLooksCompleted { return Color.gray.opacity(ringStrokeOpacity) }
                if useRainbowBrightStyle { return Color.white.opacity(ringStrokeOpacity) }
                return baseAccent.opacity(ringStrokeOpacity)
            }()

            Circle()
                .stroke(ringStrokeColor, lineWidth: 3)
                .frame(width: outerSize, height: outerSize)
                .scaleEffect(outerPulseScale)
            
            if let imageData = goal.imageData, let uiImage = UIImage(data: imageData) {
                let photoRing: Color = {
                    if titleLooksCompleted { return Color.gray.opacity(0.35) }
                    if !isRainbow { return Color(UIColor.systemGray5) }
                    if useRainbowBrightStyle { return Color.white.opacity(0.35) }
                    return baseAccent.opacity(0.35)
                }()
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: innerSize, height: innerSize)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(photoRing, lineWidth: 1))
            } else if let customIcon = goal.iconName {
                let tint = Color(hex: goal.colorHex ?? sphere?.colorHex ?? AppConstants.Colors.palette.first ?? "#3498db")
                let chrome: (innerFill: Color, glyph: Color, innerStroke: Color) = {
                    if titleLooksCompleted {
                        return (Color.gray.opacity(0.18), tint, Color.gray.opacity(0.35))
                    }
                    if useRainbowBrightStyle {
                        return (Color.white.opacity(0.2), Color.white, Color.white.opacity(0.35))
                    }
                    return (tint.opacity(0.18), tint, tint.opacity(0.3))
                }()
                ZStack {
                    Circle().fill(chrome.innerFill)
                    Image(systemName: customIcon)
                        .font(.system(size: iconFontSize, weight: .semibold))
                        .foregroundColor(chrome.glyph)
                }
                .frame(width: innerSize, height: innerSize)
                .overlay(Circle().stroke(chrome.innerStroke, lineWidth: 1))
            } else if let sphere = sphere {
                let tint = Color(hex: goal.colorHex ?? sphere.colorHex)
                let sphereChrome: (innerFill: Color, glyph: Color, innerStroke: Color) = {
                    if titleLooksCompleted {
                        return (Color.gray.opacity(0.18), tint, Color.gray.opacity(0.35))
                    }
                    if useRainbowBrightStyle {
                        return (Color.white.opacity(0.2), Color.white, Color.white.opacity(0.35))
                    }
                    return (tint.opacity(0.18), tint, tint.opacity(0.3))
                }()
                ZStack {
                    Circle()
                        .fill(sphereChrome.innerFill)
                    Image(systemName: sphere.iconName)
                        .font(.system(size: iconFontSize, weight: .semibold))
                        .foregroundColor(sphereChrome.glyph)
                }
                .frame(width: innerSize, height: innerSize)
                .overlay(Circle().stroke(sphereChrome.innerStroke, lineWidth: 1))
            } else {
                let tint = Color(hex: goal.colorHex ?? AppConstants.Colors.palette.first ?? "#3498db")
                let trophyChrome: (innerFill: Color, glyph: Color, innerStroke: Color) = {
                    if titleLooksCompleted {
                        return (Color.gray.opacity(0.18), tint, Color.gray.opacity(0.35))
                    }
                    if useRainbowBrightStyle {
                        return (Color.white.opacity(0.2), Color.white, Color.white.opacity(0.35))
                    }
                    return (tint.opacity(0.12), tint, tint.opacity(0.3))
                }()
                ZStack {
                    Circle().fill(trophyChrome.innerFill)
                    Image(systemName: "trophy.fill")
                        .font(.system(size: iconFontSize, weight: .semibold))
                        .foregroundColor(trophyChrome.glyph)
                }
                .frame(width: innerSize, height: innerSize)
                .overlay(Circle().stroke(trophyChrome.innerStroke, lineWidth: 1))
            }
        }
        .onAppear {
            updateOuterPulse()
        }
        .onDisappear {
            animationTask?.cancel()
            animationTask = nil
        }
    }
    
    private func duplicateGoal() {
        let all = (try? modelContext.fetch(FetchDescriptor<Goal>())) ?? []
        let nextVision = goal.isFlagged
            ? ((all.filter(\.isFlagged).map(\.visionGridOrder).max() ?? -1) + 1)
            : 0
        let copy = Goal(
            title: goal.title,
            description: goal.descript,
            imageData: goal.imageData,
            iconName: goal.iconName,
            colorHex: goal.colorHex,
            dueDate: goal.dueDate,
            reward: goal.reward,
            status: goal.status,
            orderIndex: goal.orderIndex + 1,
            subtasks: goal.subtasks.map { SubTask(title: $0.title, isCompleted: $0.isCompleted, orderIndex: $0.orderIndex, estimatedDuration: $0.estimatedDuration, notes: $0.notes) },
            counters: goal.counters.map { Counter(name: $0.name, current: $0.current, target: $0.target) },
            sphereID: goal.sphereID,
            positiveImpact: goal.positiveImpact,
            negativeImpact: goal.negativeImpact,
            isFlagged: goal.isFlagged,
            visionGridOrder: nextVision
        )
        copy.tags = goal.tags
        modelContext.insert(copy)
        try? modelContext.save()
    }
    
    // MARK: - Helpers (Chips & Dates)
    private func chipView(icon: String, text: String) -> some View {
        ListDetailChip(background: goalDetailChipBackground) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundColor(goalDetailChipIconColor)
                Text(text)
                    .font(.caption2)
                    .foregroundColor(goalDetailChipTextColor)
            }
        }
    }
    
    private func impactDisplayString(positive: Double, negative: Double) -> String {
        let posDisplay = positive
        let negDisplay = negative
        var parts: [String] = []
        if posDisplay > 0 { parts.append("+\(String(format: "%.0f", posDisplay))%") }
        if negDisplay > 0 { parts.append("-\(String(format: "%.0f", negDisplay))%") }
        return parts.joined(separator: " ")
    }
    
    private func relativeDateString(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private var outerPulseScale: CGFloat {
        return outerPulse ? 1.08 : 0.96
    }
    
    private func updateOuterPulse() {
        // Отменяем предыдущую анимацию, если она есть
        animationTask?.cancel()
        
        outerPulse = false
        
        // Анимация 1 пульсация
        animationTask = Task {
            for _ in 0..<1 {
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 1.0)) {
                    outerPulse = true
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 секунда
                
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 1.0)) {
                    outerPulse = false
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 секунда
            }
            // После 1 пульсации остаемся в широком положении
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 1.0)) {
                outerPulse = true
            }
        }
    }
    
}
