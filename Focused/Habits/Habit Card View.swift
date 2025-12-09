import SwiftUI
import SwiftData

// MARK: - SINGLE HABIT VIEW
struct HabitCardView: View {
    var habit: Habit
    let date: Date
    let design: HabitsViewDesign
    let isFutureDate: Bool
    let onDoubleTap: () -> Void
    
    @Environment(\.modelContext) private var modelContext
    @Query private var spheres: [Sphere]
    @State private var isLongPressing: Bool = false
    @State private var showInfo: Bool = false
    
    private func sphereColor() -> Color {
        if let sid = habit.sphereID, let sphere = spheres.first(where: { $0.id == sid }) {
            return Color(hex: sphere.colorHex)
        }
        return Color(hex: habit.colorHex)
    }
    
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
    
    @ViewBuilder
    func habitContent() -> some View {
        let leftTitleColorBasic = (habit.isCompletedHabit(on: date) || habit.isMissedHabit(on: date) || habit.isSkippedHabit(on: date)) ? Color.gray.opacity(0.5) : Color.primary.opacity(0.8)
        let leftTitleColorRainbow: Color = (habit.isCompletedHabit(on: date) || habit.isMissedHabit(on: date) || habit.isSkippedHabit(on: date)) ? .gray.opacity(0.7) : .white

        HStack(spacing: 12) {
            HStack(spacing: 12) {
                IconWithProgressView(
                    iconName: habit.iconName,
                    progress: !habit.isPassive && habit.requiredRepetitions > 1 ?
                    Double(habit.currentCompletionCount(on: date)) / Double(habit.requiredRepetitions) : 0.0,
                    color: design == .basic ? Color(hex: habit.colorHex) : .white,
                    isCompleted: habit.isCompletedHabit(on: date) || habit.isMissedHabit(on: date) || habit.isSkippedHabit(on: date),
                    isPassive: habit.isPassive,
                    pulse: showInfo
                )
                ZStack(alignment: .leading) {
                    strokedText(
                        habit.title,
                        uiFont: UIFont.preferredFont(forTextStyle: .headline),
                        color: .systemGray5,
                        width: 1
                    )
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .allowsHitTesting(false)

                    Text(habit.title)
                        .font(.headline)
                        .foregroundColor(design == .basic ? leftTitleColorBasic : leftTitleColorRainbow)
                        .strikethrough(habit.isCompletedHabit(on: date) || habit.isMissedHabit(on: date) || habit.isSkippedHabit(on: date))
                        .lineLimit(nil)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(1)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 50)
        }
        // Overlays on the right side so left content can use full width
        .overlay(
            {
                let streak = HabitLogicService(habit: habit).calculateStreak(upTo: date)
                return Group {
                    // Top-right streak (keeps position, no width reservation)
                    StreakView(streakCount: streak)
                        .padding(.trailing, -8)
                        .padding(.top, -3)
                        .opacity(streak >= 2 ? 1 : 0)
                }
            }(), alignment: .topTrailing
        )
    }
    
    // STATUS VIEW
    @ViewBuilder
    func statusView() -> some View {
        let status = habit.completionStatus(on: date)
        
        if status == .activeHabit {
            let streak = HabitLogicService(habit: habit).calculateStreak(upTo: date)
            if habit.requiredRepetitions == 1 {
                StreakView(streakCount: streak)
            } else {
                if streak >= 2 {
                    StreakView(streakCount: streak)
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
    var body: some View {
        VStack(spacing: 0) {
            habitContent()
            
            // DISPLAY ADDITIONAL CARD INFO
            if showInfo {
                VStack(alignment: .leading, spacing: 10) {
                    
                    // INFO DIVIDING LINE
                    Rectangle()
                        .fill(LinearGradient(colors: [Color.gray.opacity(0.28), .clear], startPoint: .leading, endPoint: .trailing))
                        .frame(height: 1)
                        .opacity(0.9)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.25), value: showInfo)

                    HStack {
                        Spacer()
                        WeekStatusCirclesView(
                            dayStatuses: HabitLogicService(habit: habit).statusesForWeek(endingOn: date),
                            selectedDate: date
                        )
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(response: 0.45, dampingFraction: 0.86), value: showInfo)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
                .offset(y: showInfo ? 0 : -6)
                .scaleEffect(x: 1, y: 1, anchor: .top)
                .transition(.opacity)
            }
            
        }
            .frame(minHeight: 72, alignment: .center)
            .background {
                if design == .basic {
                    RoundedRectangle(cornerRadius: habit.isPassive ? 0 : 16, style: .continuous)
                        .fill(Color(UIColor.systemBackground))
                } else {
                    let status = habit.completionStatus(on: date)
                    if status == .completedHabit || status == .missedHabit || status == .skippedHabit {
                        RoundedRectangle(cornerRadius: habit.isPassive ? 0 : 16, style: .continuous)
                            .fill(Color(UIColor.systemGray4))
                    } else {
                        RoundedRectangle(cornerRadius: habit.isPassive ? 0 : 16, style: .continuous)
                            .fill(sphereColor())
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: habit.isPassive ? 0 : 16, style: .continuous))
            .overlay(
                Group {
                    if design == .basic {
                        RoundedRectangle(cornerRadius: habit.isPassive ? 0 : 16, style: .continuous)
                            .stroke(Color(UIColor.systemGray5), lineWidth: 0.5)
                    } else {
                        RoundedRectangle(cornerRadius: habit.isPassive ? 0 : 16, style: .continuous)
                            .stroke(Color.white.opacity(0.35), lineWidth: 0.5)
                    }
                }
            )
            // Removed shadow for unified flat design across all cards
            // .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
            .padding(.vertical, 1)
            .padding(.horizontal, 10)
            .contentShape(Rectangle())
            //.scaleEffect(isLongPressing ? 1.0 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isLongPressing)
            .onTapGesture(count: 2) {
                HapticSoundManager.shared.selectionChanged()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    showInfo.toggle()
                }
            }
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.35)
                    .onChanged { _ in
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            isLongPressing = true
                        }
                    }
                    .onEnded { _ in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isLongPressing = false
                            }
                        }
                    }
            )
        // LONG PRESS CONTEXT MENU
            .contextMenu {

                Button {
                    HapticSoundManager.shared.selectionChanged()
                    onDoubleTap()
                } label: {
                    Label("Edit Habit", systemImage: "pencil")
                }
                
                let status = habit.completionStatus(on: date)
                Button {
                    HapticSoundManager.shared.playHaptic(style: .light)
                    let oldStatus = status
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        if status == .completedHabit {
                            habit.updateStatus(to: .activeHabit, on: date)
                            adjustSphereSatisfaction(for: habit, newStatus: .activeHabit, oldStatus: oldStatus, date: date)
                            HapticSoundManager.shared.actionUndone()
                        } else {
                            habit.updateStatus(to: .completedHabit, on: date)
                            adjustSphereSatisfaction(for: habit, newStatus: .completedHabit, oldStatus: oldStatus, date: date)
                            HapticSoundManager.shared.completionSuccess()
                        }
                        try? modelContext.save()
                        // Уведомляем об изменении для обновления анимации
                        NotificationCenter.default.post(name: .habitStatusDidChange, object: nil)
                    }
                } label: {
                    Label(status == .completedHabit ? "Mark Active" : "Mark Complete", systemImage: status == .completedHabit ? "circle" : "checkmark.circle")
                }
                
