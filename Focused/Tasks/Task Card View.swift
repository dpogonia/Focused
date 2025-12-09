import SwiftUI //
import SwiftData

// MARK: - TASK CARD VIEW
struct TaskCardView: View {
    let task: SuperTask
    let onEdit: () -> Void
    
    @Environment(\.modelContext) private var modelContext
    @Query private var appSettings: [TasksSettings]
    @Query private var spheres: [Sphere]
    
    @State private var showSubTasks: Bool = false

    @State private var showAddSubTask = false
    @State private var newSubTaskTitle = ""
    @State private var isDragTarget: Bool = false
    @FocusState private var isSubTaskFieldFocused: Bool
    @State private var outerPulse = false
    @State private var animationTask: Task<Void, Never>?
    @State private var checkboxRotation: Double = 0
    @State private var checkmarkScale: CGFloat = 0
    @State private var checkmarkOpacity: Double = 0
    @State private var checkboxAnimationCompleted: Bool = false
    @State private var pendingStatusChange: SuperTask.Status? = nil
    @State private var visualStatus: SuperTask.Status? = nil
    
    private var design: TasksViewDesign {
        appSettings.first?.design ?? .basic
    }
    
    private var sphereTitle: String? {
        spheres.first(where: { $0.id == task.sphereID })?.title
    }
    
    // Цвет акцента для левой полосы: цвет таска или цвет сферы
    private var accentColor: Color {
        if let hex = task.colorHex, !hex.isEmpty {
            return Color(hex: hex)
        }
        if let sphere = spheres.first(where: { $0.id == task.sphereID }) {
            return Color(hex: sphere.colorHex)
        }
        return .blue
    }
    
    // Контрастный цвет для кольца прогресса (на rainbow фоне используем белый)
    private var progressRingColor: Color {
        switch design {
        case .rainbow:
            return .white
        case .basic:
            return accentColor
        }
    }
    
    private let hapticManager = HapticSoundManager.shared
    
    // MARK: - PRIORITY VISUAL HELPERS
    private var priorityColor: Color {
        switch task.priorityEnum {
        case .none: return .clear
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .flagged: return .red
        }
    }

    // MARK: - DUE DATE HELPERS
    private var isOverdue: Bool {
        guard let dueDate = task.dueDate else { return false }
        return dueDate < Date() && task.statusEnum != .completed
    }
    
    private var isDueSoon: Bool {
        guard let dueDate = task.dueDate else { return false }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dueDay = calendar.startOfDay(for: dueDate)
        let daysUntilDue = calendar.dateComponents([.day], from: today, to: dueDay).day ?? 0
        return daysUntilDue >= 0 && daysUntilDue <= 2 && task.statusEnum != .completed
    }
    
    private var dueDateColor: Color {
        if isOverdue { return .red }
        if isDueSoon { return .orange }
        return .secondary
    }
    
    private var dueDateIcon: String {
        if isOverdue { return "exclamationmark.triangle.fill" }
        if isDueSoon { return "clock.fill" }
        return "calendar"
    }
    
    // MARK: - SMART DEADLINE REMINDERS
    private var deadlineReminder: String? {
        guard let dueDate = task.dueDate else { return nil }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dueDay = calendar.startOfDay(for: dueDate)
        let daysUntilDue = calendar.dateComponents([.day], from: today, to: dueDay).day ?? 0
        
        if isOverdue {
            let overdueDays = abs(daysUntilDue)
            if overdueDays == 1 {
                return "Overdue by 1 day"
            } else {
                return "Overdue by \(overdueDays) days"
            }
        } else if isDueSoon {
            if daysUntilDue == 0 {
                return "Due today!"
            } else if daysUntilDue == 1 {
                return "Due tomorrow"
            } else {
                return "Due in \(daysUntilDue) days"
            }
        }
        return nil
    }
    
    private var deadlineReminderColor: Color {
        if isOverdue { return .red }
        if isDueSoon { return .orange }
        return .secondary
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch design {
                case .basic:
                    basicDesign
                case .rainbow:
                    rainbowDesign
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showSubTasks)
        .contextMenu {
            contextMenuContent
        }
        .onTapGesture(count: 2) {
            // Двойной тап скрывает/показывает субтаски
            hapticManager.selectionChanged()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showSubTasks.toggle()
            }
        }
        .onLongPressGesture {
            // Долгий тап открывает настройки таска
            hapticManager.selectionChanged()
            onEdit()
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button(action: {
                hapticManager.selectionChanged()
                let newStatus: SuperTask.Status = (task.statusEnum == .completed) ? .pending : .completed
                task.updateStatus(to: newStatus)
                try? modelContext.save()
            }) {
                Label(task.statusEnum == .completed ? "Mark Incomplete" : "Mark Complete",
                      systemImage: task.statusEnum == .completed ? "circle" : "checkmark.circle")
            }
            .tint(task.statusEnum == .completed ? .orange : .green)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(action: {
                hapticManager.selectionChanged()
                onEdit()
            }) {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
            
            Button(role: .destructive, action: {
                hapticManager.itemDeleted()
                modelContext.delete(task)
                try? modelContext.save()
            }) {
                Label("Delete", systemImage: "trash")
            }
        }
        .padding(.vertical, 0)
    }
    
