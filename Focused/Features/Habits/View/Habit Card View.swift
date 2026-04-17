import SwiftUI
import SwiftData

// Presentation · Habits — карточка одной привычки на выбранную дату (в т.ч. в сегменте Vision).
// Отметки выполнения/пропуска меняют модель и могут трогать impact сферы; список на экране «Все привычки» — `FilterHabitsUseCase`.
// Оглавление: отступы → `HabitCardView` (раскладки, body, статус) → вложенные мини-вью → `IconWithProgressView`.

// MARK: Модификатор отступов (дубль padding в Segmented)
private struct HabitCardPadding: ViewModifier {
    let isInSegmented: Bool
    func body(content: Content) -> some View {
        if isInSegmented {
            content
        } else {
            content
                .padding(.vertical, 1)
                .padding(.horizontal, 10)
        }
    }
}

// MARK: Карточка одной привычки
struct HabitCardView: View {
    var habit: Habit
    let date: Date
    let design: HabitsViewDesign
    let isFutureDate: Bool
    let onDoubleTap: () -> Void
    var isInSegmented: Bool = false
    
    @Environment(\.modelContext) private var modelContext
    @Query private var spheres: [Sphere]
    @Environment(\.colorScheme) private var colorScheme
    @State private var showInfo: Bool = false
    @State private var isPressed: Bool = false
    
    /// Отложенное сохранение по ведущему свайпу (как Goals / Tasks).
    private enum HabitLeadingSwipeOverride: Equatable {
        case none
        case showAsActive
        case showAsCompletedStyle
    }
    @State private var leadingSwipeOverride: HabitLeadingSwipeOverride = .none
    
    private static let habitSwipeCompleteSaveDelay: TimeInterval = 0.65
    private static let habitSwipeUncompleteSaveDelay: TimeInterval = 1.0
    
    private func sphereColor() -> Color {
        if let sid = habit.sphereID, let sphere = spheres.first(where: { $0.id == sid }) {
            return Color(hex: sphere.colorHex)
        }
        return Color(hex: habit.colorHex)
    }
    
    private var habitCardCornerRadius: CGFloat {
        MainListCardChrome.cornerRadius
    }
    
    private var habitCardFillColor: Color {
        if habit.isArchived {
            return design == .basic ? Color(UIColor.systemGray6) : Color(UIColor.systemGray4)
        }
        if design == .basic {
            return Color(UIColor.systemBackground)
        }
        let status = habit.completionStatus(on: date)
        if status == .completedHabit || status == .missedHabit || status == .skippedHabit {
            return Color(UIColor.systemGray4)
        }
        return sphereColor()
    }
    
    private var habitCardStrokeColor: Color {
        design == .basic ? Color(UIColor.systemGray5) : Color.white.opacity(0.35)
    }

    /// Строка impact как в Goals / Tasks (`+n% -m%`).
    private func habitImpactDisplayString() -> String {
        var parts: [String] = []
        if habit.positiveImpact > 0 { parts.append("+\(String(format: "%.0f", habit.positiveImpact))%") }
        if habit.negativeImpact > 0 { parts.append("-\(String(format: "%.0f", habit.negativeImpact))%") }
        return parts.joined(separator: " ")
    }

    /// Мини-чипы под заголовком — как у Memo (`caption2`, 6×2).
    private var habitDetailChipBackground: Color {
        if habitTitleMutedStyle { return Color(UIColor.systemGray5) }
        if design == .colorful, colorScheme == .dark { return Color.white.opacity(0.14) }
        if design == .colorful, colorScheme == .light { return Color.white.opacity(0.22) }
        return sphereColor().opacity(0.2)
    }

    private var habitDetailChipIconColor: Color {
        if habitTitleMutedStyle { return Color.secondary }
        if design == .colorful, colorScheme == .dark { return Color.white.opacity(0.9) }
        if design == .colorful, colorScheme == .light { return Color.white.opacity(0.95) }
        return sphereColor()
    }