                Button {
                    HapticSoundManager.shared.selectionChanged()
                    // Duplicate habit with copied properties
                    let initialRule = habit.repeatingRules.last
                    if let initialRule = initialRule {
                        let duplicated = Habit(
                            title: habit.title,
                            colorHex: habit.colorHex,
                            iconName: habit.iconName,
                            orderIndex: habit.orderIndex + 1,
                            creationDate: Date(),
                            initialRule: initialRule,
                            sphereID: habit.sphereID,
                            isPassive: habit.isPassive,
                            positiveImpact: habit.positiveImpact,
                            negativeImpact: habit.negativeImpact,
                            requiredRepetitions: habit.requiredRepetitions
                        )
                        duplicated.repeatingRules = habit.repeatingRules
                        duplicated.tags = habit.tags
                        modelContext.insert(duplicated)
                        try? modelContext.save()
                    }
                } label: {
                    Label("Duplicate", systemImage: "plus.square.on.square")
                }

                Button(role: .destructive) {
                    HapticSoundManager.shared.itemDeleted()
                    modelContext.delete(habit)
                    try? modelContext.save()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .animation(.bouncy, value: habit.completionStatus(on: date))
            .swipeActions(edge: .leading) {
                if !isFutureDate {
                    let status = habit.completionStatus(on: date)
                    
                    if habit.isPassive {
                        Button {
                            HapticSoundManager.shared.playHaptic(style: .light)
                            let oldStatus = habit.completionStatus(on: date)
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                if status == .skippedHabit || status == .missedHabit {
                                    habit.updateStatus(to: .activeHabit, on: date)
                                    adjustSphereSatisfaction(for: habit, newStatus: .activeHabit, oldStatus: oldStatus, date: date)
                                    HapticSoundManager.shared.actionUndone()
                                } else {
                                    habit.updateStatus(to: status == .completedHabit ? .activeHabit : .completedHabit, on: date)
                                    adjustSphereSatisfaction(for: habit, newStatus: habit.completionStatus(on: date), oldStatus: oldStatus, date: date)
                                    if habit.completionStatus(on: date) == .completedHabit {
                                        HapticSoundManager.shared.completionSuccess()
                                    } else {
                                        HapticSoundManager.shared.actionUndone()
                                    }
                                }
                                try? modelContext.save()
                                // Уведомляем об изменении для обновления анимации
                                NotificationCenter.default.post(name: .habitStatusDidChange, object: nil)
                            }
                        } label: {
                            Label(
                                status == .completedHabit ? "Uncheck" : ((status == .skippedHabit || status == .missedHabit) ? "Unmark" : "Done"),
                                systemImage: status == .completedHabit ? "arrow.uturn.backward.circle.fill" : ((status == .skippedHabit || status == .missedHabit) ? "arrow.uturn.backward.circle.fill" : "checkmark.circle")
                            )
                        }
                        .tint(status == .completedHabit || status == .skippedHabit || status == .missedHabit ? .gray : .green)
                    } else {
                        Button {
                            HapticSoundManager.shared.playHaptic(style: .light)
                            let oldStatus = habit.completionStatus(on: date)
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                if status == .skippedHabit || status == .missedHabit {
                                    habit.updateStatus(to: .activeHabit, on: date)
                                    adjustSphereSatisfaction(for: habit, newStatus: .activeHabit, oldStatus: oldStatus, date: date)
                                    HapticSoundManager.shared.actionUndone()
                                } else {
                                    if habit.currentCompletionCount(on: date) < habit.requiredRepetitions {
                                        habit.incrementCompletion(on: date)
                                    } else {
                                        habit.decrementCompletion(on: date)
                                    }
                                    if habit.isCompletedHabit(on: date) && oldStatus != .completedHabit {
                                        adjustSphereSatisfaction(for: habit, newStatus: .completedHabit, oldStatus: oldStatus, date: date)
                                        HapticSoundManager.shared.completionSuccess()
                                    } else if !habit.isCompletedHabit(on: date) && oldStatus == .completedHabit {
                                        adjustSphereSatisfaction(for: habit, newStatus: .activeHabit, oldStatus: oldStatus, date: date)
                                        HapticSoundManager.shared.actionUndone()
                                    }
                                }
                                try? modelContext.save()
                                // Уведомляем об изменении для обновления анимации
                                NotificationCenter.default.post(name: .habitStatusDidChange, object: nil)
                            }
                        } label: {
                            let isCompleted = habit.isCompletedHabit(on: date)
                            Label(
                                isCompleted ? "Uncheck" : ((status == .skippedHabit || status == .missedHabit) ? "Unmark" : "Done"),
                                systemImage: isCompleted ? "arrow.uturn.backward.circle.fill" : ((status == .skippedHabit || status == .missedHabit) ? "arrow.uturn.backward.circle.fill" : "checkmark.circle")
                            )
                        }
                        .tint(habit.isCompletedHabit(on: date) || status == .skippedHabit || status == .missedHabit ? .gray : .green)
                    }
                }
            }
            .swipeActions(edge: .trailing) {
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
                                // Уведомляем об изменении для обновления анимации
                                NotificationCenter.default.post(name: .habitStatusDidChange, object: nil)
                            }
                        } label: {
                            Label("Unmark", systemImage: "arrow.uturn.backward.circle.fill")
                        }
                        .tint(.gray)
                    } else {
                        Button {
                            HapticSoundManager.shared.playHaptic(style: .light)
                            let oldStatus = habit.completionStatus(on: date)
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                habit.updateStatus(to: .skippedHabit, on: date)
                                adjustSphereSatisfaction(for: habit, newStatus: .skippedHabit, oldStatus: oldStatus, date: date)
                                HapticSoundManager.shared.itemSkipped()
                                try? modelContext.save()
                                // Уведомляем об изменении для обновления анимации
                                NotificationCenter.default.post(name: .habitStatusDidChange, object: nil)
                            }
                        } label: {
                            Label("N/A", systemImage: "minus.circle.fill")
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
                                // Уведомляем об изменении для обновления анимации
                                NotificationCenter.default.post(name: .habitStatusDidChange, object: nil)
                            }
                        } label: {
                            Label("Skip", systemImage: "xmark.circle.fill")
                        }
                        .tint(.red)
                    }
                }
            }
    }
    
    // MARK: - STREAK VIEW
    struct StreakView: View {
        let streakCount: Int
        
        var body: some View {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
                Text("\(streakCount)")
                    .fontWeight(.bold)
                    .foregroundColor(.white.opacity(1))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
            .background(.black.opacity(0.1))
            .clipShape(Capsule())
            .transition(.scale.combined(with: .opacity))
            .scaleEffect(0.7)
        }
    }
    
    // MARK: - WEEK STATUS CIRCLES VIEW
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
    
    // MARK: - PROGRESS CIRCLE VIEW
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

