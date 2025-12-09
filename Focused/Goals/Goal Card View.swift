import SwiftUI //
import SwiftData

// MARK: - GOAL CARD VIEW
struct GoalCardView: View {
    let goal: Goal
    let goalDesign: AllGoalsViewDesign
    let onEdit: (() -> Void)?
    
    @Query private var spheres: [Sphere]
    @Environment(\.modelContext) private var modelContext
    private let hapticManager = HapticSoundManager.shared
    @State private var showAdditionalInfo: Bool = false
    @State private var outerPulse = false
    @State private var animationTask: Task<Void, Never>?

    init(goal: Goal, goalDesign: AllGoalsViewDesign, onEdit: (() -> Void)? = nil) {
        self.goal = goal
        self.goalDesign = goalDesign
        self.onEdit = onEdit
    }
    
    private var color: Color {
        Color(hex: goal.colorHex ?? AppConstants.Colors.palette.first!)
    }
    
    private var sphere: Sphere? {
        if let sphereID = goal.sphereID {
            return spheres.first { $0.id == sphereID }
        }
        return nil
    }
    
    private var isCompleted: Bool {
        goal.status == .completed || goal.status == .missed
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Leading circular icon/image
                
                ZStack {
                    // Outer pulsing ring (similar to DualRingSphereIcon)
                    let ringColor: Color = {
                        if isCompleted {
                            return Color.gray
                        }
                        if let imageData = goal.imageData {
                            return (goal.colorHex ?? sphere?.colorHex).map { Color(hex: $0) } ?? color
                        } else if let sphere = sphere {
                            return Color(hex: sphere.colorHex)
                        } else {
                            return .accentColor
                        }
                    }()
                    
                    Circle()
                        .stroke(ringColor.opacity(outerPulseScale > 1.0 ? 0.6 : 0.3), lineWidth: 3)
                        .frame(width: 48, height: 48)
                        .scaleEffect(outerPulseScale)
                    
                    if let imageData = goal.imageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color(UIColor.systemGray5), lineWidth: 1))
                            .opacity(isCompleted ? 0.5 : 1.0)
                    } else if let sphere = sphere {
                        ZStack {
                            Circle()
                                .fill(Color(hex: sphere.colorHex).opacity(isCompleted ? 0.1 : 0.18))
                            Image(systemName: sphere.iconName)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(isCompleted ? Color.gray.opacity(0.5) : Color(hex: sphere.colorHex))
                        }
                        .frame(width: 40, height: 40)
                        .overlay(Circle().stroke((isCompleted ? Color.gray : Color(hex: sphere.colorHex)).opacity(0.3), lineWidth: 1))
                    } else {
                        ZStack {
                            Circle().fill(Color.orange.opacity(isCompleted ? 0.06 : 0.12))
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(isCompleted ? Color.gray.opacity(0.5) : .orange)
                        }
                        .frame(width: 40, height: 40)
                        .overlay(Circle().stroke((isCompleted ? Color.gray : Color.orange).opacity(0.3), lineWidth: 1))
                    }
                }
                .onAppear {
                    updateOuterPulse()
                }
                .onDisappear {
                    animationTask?.cancel()
                    animationTask = nil
                }
                
                // Title
                let leftTitleColorBasic = isCompleted ? Color.gray.opacity(0.5) : Color.primary.opacity(0.8)
                let leftTitleColorRainbow: Color = isCompleted ? .gray.opacity(0.7) : .white
                
                ZStack(alignment: .leading) {
                    strokedText(
                        goal.title,
                        uiFont: UIFont.preferredFont(forTextStyle: .headline),
                        color: .systemGray5,
                        width: 1
                    )
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .allowsHitTesting(false)

                    Text(goal.title)
                        .font(.headline)
                        .foregroundColor(goalDesign == .rainbow ? leftTitleColorRainbow : leftTitleColorBasic)
                        .strikethrough(isCompleted)
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
            
            // DISPLAY ADDITIONAL CARD INFO
            if showAdditionalInfo {
                VStack(alignment: .leading, spacing: 10) {
                    
                    // INFO DIVIDING LINE
                    Rectangle()
                        .fill(LinearGradient(colors: [Color.gray.opacity(0.28), .clear], startPoint: .leading, endPoint: .trailing))
                        .frame(height: 1)
                        .opacity(0.9)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.25), value: showAdditionalInfo)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            chipView(icon: "arrowtriangle.up", text: "+\(String(format: "%.1f", goal.positiveImpact * 10))% -\(String(format: "%.1f", goal.negativeImpact))%")
                            if let reward = goal.reward, !reward.isEmpty {
                                chipView(icon: "trophy", text: reward)
                            }
                            chipView(icon: "list.bullet.circle", text: "\(completedItemsCount())/\(totalItemsCount())")
                            if goal.isFlagged {
                                chipView(icon: "flag", text: "Flagged")
                            }
                            statusChipView(text: statusText(for: goal.status), icon: statusIcon(for: goal.status))
                            if let dueDate = goal.dueDate {
                                chipView(icon: "calendar", text: relativeDateString(for: dueDate))
                            }
                            if !goal.tags.isEmpty {
                                let tagName = goal.tags.first?.name ?? ""
                                chipView(icon: "number", text: "\(tagName)")
                            }
                            if let sphere = sphere {
                                chipView(icon: sphere.iconName, text: sphere.title)
                            }
                        }
                        .padding(.trailing, 4)
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(response: 0.45, dampingFraction: 0.86), value: showAdditionalInfo)

                    if let info = goal.descript, !info.isEmpty {
                        Text(info)
                            .font(.caption2)
                            .foregroundColor(goalDesign == .rainbow ? Color.white.opacity(0.9) : .secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .animation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.04), value: showAdditionalInfo)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
                .offset(y: showAdditionalInfo ? 0 : -6)
                .scaleEffect(x: 1, y: 1, anchor: .top)
                .transition(.opacity)
            }
        }
        .frame(minHeight: 72, alignment: .center)
        .background(
            Group {
                if goalDesign == .rainbow {
                    if isCompleted {
                        Color(UIColor.systemGray4)
                    } else {
                        (goal.colorHex ?? sphere?.colorHex).map { Color(hex: $0) } ?? Color.accentColor
                    }
                } else {
                    Color(UIColor.systemBackground)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .center) {
            let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
            if goalDesign == .rainbow {
                let strokeColor = isCompleted ? Color.gray.opacity(0.35) : ((goal.colorHex ?? sphere?.colorHex).map { Color(hex: $0) } ?? Color.accentColor.opacity(0.35))
                shape
                    .stroke(strokeColor, lineWidth: 0.5)
                    .background(shape.fill(Color.clear))
            } else {
                shape
                    .stroke(Color(UIColor.systemGray5), lineWidth: 0.5)
                    .background(shape.fill(Color.clear))
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        // Removed shadow for unified flat design across all cards
        // .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            hapticManager.selectionChanged()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showAdditionalInfo.toggle()
            }
        }
        .contextMenu {
            // Edit
            Button {
                hapticManager.openPage()
                onEdit?()
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button {
                hapticManager.selectionChanged()
                let newStatus: Goal.Status = (goal.status == .completed) ? .pending : .completed
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    goal.updateStatus(to: newStatus)
                    try? modelContext.save()
                    // Уведомляем об изменении для обновления анимации
                    NotificationCenter.default.post(name: .goalStatusDidChange, object: nil)
                }
            } label: {
                Label(goal.status == .completed ? "Mark Incomplete" : "Mark Complete",
                      systemImage: goal.status == .completed ? "circle" : "checkmark.circle")
            }
            
            Button {
                hapticManager.selectionChanged()
                goal.isFlagged.toggle()
                try? modelContext.save()
            } label: {
                Label(goal.isFlagged ? "Remove Flag" : "Flag",
                      systemImage: goal.isFlagged ? "flag.slash" : "flag")
            }
            
            // Quick toggle calendar due date: Today / Clear
            if goal.dueDate != nil {
                Button {
                    hapticManager.selectionChanged()
                    goal.dueDate = nil
                    try? modelContext.save()
                } label: {
                    Label("Clear Due Date", systemImage: "calendar.badge.minus")
                }
            } else {
                Button {
                    hapticManager.selectionChanged()
                    goal.dueDate = Date()
                    try? modelContext.save()
                } label: {
                    Label("Set Due Today", systemImage: "calendar.badge.plus")
                }
            }
            
            // Duplicate
            Button {
                hapticManager.selectionChanged()
                duplicateGoal()
            } label: {
                Label("Duplicate", systemImage: "doc.on.doc")
            }
            
            Divider()
            
            Button(role: .destructive) {
                hapticManager.itemDeleted()
                modelContext.delete(goal)
                try? modelContext.save()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func duplicateGoal() {
        let copy = Goal(
            title: goal.title,
            description: goal.descript,
            imageData: goal.imageData,
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
            isFlagged: goal.isFlagged
        )
        copy.tags = goal.tags
        modelContext.insert(copy)
        try? modelContext.save()
    }

    // MARK: - Helpers (Chips & Dates)
    private func chipView(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption2)
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color(UIColor.systemGray5).opacity(0.5))
        .clipShape(Capsule())
    }

    private func statusChipView(text: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption2)
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color(UIColor.systemGray5).opacity(0.5))
        .clipShape(Capsule())
    }

    private func statusIcon(for status: Goal.Status) -> String {
        switch status {
        case .pending: return "pause.circle"
        case .inProgress: return "play.circle"
        case .missed: return "xmark.circle"
        case .completed: return "checkmark.circle"
        }
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
    
    private func statusText(for status: Goal.Status) -> String {
        switch status {
        case .pending: return "Paused"
        case .inProgress: return "Progress"
        case .missed: return "Missed"
        case .completed: return "Completed"
        }
    }
    
    private func statusColor(for status: Goal.Status) -> Color {
        switch status {
        case .pending: return .gray
        case .inProgress: return .blue
        case .missed: return .red
        case .completed: return .green
        }
    }
    
    private func completedItemsCount() -> Int {
        let subtaskCount = goal.subtasks.filter { $0.isCompleted }.count
        let counterProgress = goal.counters.reduce(0) { $0 + $1.current }
        return subtaskCount + counterProgress
    }
    
    private func totalItemsCount() -> Int {
        let subtaskCount = goal.subtasks.count
        let counterTarget = goal.counters.reduce(0) { $0 + $1.target }
        return max(subtaskCount + counterTarget, 1) // At least 1 to avoid division by zero
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