    private var habitDetailChipTextColor: Color {
        if habitTitleMutedStyle { return Color.secondary }
        if design == .colorful, colorScheme == .dark { return Color.white.opacity(0.9) }
        if design == .colorful, colorScheme == .light { return Color.white.opacity(0.95) }
        return sphereColor()
    }
    
    // MARK: Пересчёт `Sphere.satisfaction` при completed/missed/skipped
    private func adjustSphereSatisfaction(for habit: Habit, newStatus: HabitStatus, oldStatus: HabitStatus, date: Date) {
        guard let sphereID = habit.sphereID else { return }
        
        let fetchDescriptor = FetchDescriptor<Sphere>(predicate: #Predicate<Sphere> { $0.id == sphereID })
        do {
            if let sphere = try modelContext.fetch(fetchDescriptor).first {
                if oldStatus == .completedHabit {
                    sphere.satisfaction -= habit.positiveImpact
                } else if oldStatus == .missedHabit {
                    sphere.satisfaction += habit.negativeImpact
                }
                
                if newStatus == .completedHabit {
                    sphere.satisfaction += habit.positiveImpact
                } else if newStatus == .missedHabit {
                    sphere.satisfaction -= habit.negativeImpact
                }
                
                sphere.satisfaction = max(0.0, min(100.0, sphere.satisfaction))
            }
        } catch {
            print("Failed to fetch sphere: \(error.localizedDescription)")
        }
    }
    
    private var habitTitleMutedStyle: Bool {
        switch leadingSwipeOverride {
        case .showAsCompletedStyle: return true
        case .showAsActive: return false
        case .none:
            return habit.isArchived || habit.isCompletedHabit(on: date) || habit.isMissedHabit(on: date) || habit.isSkippedHabit(on: date)
        }
    }
    
    private var habitTitleStrikethroughActive: Bool {
        switch leadingSwipeOverride {
        case .showAsCompletedStyle: return true
        case .showAsActive: return false
        case .none:
            return habit.isCompletedHabit(on: date) || habit.isMissedHabit(on: date) || habit.isSkippedHabit(on: date)
        }
    }
    
    private var habitTitleStrikethroughLineColor: Color {
        switch leadingSwipeOverride {
        case .showAsCompletedStyle:
            return .green
        case .showAsActive:
            return .gray
        case .none:
            if habit.isCompletedHabit(on: date) { return .green }
            if habit.isMissedHabit(on: date) { return .red }
            if habit.isSkippedHabit(on: date) { return .gray }
            return .gray
        }
    }
    
    private var leftTitleColorBasic: Color {
        habitTitleMutedStyle ? Color.gray.opacity(0.5) : Color.primary.opacity(0.8)
    }
    
    private var leftTitleColorRainbow: Color {
        habitTitleMutedStyle ? .gray.opacity(0.7) : .white
    }
    
    /// Полное кольцо (выполнено / пропущено / пропущено по свайпу «как выполнено»).
    private var habitRingShowsFullProgress: Bool {
        switch leadingSwipeOverride {
        case .showAsCompletedStyle: return true
        case .showAsActive: return false
        case .none:
            return habit.isCompletedHabit(on: date) || habit.isMissedHabit(on: date) || habit.isSkippedHabit(on: date)
        }
    }
    
    /// Серые кольца и иконка только для missed/skipped (выполненная привычка — цветная, как у Tasks).
    private var habitIconUseGrayMutedStyle: Bool {
        switch leadingSwipeOverride {
        case .showAsCompletedStyle: return false
        case .showAsActive: return false
        case .none:
            return habit.isMissedHabit(on: date) || habit.isSkippedHabit(on: date)
        }
    }
    
    /// Colorful: белый на цветной карточке; на серой «выполненной» Rainbow — hex привычки, как Basic (иконка не серая).
    private var habitIconForegroundColor: Color {
        if design == .basic { return Color(hex: habit.colorHex) }
        if habitIconUseGrayMutedStyle { return .white }
        if leadingSwipeOverride == .showAsCompletedStyle { return Color(hex: habit.colorHex) }
        if habit.isCompletedHabit(on: date) { return Color(hex: habit.colorHex) }
        return .white
    }
    
    // MARK: Развёрнутая колонка — заголовок, стрик, неделя в кружках
    @ViewBuilder
    func habitExpandedLayout() -> some View {
        let streak = HabitLogicService(habit: habit).calculateStreak(upTo: date)
        HStack(alignment: .center, spacing: 12) {
            VStack {
                Spacer(minLength: 0)
                IconWithProgressView(
                    iconName: habit.iconName,
                    progress: habit.requiredRepetitions > 1 ?
                    Double(habit.currentCompletionCount(on: date)) / Double(habit.requiredRepetitions) : 0.0,
                    color: habitIconForegroundColor,
                    design: design,
                    showProgressRing: habit.requiredRepetitions > 1,
                    ringShowsFullProgress: habitRingShowsFullProgress,
                    useGrayMutedIcon: habitIconUseGrayMutedStyle
                )
                Spacer(minLength: 0)
            }
            .frame(width: 60, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 10) {
                Text(habit.title)
                        .font(.headline)
                        .foregroundColor(design == .basic ? leftTitleColorBasic : leftTitleColorRainbow)
                        .strikethrough(habitTitleStrikethroughActive, color: habitTitleStrikethroughLineColor)
                        .lineLimit(nil)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(1)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: leadingSwipeOverride)

                if habit.sphereID != nil || habit.positiveImpact > 0 || habit.negativeImpact > 0 || !habit.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            if let sphere = spheres.first(where: { $0.id == habit.sphereID }) {
                                ListDetailChip(background: habitDetailChipBackground) {
                                    HStack(spacing: 4) {
                                        Image(systemName: sphere.iconName)
                                            .font(.caption2)
                                            .foregroundColor(habitDetailChipIconColor)
                                        if habit.positiveImpact > 0 || habit.negativeImpact > 0 {
                                            Text(habitImpactDisplayString())
                                                .font(.caption2)
                                                .foregroundColor(habitDetailChipTextColor)
                                        }
                                    }
                                }
                            } else if habit.positiveImpact > 0 || habit.negativeImpact > 0 {
                                ListDetailChip(background: habitDetailChipBackground) {
                                    Text(habitImpactDisplayString())
                                        .font(.caption2)
                                        .foregroundColor(habitDetailChipTextColor)
                                }
                            }
                            ForEach(habit.tags) { tag in
                                ListDetailChip(background: habitDetailChipBackground) {
                                    HStack(spacing: 0) {
                                        Text("#")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .foregroundColor(habitDetailChipIconColor)
                                        Text(tag.name)
                                            .font(.caption2)
                                            .foregroundColor(habitDetailChipTextColor)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                if let info = habit.descript, !info.isEmpty {
                    Text(info)
                        .font(.caption2)
                        .foregroundColor(design == .colorful ? Color.white.opacity(0.9) : .secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                WeekStatusCirclesView(
                    dayStatuses: HabitLogicService(habit: habit).statusesForWeek(endingOn: date),
                    selectedDate: date
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
            .padding(.trailing, 8)

            // Trailing streak badge must participate in layout to prevent title overlap.
            if streak >= 2 {
                HabitStreakBadgeView(
                    streakCount: streak,
                    design: design,
                    badgeColor: sphereColor(),
                    isArchived: habit.isArchived
                )
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(2)
                .padding(.trailing, 4)
            }
        }
        .padding(.leading, 16)
        .padding(.vertical, 10)
        .padding(.trailing, 16)
    }
    
    // MARK: Свёрнутая одна строка — иконка с прогрессом + заголовок
    @ViewBuilder
    func habitContent() -> some View {
        let streak = HabitLogicService(habit: habit).calculateStreak(upTo: date)
        HStack(alignment: .center, spacing: 12) {
            VStack {
                Spacer(minLength: 0)
                IconWithProgressView(
                    iconName: habit.iconName,
                    progress: habit.requiredRepetitions > 1 ?
                    Double(habit.currentCompletionCount(on: date)) / Double(habit.requiredRepetitions) : 0.0,
                    color: habitIconForegroundColor,
                    design: design,
                    showProgressRing: habit.requiredRepetitions > 1,
                    ringShowsFullProgress: habitRingShowsFullProgress,
                    useGrayMutedIcon: habitIconUseGrayMutedStyle
                )
                Spacer(minLength: 0)
            }
            .frame(width: 60, alignment: .leading)

            Text(habit.title)
                .font(.headline)
                .foregroundColor(design == .basic ? leftTitleColorBasic : leftTitleColorRainbow)
                .strikethrough(habitTitleStrikethroughActive, color: habitTitleStrikethroughLineColor)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: leadingSwipeOverride)

            Spacer(minLength: 8)

            if streak >= 2 {
                HabitStreakBadgeView(
                    streakCount: streak,
                    design: design,
                    badgeColor: sphereColor(),
                    isArchived: habit.isArchived
                )
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(2)
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .center)
    }
    
    // MARK: Иконка статуса дня (галочка / крест / прогресс повторов)
    @ViewBuilder
    func statusView() -> some View {
        let status = habit.completionStatus(on: date)
        
        if status == .activeHabit {
            let streak = HabitLogicService(habit: habit).calculateStreak(upTo: date)
            if habit.requiredRepetitions == 1 {
                HabitStreakBadgeView(
                    streakCount: streak,
                    design: design,
                    badgeColor: sphereColor(),
                    isArchived: habit.isArchived
                )
            } else {
                if streak >= 2 {
                    HabitStreakBadgeView(
                        streakCount: streak,
                        design: design,
                        badgeColor: sphereColor(),
                        isArchived: habit.isArchived
                    )
                } else {
                    let currentCount = habit.currentCompletionCount(on: date)
                    let requiredCount = habit.requiredRepetitions
                    let progress = Double(currentCount) / Double(requiredCount)
                    ProgressCircleView(progress: progress, currentCount: currentCount, requiredCount: requiredCount, color: Color(hex: habit.colorHex))
                }
            }
        } else if status == .completedHabit {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.title2)
                .transition(.scale.combined(with: .opacity))
        } else if status == .missedHabit {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
                .font(.title2)
                .transition(.scale.combined(with: .opacity))
        } else if status == .skippedHabit {
            Image(systemName: "minus.circle.fill")
                .foregroundColor(.gray)
                .font(.title2)
                .transition(.scale.combined(with: .opacity))
        } else if status == .partialHabit {
            let currentCount = habit.currentCompletionCount(on: date)
            let requiredCount = habit.requiredRepetitions
            let progress = Double(currentCount) / Double(requiredCount)
            ProgressCircleView(progress: progress, currentCount: currentCount, requiredCount: requiredCount, color: Color(hex: habit.colorHex))
        }
    }
    
    private func applySkippedOrMissedUndo(oldStatus: HabitStatus) {
        guard leadingSwipeOverride != .none else { return }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            habit.updateStatus(to: .activeHabit, on: date)
            adjustSphereSatisfaction(for: habit, newStatus: .activeHabit, oldStatus: oldStatus, date: date)
            HapticSoundManager.shared.actionUndone()
            try? modelContext.save()
            NotificationCenter.default.postAppEvent(.habitStatusDidChange)
        }
        leadingSwipeOverride = .none
    }
    
    private func applyIncrementDelayed(oldStatus: HabitStatus) {
        guard leadingSwipeOverride != .none else { return }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            habit.incrementCompletion(on: date)
            if habit.isCompletedHabit(on: date) && oldStatus != .completedHabit {
                adjustSphereSatisfaction(for: habit, newStatus: .completedHabit, oldStatus: oldStatus, date: date)
                HapticSoundManager.shared.completionSuccess()
            } else if !habit.isCompletedHabit(on: date) && oldStatus == .completedHabit {
                adjustSphereSatisfaction(for: habit, newStatus: .activeHabit, oldStatus: oldStatus, date: date)
                HapticSoundManager.shared.actionUndone()
            }
            try? modelContext.save()
            NotificationCenter.default.postAppEvent(.habitStatusDidChange)
        }
        leadingSwipeOverride = .none
    }
    
    private func applyIncrementImmediate(oldStatus: HabitStatus) {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            habit.incrementCompletion(on: date)
            if habit.isCompletedHabit(on: date) && oldStatus != .completedHabit {
                adjustSphereSatisfaction(for: habit, newStatus: .completedHabit, oldStatus: oldStatus, date: date)
                HapticSoundManager.shared.completionSuccess()
            } else if !habit.isCompletedHabit(on: date) && oldStatus == .completedHabit {
                adjustSphereSatisfaction(for: habit, newStatus: .activeHabit, oldStatus: oldStatus, date: date)
                HapticSoundManager.shared.actionUndone()
            }
            try? modelContext.save()
            NotificationCenter.default.postAppEvent(.habitStatusDidChange)
        }
    }
    
    private func applyDecrementDelayed(oldStatus: HabitStatus) {
        guard leadingSwipeOverride != .none else { return }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            habit.decrementCompletion(on: date)
            if habit.isCompletedHabit(on: date) && oldStatus != .completedHabit {
                adjustSphereSatisfaction(for: habit, newStatus: .completedHabit, oldStatus: oldStatus, date: date)
                HapticSoundManager.shared.completionSuccess()
            } else if !habit.isCompletedHabit(on: date) && oldStatus == .completedHabit {
                adjustSphereSatisfaction(for: habit, newStatus: .activeHabit, oldStatus: oldStatus, date: date)
                HapticSoundManager.shared.actionUndone()
            }
            try? modelContext.save()
            NotificationCenter.default.postAppEvent(.habitStatusDidChange)
        }
        leadingSwipeOverride = .none
    }
    
    // MARK: Body — фон, свайпы, одиночный тап, переключение info
    var body: some View {
        Group {
            if showInfo {
                habitExpandedLayout()
            } else {
                habitContent()
            }
        }
            .contentTransition(.opacity)
            .frame(minHeight: 72, alignment: .center)
            .mainListCardChrome(
                fill: habitCardFillColor,
                stroke: habitCardStrokeColor,
                cornerRadius: habitCardCornerRadius
            )
            // Removed shadow for unified flat design across all cards
            // .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
            .modifier(HabitCardPadding(isInSegmented: isInSegmented))
            .scaleEffect(isPressed ? 1.02 : 1.0)
            .onTapGesture {
                HapticSoundManager.shared.selectionChanged()
                withAnimation(CardExpansionAnimation.spring) {
                    showInfo.toggle()
                }
            }
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                if !isFutureDate {
                    let status = habit.completionStatus(on: date)
                    
                    Button {
                        guard leadingSwipeOverride == .none else { return }
                        let oldStatus = habit.completionStatus(on: date)
                        HapticSoundManager.shared.selectionChanged()
                        if oldStatus == .skippedHabit || oldStatus == .missedHabit {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                                leadingSwipeOverride = .showAsActive
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + Self.habitSwipeUncompleteSaveDelay) {
                                    applySkippedOrMissedUndo(oldStatus: oldStatus)
                            }
                        } else if habit.currentCompletionCount(on: date) < habit.requiredRepetitions {
                            let willBecomeCompleted = (habit.currentCompletionCount(on: date) + 1) >= habit.requiredRepetitions
                            if willBecomeCompleted {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                    leadingSwipeOverride = .showAsCompletedStyle
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + Self.habitSwipeCompleteSaveDelay) {
                                        applyIncrementDelayed(oldStatus: oldStatus)
                                }
                            } else {
                                    applyIncrementImmediate(oldStatus: oldStatus)
                            }
                        } else {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                                leadingSwipeOverride = .showAsActive
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + Self.habitSwipeUncompleteSaveDelay) {
                                    applyDecrementDelayed(oldStatus: oldStatus)
                            }
                        }
                    } label: {
                        let isCompleted = habit.isCompletedHabit(on: date)
                        Image(systemName: isCompleted ? "arrow.uturn.backward" : ((status == .skippedHabit || status == .missedHabit) ? "arrow.uturn.backward" : "checkmark"))
                    }
                    .tint(habit.isCompletedHabit(on: date) || status == .skippedHabit || status == .missedHabit ? .orange : .green)
                }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button {
                    HapticSoundManager.shared.selectionChanged()
                    onDoubleTap()
                } label: {
                    Image(systemName: "pencil")
                }
                .tint(.yellow)
                if !isFutureDate {
                    if habit.completionStatus(on: date) != .activeHabit {
                        Button {
                            HapticSoundManager.shared.playHaptic(style: .light)
                            let oldStatus = habit.completionStatus(on: date)
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                habit.updateStatus(to: .activeHabit, on: date)
                                adjustSphereSatisfaction(for: habit, newStatus: .activeHabit, oldStatus: oldStatus, date: date)
                                HapticSoundManager.shared.actionUndone()
                                try? modelContext.save()
                                NotificationCenter.default.postAppEvent(.habitStatusDidChange)
                            }
                        } label: {
                            Image(systemName: "arrow.uturn.backward")
                        }
                        .tint(.orange)
                    } else {
                        Button {
                            HapticSoundManager.shared.playHaptic(style: .light)
                            let oldStatus = habit.completionStatus(on: date)
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                habit.updateStatus(to: .skippedHabit, on: date)
                                adjustSphereSatisfaction(for: habit, newStatus: .skippedHabit, oldStatus: oldStatus, date: date)
                                HapticSoundManager.shared.itemSkipped()
                                try? modelContext.save()
                                NotificationCenter.default.postAppEvent(.habitStatusDidChange)
                            }
                        } label: {
                            Image(systemName: "minus")
                        }
                        .tint(.gray)
                        