    @ViewBuilder
    private var basicDesign: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 12) {
                    checkboxSection
                    
                    let isCompleted = task.statusEnum == .completed
                    let leftTitleColorBasic = isCompleted ? Color.gray.opacity(0.5) : Color.primary.opacity(0.8)
                    
                    ZStack(alignment: .leading) {
                        strokedText(
                            task.title,
                            uiFont: UIFont.preferredFont(forTextStyle: .headline),
                            color: .systemGray5,
                            width: 1
                        )
                        .lineLimit(nil)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .allowsHitTesting(false)

                        Text(task.title)
                            .font(.headline)
                            .foregroundColor(leftTitleColorBasic)
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
            }
            
            // DISPLAY ADDITIONAL CARD INFO
            if showSubTasks {
                VStack(alignment: .leading, spacing: 10) {
                    
                    // INFO DIVIDING LINE
                    Rectangle()
                        .fill(LinearGradient(colors: [Color.gray.opacity(0.28), .clear], startPoint: .leading, endPoint: .trailing))
                        .frame(height: 1)
                        .opacity(0.9)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.25), value: showSubTasks)

                    propertiesScroller
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.spring(response: 0.45, dampingFraction: 0.86), value: showSubTasks)

                    if let descript = task.descript, !descript.isEmpty {
                        Text(descript)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .animation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.02), value: showSubTasks)
                    }

                    if !task.subTasks.isEmpty {
                        subtasksPreview
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .animation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.04), value: showSubTasks)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
                .offset(y: showSubTasks ? 0 : -6)
                .scaleEffect(x: 1, y: 1, anchor: .top)
                .transition(.opacity)
            }
        }
        .frame(minHeight: 72, alignment: .center)
        .background({
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(UIColor.systemBackground))
        }())
        .overlay(alignment: .leading) {
            // Левая цветная полоса
            Rectangle()
                .fill(accentColor)
                .frame(width: 4)
                .shadow(color: task.priorityEnum == .flagged ? Color.red.opacity(0.45) : Color.clear, radius: task.priorityEnum == .flagged ? 6 : 0, x: 0, y: 0)
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .center) {
            let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
            shape
                .stroke(Color(UIColor.systemGray5), lineWidth: 0.5)
                .background(shape.fill(Color.clear))
        }
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        // Removed shadow for unified flat design across all cards
        // .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        // Removed colored stroke border
        .overlay(alignment: .center) {
            // Drag & Drop visual feedback
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isDragTarget ? Color.blue : Color.clear, lineWidth: 2)
                .opacity(isDragTarget ? 0.8 : 0)
                .animation(.easeInOut(duration: 0.2), value: isDragTarget)
        }
    }
    
    @ViewBuilder
    private var checkboxSection: some View {
            Button(action: {
                hapticManager.selectionChanged()
                let wasCompleted = task.statusEnum == .completed
                
                // Сбрасываем флаг завершения анимации
                checkboxAnimationCompleted = false
                
                if wasCompleted {
                    // Анимация исчезновения
                    pendingStatusChange = .pending
                    // Обновляем визуальный статус сразу для визуального эффекта
                    visualStatus = .pending
                    
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        checkmarkScale = 0
                        checkmarkOpacity = 0
                        checkboxRotation += 360
                    }
                    
                    // Ждем полного завершения анимации исчезновения
                    // Spring с response: 0.4 и dampingFraction: 0.6 занимает примерно 0.8-1.0 секунды
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        checkboxAnimationCompleted = true
                        saveAndMoveCard()
                    }
                } else {
                    // Анимация появления с вращением
                    pendingStatusChange = .completed
                    // Обновляем визуальный статус сразу для визуального эффекта
                    visualStatus = .completed
                    checkmarkScale = 0
                    checkmarkOpacity = 0
                    
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        checkboxRotation += 360
                    }
                    
                    // Анимация появления галочки с bounce эффектом
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                            checkmarkScale = 1.3
                            checkmarkOpacity = 1.0
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                checkmarkScale = 1.0
                            }
                            
                            // Ждем полного завершения всех анимаций
                            // Вращение (0.5s) + появление галочки (0.4s) + возврат (0.3s) = ~1.2 секунды
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                checkboxAnimationCompleted = true
                                saveAndMoveCard()
                            }
                        }
                    }
                }
            }) {
                ZStack {
                    // Outer pulsing ring (similar to Habits)
                    Circle()
                        .stroke(progressRingColor.opacity(outerPulseScale > 1.0 ? 0.6 : 0.3), lineWidth: 3)
                        .frame(width: 48, height: 48)
                        .scaleEffect(outerPulseScale)
                    
                    // Внутренний круг-чекбокс
                    ZStack {
                        // Используем visualStatus для визуального отображения, если есть, иначе реальный статус
                        let displayStatus = visualStatus ?? task.statusEnum
                        let isCompleted = displayStatus == .completed
                        
                        // Фон круга (закрашивается при выполнении)
                        Circle()
                            .fill(isCompleted ? accentColor : Color.clear)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Circle()
                                    .stroke(progressRingColor.opacity(isCompleted ? 0.0 : 0.3), lineWidth: 4)
                                    .frame(width: 40, height: 40)
                            )
                            .rotationEffect(.degrees(checkboxRotation))
                            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: displayStatus)
                        
                        // Галочка в центре (появляется при выполнении с заметной анимацией)
                        Image(systemName: "checkmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .scaleEffect(checkmarkScale)
                            .opacity(isCompleted ? checkmarkOpacity : 0)
                            .rotationEffect(.degrees(checkboxRotation))
                    }
                }
            }
            .onAppear {
                // Инициализация состояний при появлении
                visualStatus = nil // Сбрасываем визуальный статус
                if task.statusEnum == .completed {
                    checkmarkScale = 1.0
                    checkmarkOpacity = 1.0
                } else {
                    checkmarkScale = 0
                    checkmarkOpacity = 0
                }
            }
            .onChange(of: task.statusEnum) { oldValue, newValue in
                if newValue == .completed && oldValue != .completed {
                    // При изменении на completed запускаем анимацию
                    checkmarkScale = 0
                    checkmarkOpacity = 0
                    
                    // Небольшая задержка перед появлением для синхронизации с вращением
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                            checkmarkScale = 1.3
                            checkmarkOpacity = 1.0
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                checkmarkScale = 1.0
                            }
                        }
                    }
                } else if newValue != .completed {
                    // При снятии галочки
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        checkmarkScale = 0
                        checkmarkOpacity = 0
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
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
    
    private func saveAndMoveCard() {
        // Сохраняем только если анимация завершена
        guard checkboxAnimationCompleted else { return }
        
        // Обновляем реальный статус задачи только после завершения анимации
        if let pendingStatus = pendingStatusChange {
            task.updateStatus(to: pendingStatus)
            
            // Сохраняем с анимацией перемещения
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                try? modelContext.save()
                // Уведомляем об изменении для обновления анимации
                NotificationCenter.default.post(name: .taskStatusDidChange, object: nil)
            }
        }
        
        // Сбрасываем флаги и визуальный статус
        pendingStatusChange = nil
        checkboxAnimationCompleted = false
        visualStatus = nil
    }
    
    // MARK: - Status Animation Properties
    private var statusIconName: String {
        switch task.statusEnum {
        case .pending: return "circle"
        case .inProgress: return "play.circle.fill"
        case .review: return "eye.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        }
    }
    
    private var statusIconColor: Color {
        switch task.statusEnum {
        case .pending: return progressRingColor
        case .inProgress: return .blue
        case .review: return .purple
        case .completed: return .green
        case .cancelled: return .red
        }
    }
    
    private var statusBackgroundColor: Color {
        // Во всех режимах (кроме rainbow) внутренний круг совпадает по цвету с внешним кольцом чекбокса
        if design == .rainbow { return .clear }
        return progressRingColor.opacity(0.18)
    }
    
    private var statusAnimationScale: CGFloat {
        switch task.statusEnum {
        case .pending: return 1.0
        case .inProgress: return 1.1
        case .review: return 1.05
        case .completed: return 1.2
        case .cancelled: return 0.9
        }
    }
    
    private var statusAnimationOpacity: Double {
        switch task.statusEnum {
        case .pending: return 0.0
        case .inProgress: return 0.3
        case .review: return 0.2
        case .completed: return 0.4
        case .cancelled: return 0.2
        }
    }
    
    private var statusIconScale: CGFloat {
        switch task.statusEnum {
        case .pending: return 1.0
        case .inProgress: return 1.1
        case .review: return 1.05
        case .completed: return 1.2
        case .cancelled: return 0.9
        }
    }
    
    private var statusIconRotation: Double {
        switch task.statusEnum {
        case .pending: return 0
        case .inProgress: return 0
        case .review: return 0
        case .completed: return 360
        case .cancelled: return 180
        }
    }
    
    // MARK: - Subtasks Preview
    @ViewBuilder
    private var subtasksPreview: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Заголовок с количеством
            
            // Скроллируемый список всех субтасков
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(task.subTasks, id: \.id) { subTask in
                        HStack(spacing: 6) {
                            // Интерактивный статус субтаска
                            Button(action: {
                                hapticManager.selectionChanged()
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    subTask.toggleCompletion()
                                }
                                try? modelContext.save()
                            }) {
                                Image(systemName: subTask.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .font(.caption2)
                                    .foregroundColor(subTask.isCompleted ? .green : .white)
                                    .scaleEffect(subTask.isCompleted ? 1.1 : 1.0)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: subTask.isCompleted)
                            }
                            .buttonStyle(.plain)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.1))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.gray.opacity(0.5), lineWidth: 0.5)
                            )
                            
                            // Название субтаска
                            Text(subTask.title)
                                .font(.caption2)
                                .foregroundColor(design == .rainbow ? .white : .primary)
                                .foregroundColor(subTask.isCompleted ? .secondary : .primary)
                                .strikethrough(subTask.isCompleted)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            // Время выполнения (если указано)
                            if subTask.estimatedDuration > 0 {
                                Text("\(subTask.estimatedDuration)min")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color(UIColor.systemGray6))
                                    )
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                    }
                    // Поле для быстрого добавления субтаска
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.blue)
                        
                        TextField("...", text: $newSubTaskTitle)
                            .font(.caption2)
                            .textFieldStyle(.plain)
                            .foregroundColor(design == .rainbow ? .white : .primary)
                            .onSubmit {
                                addNewSubTask()
                            }
                            .focused($isSubTaskFieldFocused)
                        
                        if !newSubTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button(action: {
                                addNewSubTask()
                            }) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