// MARK: - Multiline stroke helper for SwiftUI Text
@ViewBuilder
func strokedText(_ text: String, uiFont: UIFont, color: UIColor, width: CGFloat) -> some View {
    // Render stroke as layered SwiftUI Text to respect SwiftUI layout (wraps across lines)
    let swiftUIColor = Color(color)
    ZStack {
        Text(text).font(.headline).foregroundColor(swiftUIColor).opacity(0.0) // keep layout baseline
        Text(text).font(.headline).foregroundColor(swiftUIColor.opacity(0.6)).offset(x: 0.4, y: 0)
        Text(text).font(.headline).foregroundColor(swiftUIColor.opacity(0.6)).offset(x: -0.4, y: 0)
        Text(text).font(.headline).foregroundColor(swiftUIColor.opacity(0.6)).offset(x: 0, y: 0.4)
        Text(text).font(.headline).foregroundColor(swiftUIColor.opacity(0.6)).offset(x: 0, y: -0.4)
    }
}

struct IconWithProgressView: View {
    let iconName: String
    let progress: Double
    let color: Color
    let isCompleted: Bool
    let isPassive: Bool
    let pulse: Bool
    
    @State private var outerPulse = false
    @State private var animationTask: Task<Void, Never>?
    
    var body: some View {
        ZStack {
            // Show progress ring for all habits
            let ringColor = isCompleted ? Color.gray.opacity(0.3) : color
            let ringProgress = isCompleted ? 1.0 : progress
            let pulseScale: CGFloat = pulse ? 1.12 : 1.0
            
            // Outer pulsing ring (similar to DualRingSphereIcon)
            Circle()
                .stroke(ringColor.opacity(outerPulseScale > 1.0 ? 0.6 : 0.3), lineWidth: 3)
                .frame(width: 48, height: 48)
                .scaleEffect(outerPulseScale)
            
            Circle()
                .stroke(ringColor.opacity(0.3), lineWidth: 4)
                .frame(width: 40, height: 40)
                .scaleEffect(pulseScale)
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: pulse)
            
            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(ringColor, lineWidth: 4)
                .frame(width: 40, height: 40)
                .rotationEffect(.degrees(-90))
                .scaleEffect(pulseScale)
                .animation(.spring(response: 0.35, dampingFraction: 0.68), value: pulse)
                .animation(.easeInOut(duration: 0.3), value: ringProgress)

            // Soft glow halo during pulse
            Circle()
                .stroke(ringColor.opacity(pulse ? 0.25 : 0.0), lineWidth: 6)
                .frame(width: 40, height: 40)
                .scaleEffect(pulse ? 1.2 : 1.0)
                .animation(.spring(response: 0.38, dampingFraction: 0.65), value: pulse)
            
            // Icon with background
            Image(systemName: iconName.isEmpty ? "star.fill" : iconName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(isCompleted ? .gray.opacity(0.3) : color)
                .frame(width: 24, height: 24)
                .padding(4)
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