                        Button {
                            HapticSoundManager.shared.playHaptic(style: .light)
                            let oldStatus = habit.completionStatus(on: date)
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                habit.updateStatus(to: .missedHabit, on: date)
                                adjustSphereSatisfaction(for: habit, newStatus: .missedHabit, oldStatus: oldStatus, date: date)
                                HapticSoundManager.shared.itemDeleted()
                                try? modelContext.save()
                                NotificationCenter.default.postAppEvent(.habitStatusDidChange)
                            }
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .tint(.red)
                    }
                }
            }
    }
    
    // MARK: Streak badge (matches Memo type `.streak`)
    struct HabitStreakBadgeView: View {
        let streakCount: Int
        let design: HabitsViewDesign
        let badgeColor: Color
        let isArchived: Bool
        
        private var textColor: Color {
            if design == .colorful { return .white.opacity(0.9) }
            return isArchived ? .secondary : badgeColor
        }
        
        private var fillColor: Color {
            if design == .colorful { return Color.white.opacity(0.2) }
            return isArchived ? Color(UIColor.systemGray5) : badgeColor.opacity(0.2)
        }
        
        var body: some View {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(textColor)
                Text("\(streakCount)")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(textColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(fillColor)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .floatingBadgeStyle()
            .transition(.scale.combined(with: .opacity))
        }
    }
    
    // MARK: Кружки статусов по дням недели
    struct WeekStatusCirclesView: View {
        let dayStatuses: [(Date, HabitStatus)]
        let selectedDate: Date
        
        var body: some View {
            HStack(spacing: 4) {
                ForEach(dayStatuses.sorted(by: { $0.0 < $1.0 }), id: \.0) { (date, status) in
                    Circle()
                        .fill(fillColor(for: status, date: date))
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(.gray, lineWidth: 0.3)
                        )
                }
            }
        }
        
        private func fillColor(for status: HabitStatus, date: Date) -> Color {
            let calendar = Calendar.current
            let normalizedDate = calendar.startOfDay(for: date)
            let normalizedSelectedDate = calendar.startOfDay(for: selectedDate)
            
            switch status {
            case .completedHabit:
                return .green.opacity(0.8)
            case .missedHabit:
                return .red.opacity(0.8)
            case .skippedHabit:
                return .gray.opacity(0.8)
            case .activeHabit, .partialHabit:
                if calendar.isDate(normalizedDate, inSameDayAs: normalizedSelectedDate) {
                    return Color.white.opacity(0.8)
                } else {
                    return .white.opacity(0.5)
                }
            }
        }
    }
    
    // MARK: Кольцо прогресса N/M повторов за день
    struct ProgressCircleView: View {
        let progress: Double
        let currentCount: Int
        let requiredCount: Int
        let color: Color
        
        var body: some View {
            ZStack {
                Circle()
                    .stroke(lineWidth: 4.0)
                    .opacity(0.3)
                    .foregroundColor(color)
                
                Circle()
                    .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                    .stroke(style: StrokeStyle(lineWidth: 4.0, lineCap: .round, lineJoin: .round))
                    .foregroundColor(color)
                    .rotationEffect(Angle(degrees: 270.0))
                    .animation(.easeInOut, value: progress)
                
                Text("\(currentCount)/\(requiredCount)")
                    .font(.caption2)
                    .bold()
                    .foregroundColor(color)
            }
            .frame(width: 40, height: 40)
        }
    }
}