//                    .background(
//                        RoundedRectangle(cornerRadius: 6)
//                            .fill(Color.blue.opacity(0.1))
//                    )
//                    .overlay(
//                        RoundedRectangle(cornerRadius: 6)
//                            .stroke(Color.blue.opacity(0.3), lineWidth: 0.5)
//                    )
                }
            }
            .frame(maxHeight: 120) // Ограничиваем высоту скролла
        }
        .padding(.top, 4)
    }
            
    @ViewBuilder
    private var mainContentSection: some View {
        ZStack(alignment: .leading) {
            strokedText(
                task.title,
                uiFont: UIFont.preferredFont(forTextStyle: .headline),
                color: .systemGray5,
                width: 1
            )
            .lineLimit(nil)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .allowsHitTesting(false)

            Text(task.title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(design == .rainbow ? .white : .primary)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
        }
    }

    // MARK: - Unified horizontally scrollable properties under the title
    @ViewBuilder
    private var propertiesScroller: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // AMOUNT OF SUBTASKS
                if task.subTasks.count != 0 { HStack(spacing: 6) {
                    Text("\(task.subTasks.filter { $0.isCompleted }.count)/\(task.subTasks.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color(UIColor.secondarySystemBackground)))
                    
                }
                }
                
                if let dueDate = task.dueDate {
                    HStack(spacing: 4) {
                        Image(systemName: dueDateIcon)
                            .font(.caption)
                            .foregroundColor(dueDateColor)
                        Text(dueDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundColor(dueDateColor)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(dueDateColor.opacity(0.1)))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(dueDateColor.opacity(0.3), lineWidth: 1))
                }

                if !(task.statusEnum == .pending &&
                      task.dueDate == nil &&
                      task.priorityEnum == .none &&
                      task.repeatingEnum == .none &&
                      task.tags.isEmpty &&
                      task.sphereID == nil &&
                      task.positiveImpact == 0 &&
                      task.negativeImpact == 0 &&
                      task.subTasks.isEmpty) {
                    HStack(spacing: 4) {
                        Image(systemName: statusIcon(for: task.statusEnum))
                            .font(.caption)
                            .foregroundColor(statusColor(for: task.statusEnum))
                        Text(task.statusEnum.displayString)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color(UIColor.secondarySystemBackground)))
                }

                if task.priorityEnum != .none {
                    HStack(spacing: 4) {
                        Image(systemName: priorityIcon(for: task.priorityEnum))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(task.priorityEnum.displayString)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color(UIColor.secondarySystemBackground)))
                }

                if task.repeatingEnum != .none {
                    HStack(spacing: 4) {
                        Image(systemName: "repeat")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(task.repeatingEnum.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color(UIColor.secondarySystemBackground)))
                }

                if let sphereTitle = sphereTitle {
                    HStack(spacing: 4) {
                        Image(systemName: "circlebadge")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(sphereTitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color(UIColor.secondarySystemBackground)))
                }

                if task.positiveImpact > 0 || task.negativeImpact > 0 {
                    HStack(spacing: 6) {
                        if task.positiveImpact > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                Text(String(format: "%.0f%%", task.positiveImpact))
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                        if task.negativeImpact > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                Text(String(format: "%.0f%%", task.negativeImpact))
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color(UIColor.secondarySystemBackground)))
                }

                ForEach(task.tags) { tag in
                    Text("#\(tag.name)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color(UIColor.secondarySystemBackground)))
                }
            }
            .padding(.vertical, 2)
        }
    }
    
    @ViewBuilder
    private var metaInfoSection: some View {
        VStack(spacing: 8) {
            // Due Date with Smart Reminders
            if let dueDate = task.dueDate {
                VStack(spacing: 4) {
                    // Date display
                    HStack(spacing: 4) {
                        Image(systemName: dueDateIcon)
                            .font(.caption)
                            .foregroundColor(dueDateColor)
                            .frame(width: 14)
                        
                        Text(dueDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundColor(dueDateColor)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(dueDateColor.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(dueDateColor.opacity(0.3), lineWidth: 1)
                    )
                    
                    // Smart reminder text
                    if let reminder = deadlineReminder {
                        Text(reminder)
                            .font(.caption2)
                            .foregroundColor(deadlineReminderColor)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(deadlineReminderColor.opacity(0.1))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(deadlineReminderColor.opacity(0.2), lineWidth: 0.5)
                            )
                            .scaleEffect(1.0)
                            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: reminder)
                    }
                }
            }
            
            // Subtasks Progress (если есть)
            if !task.subTasks.isEmpty {
                HStack(spacing: 8) {
                    // Subtask count
                    HStack(spacing: 4) {
                        Image(systemName: "list.bullet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 14)
                        
                        Text("\(task.subTasks.filter { $0.isCompleted }.count)/\(task.subTasks.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Enhanced Progress Ring
                    HStack(spacing: 8) {
                        // Animated Circular Progress Ring
                        ZStack {
                            // Background ring with shadow
                            Circle()
                                .stroke(Color.gray.opacity(0.15), lineWidth: 3)
                                .frame(width: 24, height: 24)
                                .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                            
                            // Progress ring with gradient and animation
                            Circle()
                                .trim(from: 0, to: task.completionProgress())
                                .stroke(
                                    LinearGradient(
                                        colors: [.blue, .green, .mint],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                                )
                                .frame(width: 24, height: 24)
                                .rotationEffect(.degrees(-90))
                                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: task.completionProgress())
                                .overlay(
                                    // Glow effect
                                    Circle()
                                        .trim(from: 0, to: task.completionProgress())
                                        .stroke(
                                            LinearGradient(
                                                colors: [.blue.opacity(0.3), .green.opacity(0.3)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                                        )
                                        .frame(width: 24, height: 24)
                                        .rotationEffect(.degrees(-90))
                                        .blur(radius: 1.5)
                                        .opacity(task.completionProgress() > 0 ? 0.6 : 0)
                                        .animation(.easeInOut(duration: 0.4), value: task.completionProgress())
                                )
                            
                            // Percentage text
                            Text("\(Int(task.completionProgress() * 100))%")
                                .font(.system(size: 7, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                                .scaleEffect(task.completionProgress() > 0 ? 1.0 : 0.8)
                                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: task.completionProgress())
                        }
                        .scaleEffect(task.completionProgress() == 1.0 ? 1.05 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: task.completionProgress())
                        
                        // Compact Linear Progress Bar
                        GeometryReader { geometry in
                                                    ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(UIColor.systemGray4))
                                .frame(height: 4)
                            
                            RoundedRectangle(cornerRadius: 2)
                                .fill(
                                    LinearGradient(
                                        colors: [.blue, .green, .mint],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * task.completionProgress(), height: 4)
                                .shadow(color: Color.primary.opacity(0.2), radius: 1, x: 0, y: 1)
                                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: task.completionProgress())
                            }
                        }
                        .frame(width: 40, height: 4)
                    }
                    
                    // Expand/Collapse indicator
                    if showSubTasks {
                        Image(systemName: "chevron.up")
                            .font(.caption2)
                            .foregroundColor(.blue)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.8)
                                    .combined(with: .opacity)
                                    .combined(with: .offset(y: -5)),
                                removal: .scale(scale: 0.8)
                                    .combined(with: .opacity)
                                    .combined(with: .offset(y: 5))
                            ))
                            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: showSubTasks)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var tagsAndImpactSection: some View {
                HStack {
                    if !task.tags.isEmpty {
                        Text("#\(task.tags.first?.name ?? "")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if task.sphereID != nil || task.positiveImpact > 0 || task.negativeImpact > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "dumbbell")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(sphereTitle ?? "Task")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("↑\(String(format: "%.0f", task.positiveImpact * 10))%")
                                .font(.caption)
                                .foregroundColor(.green)
                            
                            Text("↓\(String(format: "%.1f", task.negativeImpact))%")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(UIColor.systemGray4), lineWidth: 1)
                        )
                    }
                }
            }
            
    @ViewBuilder
    private var actionsSection: some View {
            VStack(alignment: .trailing, spacing: 8) {
                // Флаг убран — используйте приоритет .flagged
                
                Menu {
                    ForEach(SuperTask.Status.allCases, id: \.self) { status in
                        Button {
                            hapticManager.selectionChanged()
                            task.updateStatus(to: status)
                            try? modelContext.save()
                        } label: {
                        Label(status.displayString, systemImage: statusIcon(for: status))
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    
    @ViewBuilder
    private var colorfulDesign: some View {
        VStack(alignment: .leading, spacing: 8) {
            colorfulHeaderSection
            colorfulDescriptionSection
            colorfulMetaSection
            colorfulTagsSection
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        // Removed colored stroke border
        .overlay(
            // Верхняя полоска приоритета для colorful design
            Rectangle()
                .fill(priorityColor)
                .frame(height: 4)
                .clipShape(RoundedRectangle(cornerRadius: 2))
                .opacity(task.priorityEnum == .none ? 0 : 1),
            alignment: .top
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.primary.opacity(0.1), radius: 4, x: 0, y: 2)
        
        // Секция субтасков как часть карточки
        if showSubTasks {
            VStack(spacing: 0) {
                Divider()
                    .padding(.horizontal, 16)
                
                VStack(spacing: 6) {
                    if task.subTasks.isEmpty {
                        subtaskAddInline
                    } else {
                        subtasksListRemindersStyle
                        subtaskAddInline
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .move(edge: .bottom)).combined(with: .scale(scale: 0.98, anchor: .bottom)),
                removal: .opacity.combined(with: .move(edge: .bottom)).combined(with: .scale(scale: 0.98, anchor: .bottom))
            ))
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: showSubTasks)
        }
    }
    
    // MARK: - Reminders-like minimal row
    @ViewBuilder
    private var remindersDesign: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                // Leading status dot similar to Reminders
                Button {
                    hapticManager.selectionChanged()
                    let next: SuperTask.Status = task.statusEnum == .completed ? .pending : .completed
                    task.updateStatus(to: next)
                    try? modelContext.save()
                } label: {
                    Image(systemName: task.statusEnum == .completed ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(task.statusEnum == .completed ? .green : .secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    let isCompleted = task.statusEnum == .completed
                    Text(task.title)
                        .font(.body)
                        .foregroundColor(isCompleted ? Color.gray.opacity(0.5) : .primary)
                        .strikethrough(isCompleted, color: .secondary)
                        .lineLimit(2)

                    // Inline meta line
                    HStack(spacing: 8) {
                        if let dueDate = task.dueDate {
                            Label(dueDate.formatted(date: .abbreviated, time: .omitted), systemImage: dueDateIcon)
                                .font(.caption)
                                .foregroundColor(dueDateColor)
                        }
                        if task.priorityEnum != .none {
                            Image(systemName: priorityIcon(for: task.priorityEnum))
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        if !task.subTasks.isEmpty {
                            Label("\(task.subTasks.filter { $0.isCompleted }.count)/\(task.subTasks.count)", systemImage: "checkmark.square")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

            }

        }
        .padding(.vertical, 10)
        .padding(.horizontal, 0)

        
                // Секция субтасков как часть карточки
        if showSubTasks {
            VStack(spacing: 0) {
                Divider()
                    .padding(.leading, 46)
                
                VStack(spacing: 6) {
                    if task.subTasks.isEmpty {
                        subtaskAddInline
                    } else {
                        subtasksListRemindersStyle
                        subtaskAddInline
                    }
                }
                .padding(.trailing, 8)
            }
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .move(edge: .bottom)).combined(with: .scale(scale: 0.98, anchor: .bottom)),
                removal: .opacity.combined(with: .move(edge: .bottom)).combined(with: .scale(scale: 0.98, anchor: .bottom))
            ))
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: showSubTasks)
        }
    }
    
    // MARK: - Plain list-row style (no border, default separators)
    @ViewBuilder
    private var plainDesign: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Button {
                    hapticManager.selectionChanged()
                    let next: SuperTask.Status = task.statusEnum == .completed ? .pending : .completed
                    task.updateStatus(to: next)
                    try? modelContext.save()
                } label: {
                    Image(systemName: task.statusEnum == .completed ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(task.statusEnum == .completed ? .green : .secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
                
                VStack(alignment: .leading, spacing: 4) {
                    let isCompleted = task.statusEnum == .completed
                    Text(task.title)
                        .font(.body)
                        .foregroundColor(isCompleted ? Color.gray.opacity(0.5) : .primary)
                        .strikethrough(isCompleted, color: .secondary)
                        .lineLimit(2)
                    HStack(spacing: 8) {
                        if let dueDate = task.dueDate {
                            Label(dueDate.formatted(date: .abbreviated, time: .omitted), systemImage: dueDateIcon)
                                .font(.caption)
                                .foregroundColor(dueDateColor)
                        }
                        if task.priorityEnum != .none {
                            Image(systemName: priorityIcon(for: task.priorityEnum))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        if !task.subTasks.isEmpty {
                            Label("\(task.subTasks.filter { $0.isCompleted }.count)/\(task.subTasks.count)", systemImage: "checkmark.square")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                Spacer()
                // Флаг убран — используйте приоритет .flagged
            }
            if let descript = task.descript, !descript.isEmpty {
                Text(descript)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 0)
        .contentShape(Rectangle())
        
                // Секция субтасков как часть карточки
        if showSubTasks {
            VStack(spacing: 0) {
                Divider()
                    .padding(.leading, 46)
                
                VStack(spacing: 6) {
                    if task.subTasks.isEmpty {
                        subtaskAddInline
                    } else {
                        subtasksListRemindersStyle
                        subtaskAddInline
                    }
                }
                .padding(.trailing, 8)
            }
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .move(edge: .bottom)).combined(with: .scale(scale: 0.98, anchor: .bottom)),
                removal: .opacity.combined(with: .move(edge: .bottom)).combined(with: .scale(scale: 0.98, anchor: .bottom))
            ))
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: showSubTasks)
        }
    }
    
    // MARK: - Minimal style (no checkbox, swipe-only, flat list row)
    @ViewBuilder
    private var rainbowDesign: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 12) {
                    checkboxSection
                    
                    let isCompleted = task.statusEnum == .completed
                    let leftTitleColorRainbow: Color = isCompleted ? .gray.opacity(0.7) : .white
                    
                    ZStack(alignment: .leading) {
                        strokedText(
                            task.title,
                            uiFont: UIFont.preferredFont(forTextStyle: .headline),
                            color: .systemGray5,
                            width: 1
                        )
                        .lineLimit(nil)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .allowsHitTesting(false)

                        Text(task.title)
                            .font(.headline)
                            .foregroundColor(leftTitleColorRainbow)
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
            }
            
            // DISPLAY ADDITIONAL CARD INFO
            if showSubTasks {
                VStack(alignment: .leading, spacing: 10) {
                    
                    // INFO DIVIDING LINE
                    Rectangle()
                        .fill(LinearGradient(colors: [Color.gray.opacity(0.28), .clear], startPoint: .leading, endPoint: .trailing))
                        .frame(height: 1)
                        .opacity(0.9)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.25), value: showSubTasks)

                    propertiesScroller
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.spring(response: 0.45, dampingFraction: 0.86), value: showSubTasks)

                    if let descript = task.descript, !descript.isEmpty {
                        Text(descript)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .animation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.02), value: showSubTasks)
                    }

                    if !task.subTasks.isEmpty {
                        subtasksPreview
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .animation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.04), value: showSubTasks)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
                .offset(y: showSubTasks ? 0 : -6)
                .scaleEffect(x: 1, y: 1, anchor: .top)
                .transition(.opacity)
            }
        }
        .frame(minHeight: 72, alignment: .center)
        .background(
            Group {
                let isCompleted = task.statusEnum == .completed
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isCompleted ? Color(UIColor.systemGray4) : accentColor)
            }
        )
        .overlay(alignment: .center) {
            let isCompleted = task.statusEnum == .completed
            let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
            let strokeColor = isCompleted ? Color.gray.opacity(0.35) : accentColor.opacity(0.35)
            shape
                .stroke(strokeColor, lineWidth: 0.5)
                .background(shape.fill(Color.clear))
        }
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        // Removed shadow for unified flat design across all cards
        // .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        // Removed colored stroke border
        .overlay(
            // Drag & Drop visual feedback
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isDragTarget ? Color.blue : Color.clear, lineWidth: 2)
                .opacity(isDragTarget ? 0.8 : 0)
                .animation(.easeInOut(duration: 0.2), value: isDragTarget)
        )
    }
    @ViewBuilder
    private var colorfulHeaderSection: some View {
            HStack(alignment: .top) {
            Image(systemName: statusIcon(for: task.statusEnum))
                    .font(.title3)
                .foregroundColor(statusColor(for: task.statusEnum))
                    .frame(width: 24, height: 24)
                
                Text(task.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                Spacer()
                
                
                Menu {
                    ForEach(SuperTask.Status.allCases, id: \.self) { status in
                        Button {
                            hapticManager.selectionChanged()
                            task.updateStatus(to: status)
                        } label: {
                        Label(status.displayString, systemImage: statusIcon(for: status))
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
            }
                }
            }
            
    @ViewBuilder
    private var colorfulDescriptionSection: some View {
            if let descript = task.descript {
                Text(descript)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
        }
            }
            
    @ViewBuilder
    private var colorfulMetaSection: some View {
            HStack(spacing: 12) {
                if let dueDate = task.dueDate {
                    Label(dueDate.formatted(date: .abbreviated, time: .omitted), systemImage: dueDateIcon)
                        .font(.caption2)
                        .foregroundColor(dueDateColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(dueDateColor.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(dueDateColor.opacity(0.3), lineWidth: 1)
                        )
                }
                
                if task.priorityEnum != .none {
                    Label(task.priorityEnum.displayString, systemImage: priorityIcon(for: task.priorityEnum))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
            if task.repeatingEnum != .none {
                Label(task.repeatingEnum.rawValue.capitalized, systemImage: "repeat")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                if !task.subTasks.isEmpty {
                    HStack(spacing: 4) {
                        CircularProgressView(progress: task.completionProgress())
                        .frame(width: 16, height:16)
                        
                        Label("\(task.subTasks.filter { $0.isCompleted }.count)/\(task.subTasks.count)", systemImage: "checkmark.square.stack")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    
                    // Индикатор развернутых субтасков
                    if showSubTasks {
                        Image(systemName: "chevron.up")
                            .font(.caption2)
                            .foregroundColor(.blue)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.8)
                                    .combined(with: .opacity)
                                    .combined(with: .offset(y: -5)),
                                removal: .scale(scale: 0.8)
                                    .combined(with: .opacity)
                                    .combined(with: .offset(y: 5))
                            ))
                            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: showSubTasks)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var colorfulTagsSection: some View {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(task.tags) { tag in
                        Text("#\(tag.name)")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: task.colorHex ?? "#3498db").opacity(0.15))
                            .clipShape(Capsule())
                    }
                    
                    if let sphereTitle = sphereTitle {
                        Text(sphereTitle)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: task.colorHex ?? "#3498db").opacity(0.15))
                            .clipShape(Capsule())
                    }
                    
                    if task.positiveImpact > 0 || task.negativeImpact > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up")
                                .font(.caption2)
                                .foregroundColor(.green)
                            
                            Text(String(format: "%.1f%%", task.positiveImpact))
                                .font(.caption2)
                                .foregroundColor(.green)
                            
                            Image(systemName: "arrow.down")
                                .font(.caption2)
                                .foregroundColor(.red)
                            
                            Text(String(format: "%.1f%%", task.negativeImpact))
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                                                .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: task.colorHex ?? "#3498db").opacity(0.15))
                            .clipShape(Capsule())
                    }
            }
        }
    }
    
    private func statusIcon(for status: SuperTask.Status) -> String {
        switch status {
        case .pending: return "circle"
        case .inProgress: return "play.circle"
        case .review: return "eye.circle"
        case .completed: return "checkmark.circle"
        case .cancelled: return "xmark.circle"
        }
    }
    
    private func statusColor(for status: SuperTask.Status) -> Color {
        switch status {
        case .pending: return .gray
        case .inProgress: return .blue
        case .review: return .purple
        case .completed: return .green
        case .cancelled: return .red
        }
    }
    
    private func priorityIcon(for priority: SuperTask.PriorityEnum) -> String {
        switch priority {
        case .none: return "exclamationmark.circle"
        case .low: return "exclamationmark"
        case .medium: return "exclamationmark.2"
        case .high: return "exclamationmark.3"
        case .flagged: return "bolt.circle"
        }
    }
    
    // MARK: - CONTEXT MENU
    @ViewBuilder
    private var contextMenuContent: some View {
        // MARK: - Основные действия
        Button {
            onEdit()
            hapticManager.selectionChanged()
        } label: {
            Label("Edit Task", systemImage: "pencil")
        }
        
        Button {
            toggleTaskCompletion()
            hapticManager.completionSuccess()
        } label: {
            Label(task.statusEnum == .completed ? "Mark Incomplete" : "Mark Complete",
                  systemImage: task.statusEnum == .completed ? "circle" : "checkmark.circle")
        }
        
        // MARK: - Быстрые действия
        if !task.subTasks.isEmpty {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showSubTasks.toggle()
                }
                hapticManager.selectionChanged()
            } label: {
                Label(showSubTasks ? "Hide Subtasks" : "Show Subtasks",
                      systemImage: showSubTasks ? "eye.slash" : "eye")
            }
            

        }
        
        Divider()
        
        // MARK: - Флаги и метки
        // Действие флага удалено — используется приоритет .flagged
        
        // MARK: - Приоритет
        Menu("Priority") {
            ForEach(SuperTask.PriorityEnum.allCases, id: \.self) { priority in
                Button {
                    changePriority(to: priority)
                    hapticManager.selectionChanged()
                } label: {
                    HStack {
                        Text(priority.displayString)
                        if task.priorityEnum == priority {
                            Image(systemName: "checkmark")
                                .foregroundColor(.green)
                        }
                    }
                }
            }
        }
        
        // MARK: - Статус
        Menu("Status") {
            ForEach(SuperTask.Status.allCases, id: \.self) { status in
                Button {
                    changeStatus(to: status)
                    hapticManager.selectionChanged()
                } label: {
                    HStack {
                        Text(status.displayString)
                        if task.statusEnum == status {
                            Image(systemName: "checkmark")
                                .foregroundColor(.green)
                        }
                    }
                }
            }
        }
        
        // MARK: - Дополнительные действия
        if let dueDate = task.dueDate {
            Button {
                // Копировать дату в буфер обмена
                UIPasteboard.general.string = dueDate.formatted(date: .complete, time: .omitted)
                hapticManager.selectionChanged()
            } label: {
                Label("Copy Due Date", systemImage: "doc.on.doc")
            }
        }
        
        if !task.tags.isEmpty {
            Button {
                // Копировать теги в буфер обмена
                let tagsString = task.tags.map { "#\($0.name)" }.joined(separator: " ")
                UIPasteboard.general.string = tagsString
                hapticManager.selectionChanged()
            } label: {
                Label("Copy Tags", systemImage: "tag")
            }
        }
        
        Divider()
        
        // MARK: - Опасные действия
        Button(role: .destructive) {
            deleteTask()
            hapticManager.itemDeleted()
        } label: {
            Label("Delete Task", systemImage: "trash")
        }
    }
    
    // MARK: - SUBTASK MANAGEMENT
    private func addNewSubTask() {
        let title = newSubTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        
        let newSubTask = SubTask(
            title: title,
            isCompleted: false,
            orderIndex: task.subTasks.count,
            estimatedDuration: 0,
            notes: nil
        )
        
        task.subTasks.append(newSubTask)
        newSubTaskTitle = ""
        showAddSubTask = false
        
        hapticManager.selectionChanged()
        try? modelContext.save()
    }
    
    // MARK: - CONTEXT MENU ACTIONS
    private func toggleTaskCompletion() {
        let newStatus: SuperTask.Status = (task.statusEnum == .completed) ? .pending : .completed
        task.status = newStatus.rawValue
        try? modelContext.save()
    }
    
    // Флаг удалён — используйте приоритет .flagged
    private func toggleTaskFlag() { }
    
    private func changePriority(to priority: SuperTask.PriorityEnum) {
        let oldPriority = task.priorityEnum
        
        // Анимация изменения приоритета
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            task.priority = priority.rawValue
        }
        
        // Haptic feedback в зависимости от приоритета
        switch priority {
        case .flagged:
            hapticManager.selectionChanged()
        case .high:
            hapticManager.selectionChanged()
        case .medium:
            hapticManager.selectionChanged()
        case .low:
            hapticManager.selectionChanged()
        case .none:
            hapticManager.selectionChanged()
        }
        
        // Дополнительные действия для высоких приоритетов
        if priority == .flagged && oldPriority != .flagged {
            // Двойной haptic feedback для срочных тасков
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                hapticManager.selectionChanged()
            }
        }
        
        try? modelContext.save()
    }
    
    private func changeStatus(to status: SuperTask.Status) {
        let oldStatus = task.statusEnum
        
        // Анимация изменения статуса
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            task.status = status.rawValue
        }
        
        // Haptic feedback в зависимости от нового статуса
        switch status {
        case .completed:
            hapticManager.completionSuccess()
        case .cancelled:
            hapticManager.itemDeleted()
        case .inProgress:
            hapticManager.selectionChanged()
        case .review:
            hapticManager.selectionChanged()
        case .pending:
            hapticManager.selectionChanged()
        }
        
        // Дополнительные действия для определенных статусов
        if status == .completed && oldStatus != .completed {
            // Показать кратковременное уведомление о завершении
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                hapticManager.completionSuccess()
            }
        }
        
        try? modelContext.save()
    }
    
    private func deleteTask() {
        modelContext.delete(task)
        try? modelContext.save()
    }
    

    
    // MARK: - SUBTASKS COMPONENTS
    @ViewBuilder
    private var subtasksDivider: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.clear, Color.blue.opacity(0.3), Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private var subtasksHeader: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "list.bullet.rectangle")
                    .font(.subheadline)
                    .foregroundColor(.blue)
                
                Text("Subtasks")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            // Прогресс с красивым дизайном
            HStack(spacing: 6) {
                ZStack {
                    Circle()
                        .stroke(Color(UIColor.systemGray4), lineWidth: 3)
                        .frame(width: 24, height: 24)
                    
                    Circle()
                        .trim(from: 0, to: task.completionProgress())
                        .stroke(
                            LinearGradient(
                                colors: [.blue, .green],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 24, height: 24)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: task.completionProgress())
                }
                
                Text("\(task.subTasks.filter { $0.isCompleted }.count)/\(task.subTasks.count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
    
    @ViewBuilder
    private var subtasksList: some View {
        LazyVStack(spacing: 8) {
            ForEach(Array(task.subTasks.sorted(by: { $0.orderIndex < $1.orderIndex }).enumerated()), id: \.element.id) { index, subTask in
                SubTaskRowView(subTask: subTask, task: task)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8)
                            .combined(with: .opacity)
                            .combined(with: .offset(y: 20)),
                        removal: .scale(scale: 0.8)
                            .combined(with: .opacity)
                            .combined(with: .offset(y: -20))
                    ))
                    .animation(
                        .spring(response: 0.5, dampingFraction: 0.7)
                        .delay(Double(index) * 0.05),
                        value: showSubTasks
                    )
            }
        }
        .padding(.horizontal, 16)
    }

    // Reminders-style compact subtasks list
    @ViewBuilder
    private var subtasksListRemindersStyle: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(task.subTasks.sorted(by: { $0.orderIndex < $1.orderIndex }).enumerated()), id: \.element.id) { index, subTask in
                HStack(spacing: 10) {
                    Button {
                        hapticManager.selectionChanged()
                        subTask.toggleCompletion()
                        try? modelContext.save()
                    } label: {
                        Image(systemName: subTask.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(subTask.isCompleted ? .green : .secondary)
                    }
                    .buttonStyle(.plain)
                    
                    Text(subTask.title)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .strikethrough(subTask.isCompleted, color: .secondary)
                        .lineLimit(2)
                    
                    Spacer()
                }
                .padding(.vertical, 10)
                .padding(.trailing, 8)
                .contentShape(Rectangle())
                .transition(.asymmetric(
                    insertion: .opacity
                        .combined(with: .move(edge: .top))
                        .combined(with: .scale(scale: 0.995, anchor: .topLeading)),
                    removal: .opacity
                        .combined(with: .move(edge: .top))
                        .combined(with: .scale(scale: 0.995, anchor: .topLeading))
                ))
                .animation(.spring(response: 0.45, dampingFraction: 0.9).delay(Double(index) * 0.02), value: showSubTasks)
                Divider().padding(.leading, 36)
            }
        }
    }

    @ViewBuilder
    private var subtaskAddInline: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .foregroundColor(.blue)
            TextField("New subtask", text: $newSubTaskTitle)
                .textFieldStyle(.plain)
                .foregroundColor(design == .rainbow ? .white : .primary)
                .onSubmit { addNewSubTask() }
                .focused($isSubTaskFieldFocused)
            Spacer()
            Button {
                addNewSubTask()
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
            .disabled(newSubTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onAppear {
            // Автофокус при появлении поля добавления субтаска
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSubTaskFieldFocused = true
            }
        }
    }
    
    @ViewBuilder
    private var subtaskAddForm: some View {
        if showAddSubTask {
            VStack(spacing: 12) {
                // Красивая форма ввода
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                        
                        TextField("New subtask title", text: $newSubTaskTitle)
                            .textFieldStyle(.plain)
                            .font(.subheadline)
                            .onSubmit {
                                addNewSubTask()
                            }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.tertiarySystemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue.opacity(0.4), lineWidth: 1)
                            )
                    )
                    
                    // Кнопки действий
                    VStack(spacing: 6) {
                        Button(action: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                addNewSubTask()
                            }
                        }) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.green)
                        }
                        .disabled(newSubTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .scaleEffect(newSubTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.8 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: newSubTaskTitle)
                        
                        Button(action: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                showAddSubTask = false
                                newSubTaskTitle = ""
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
//                                .background(
//                        RoundedRectangle(cornerRadius: 16)
//                            .fill(Color(UIColor.tertiarySystemBackground))
//                            .overlay(
//                                RoundedRectangle(cornerRadius: 16)
//                                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
//                            )
//                    )
            .transition(.asymmetric(
                insertion: .scale(scale: 0.9)
                    .combined(with: .opacity)
                    .combined(with: .offset(y: 20)),
                removal: .scale(scale: 0.9)
                    .combined(with: .opacity)
                    .combined(with: .offset(y: -20))
            ))
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: showAddSubTask)
        } else {
            // Красивая кнопка добавления
            Button(action: {
                hapticManager.selectionChanged()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    showAddSubTask = true
                }
            }) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    
                    Text("Add Subtask")
                        .font(.subheadline)
                        //.foregroundColor(design == .rainbow ? .white : .primary)
                        .fontWeight(.medium)
                        
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.blue.opacity(0.6))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
//                .background(
//                    RoundedRectangle(cornerRadius: 12)
//                        .fill(Color.blue.opacity(0.1))
//                        .overlay(
//                            RoundedRectangle(cornerRadius: 12)
//                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
//                        )
//                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .transition(.asymmetric(
                insertion: .scale(scale: 0.9)
                    .combined(with: .opacity)
                    .combined(with: .offset(y: 20)),
                removal: .scale(scale: 0.9)
                    .combined(with: .opacity)
                    .combined(with: .offset(y: -20))
            ))
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: showAddSubTask)
        }
    }
}