// MARK: Левая иконка привычки + кольцо прогресса (структура как `GoalCardView.goalIconView`)
struct IconWithProgressView: View {
    let iconName: String
    let progress: Double
    let color: Color
    let design: HabitsViewDesign
    /// Кольцо прогресса (трек + дуга) — только для активных привычек с повторениями > 1.
    let showProgressRing: Bool
    /// Кольцо заполнено на 100 % (выполнено / missed / skipped или превью свайпа).
    let ringShowsFullProgress: Bool
    /// Серые кольца и глиф — только missed/skipped; выполненная привычка остаётся цветной (как чекбокс у Tasks).
    let useGrayMutedIcon: Bool
    
    @State private var outerPulse = false
    @State private var animationTask: Task<Void, Never>?
    
    private let outerSize: CGFloat = 48
    private let innerSize: CGFloat = 40
    private let iconFontSize: CGFloat = 20
    
    var body: some View {
        ZStack {
            let ringStrokeOpacity: CGFloat = outerPulseScale > 1.0 ? 0.6 : 0.3
            let outerRingColor: Color = {
                if useGrayMutedIcon { return Color.gray.opacity(ringStrokeOpacity) }
                if design == .colorful { return Color.white.opacity(ringStrokeOpacity) }
                return color.opacity(ringStrokeOpacity)
            }()
            let innerFill: Color = {
                if useGrayMutedIcon { return Color.gray.opacity(0.18) }
                if design == .colorful { return Color.white.opacity(0.2) }
                return color.opacity(0.18)
            }()
            let innerStroke: Color = {
                if useGrayMutedIcon { return Color.gray.opacity(0.35) }
                if design == .colorful { return Color.white.opacity(0.35) }
                return color.opacity(0.3)
            }()
            let glyphColor: Color = useGrayMutedIcon ? Color.gray.opacity(0.3) : color
            let ringColor = useGrayMutedIcon ? Color.gray.opacity(0.3) : color
            let ringProgress = ringShowsFullProgress ? 1.0 : progress
            
            // 1. Внешнее кольцо — как у цели (`goalIconView`: stroke 3, пульс только здесь)
            Circle()
                .stroke(outerRingColor, lineWidth: 3)
                .frame(width: outerSize, height: outerSize)
                .scaleEffect(outerPulseScale)
            
            // 2. Внутренний диск: заливка → (опц.) трек и дуга прогресса → иконка → обводка 1 pt
            ZStack {
                Circle()
                    .fill(innerFill)
                
                if showProgressRing {
                    Circle()
                        .stroke(ringColor.opacity(0.3), lineWidth: 4)
                        .frame(width: innerSize, height: innerSize)
                    Circle()
                        .trim(from: 0, to: ringProgress)
                        .stroke(ringColor, lineWidth: 4)
                        .frame(width: innerSize, height: innerSize)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3), value: ringProgress)
                }
                
                Image(systemName: iconName.isEmpty ? "star.fill" : iconName)
                    .font(.system(size: iconFontSize, weight: .semibold))
                    .foregroundColor(glyphColor)
            }
            .frame(width: innerSize, height: innerSize)
            .overlay(Circle().stroke(innerStroke, lineWidth: 1))
        }
        .onAppear {
            updateOuterPulse()
        }
        .onDisappear {
            animationTask?.cancel()
            animationTask = nil
        }
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
