import SwiftUI
import SwiftData

// Presentation · Vision — сегментированные списки целей/задач/привычек/мемо внутри вкладки Vision.
// Переиспользует карточки фич (`GoalCardView`, `TaskCardView`, …). Навигация между вкладками приложения — `RootCoordinator` / `AppRootTab`.
// Оглавление: цели → задачи → привычки → мемо → вспомогательные карточки/календарь.

// MARK: Сегмент «Цели» по выбранной сфере
struct GoalsForSphereView: View {
    let sphereID: UUID
    let selectedDate: Date
    @Query private var goals: [Goal]
    @Environment(\.modelContext) private var modelContext
    @State private var goalToEdit: Goal? = nil
    @State private var showAddEditSheet = false
    private let hapticManager = HapticSoundManager.shared
    @State private var showDeleteGoalConfirmation: Bool = false
    @State private var goalPendingDeletion: Goal?
    @State private var goalLeadingSwipeVisual: (id: UUID, titleCompleted: Bool)? = nil
    
    private static let goalSwipeCompleteSaveDelay: TimeInterval = 0.65
    private static let goalSwipeUncompleteSaveDelay: TimeInterval = 1.0
    
    init(sphereID: UUID, selectedDate: Date = .now) {
        self.sphereID = sphereID
        self.selectedDate = selectedDate
        self._goals = Query(filter: #Predicate<Goal> { $0.sphereID == sphereID })
    }
    
    private var goalsForDate: [Goal] {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: selectedDate)
        
        let filtered = goals.filter { goal in
            if let dueDate = goal.dueDate {
                return calendar.isDate(dueDate, inSameDayAs: normalizedDate)
            }
            return calendar.isDate(goal.creationDate, inSameDayAs: normalizedDate)
        }
        
        return filtered.sorted { g1, g2 in
            let g1IsCompleted = g1.status == .completed || g1.status == .missed
            let g2IsCompleted = g2.status == .completed || g2.status == .missed
            if g1IsCompleted != g2IsCompleted {
                return !g1IsCompleted && g2IsCompleted
            }
            if g1IsCompleted && g2IsCompleted {
                let d1 = g1.completedAt ?? g1.creationDate
                let d2 = g2.completedAt ?? g2.creationDate
                return d1 > d2
            }
            return g1.orderIndex < g2.orderIndex
        }
    }
    
    private func visualTitleCompleted(for goal: Goal) -> Bool? {
        guard let v = goalLeadingSwipeVisual, v.id == goal.id else { return nil }
        return v.titleCompleted
    }
    
    var body: some View {
        Group {
            if goalsForDate.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "target")
                        .font(.largeTitle)
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No goals found for this day")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
        } else {
                List {
                    ForEach(goalsForDate) { goal in
                    GoalCardView(goal: goal, goalDesign: .basic, visualTitleCompleted: visualTitleCompleted(for: goal)) {
                        goalToEdit = goal
                        showAddEditSheet = true
                        }
                        .frame(maxWidth: .infinity, minHeight: 72)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 1)
                        .background(Color.clear)
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            leadingSwipeButton(for: goal)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            trailingSwipeButtons(for: goal)
                        }
                    }
                    .onMove(perform: moveGoalsInSphere)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .animation(.smooth(duration: 0.4), value: goalsForDate.map { "\($0.id)-\($0.status.rawValue)" })
            }
        }
            .sheet(isPresented: $showAddEditSheet) {
                EditGoalView(goalToEdit: $goalToEdit, allGoalsCount: goals.count)
        }
        .frostedDeleteConfirmation(
            isPresented: $showDeleteGoalConfirmation,
            title: "Delete goal?",
            message: "This goal will be permanently deleted.",
            onConfirm: {
                if let goal = goalPendingDeletion {
                    deleteGoal(goal)
                    goalPendingDeletion = nil
                }
            }
        )
    }
    
    private func applyGoalLeadingSwipeSave(goal: Goal, from oldStatus: Goal.Status, to newStatus: Goal.Status) {
        guard goalLeadingSwipeVisual?.id == goal.id else { return }
        Goal.adjustSphereSatisfaction(goal: goal, oldStatus: oldStatus, newStatus: newStatus, modelContext: modelContext)
        goal.updateStatus(to: newStatus)
        if newStatus == .completed { hapticManager.completionSuccess() } else { hapticManager.actionUndone() }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            try? modelContext.save()
            NotificationCenter.default.postAppEvent(.goalStatusDidChange)
        }
        goalLeadingSwipeVisual = nil
    }
    
    @ViewBuilder
    private func leadingSwipeButton(for goal: Goal) -> some View {
        let status = goal.status
        let isUndo = status == .completed || status == .missed || status == .archived
        Button {
            guard goalLeadingSwipeVisual == nil else { return }
            hapticManager.selectionChanged()
            let newStatus: Goal.Status = isUndo ? .pending : .completed
            let capturedOld = status
            if isUndo {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    goalLeadingSwipeVisual = (goal.id, false)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + Self.goalSwipeUncompleteSaveDelay) {
                    applyGoalLeadingSwipeSave(goal: goal, from: capturedOld, to: newStatus)
                }
            } else {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    goalLeadingSwipeVisual = (goal.id, true)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + Self.goalSwipeCompleteSaveDelay) {
                    applyGoalLeadingSwipeSave(goal: goal, from: capturedOld, to: newStatus)
                }
            }
        } label: {
            Image(systemName: isUndo ? "arrow.uturn.backward" : "checkmark")
        }
        .tint(isUndo ? .orange : .green)
    }
    
    @ViewBuilder
    private func trailingSwipeButtons(for goal: Goal) -> some View {
        let status = goal.status
        if status == .completed || status == .missed {
            // Unmark button
            Button {
                hapticManager.playHaptic(style: .light)
                withAnimation(.smooth(duration: 0.4)) {
                    Goal.adjustSphereSatisfaction(goal: goal, oldStatus: status, newStatus: .pending, modelContext: modelContext)
                    goal.updateStatus(to: .pending)
                    hapticManager.actionUndone()
                    try? modelContext.save()
                    NotificationCenter.default.postAppEvent(.goalStatusDidChange)
                }
            } label: {
                Image(systemName: "arrow.uturn.backward.circle.fill")
            }
            .tint(.orange)
            // Archive button
            Button {
                hapticManager.selectionChanged()
                withAnimation(.smooth(duration: 0.4)) {
                    goal.updateStatus(to: .archived)
                    try? modelContext.save()
                    NotificationCenter.default.postAppEvent(.goalStatusDidChange)
                }
            } label: {
                Image(systemName: "archivebox")
            }
            .tint(.gray)
            // Delete button
            Button(role: .destructive) {
                goalPendingDeletion = goal
                showDeleteGoalConfirmation = true
            } label: {
                Image(systemName: "trash")
            }
            .tint(.red)
        } else if status == .archived {
            Button {
                hapticManager.selectionChanged()
                withAnimation(.smooth(duration: 0.4)) {
                    goal.updateStatus(to: .pending)
                    try? modelContext.save()
                    NotificationCenter.default.postAppEvent(.goalStatusDidChange)
                }
            } label: {
                Image(systemName: "archivebox.fill")
            }
            .tint(Color(UIColor.systemGray))
            
            Button(role: .destructive) {
                goalPendingDeletion = goal
                showDeleteGoalConfirmation = true
            } label: {
                Image(systemName: "trash")
            }
            .tint(.red)
        } else {
            Button {
                hapticManager.selectionChanged()
                withAnimation(.smooth(duration: 0.4)) {
                    goal.updateStatus(to: .archived)
                    try? modelContext.save()
                    NotificationCenter.default.postAppEvent(.goalStatusDidChange)
                }
            } label: {
                Image(systemName: "archivebox")
            }
            .tint(.gray)
            
            Button(role: .destructive) {
                goalPendingDeletion = goal
                showDeleteGoalConfirmation = true
            } label: {
                Image(systemName: "trash")
            }
            .tint(.red)
        }
    }

    private func deleteGoal(_ goal: Goal) {
        modelContext.delete(goal)
        try? modelContext.save()
    }
    
    private func moveGoalsInSphere(from source: IndexSet, to destination: Int) {
        hapticManager.playHaptic(style: .medium)
        var reordered = goalsForDate
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, goal) in reordered.enumerated() {
            goal.orderIndex = index
        }
        try? modelContext.save()
        NotificationCenter.default.postAppEvent(.goalStatusDidChange)
    }
}

// MARK: Сегмент «Задачи» по сфере
struct TasksForSphereView: View {
    let sphereID: UUID
    let selectedDate: Date
    @Query private var tasks: [SuperTask]
    @Environment(\.modelContext) private var modelContext
    @State private var taskToEdit: SuperTask? = nil
    @State private var showEditTaskSheet = false
    
    init(sphereID: UUID, selectedDate: Date = .now) {
        self.sphereID = sphereID
        self.selectedDate = selectedDate
        self._tasks = Query(filter: #Predicate<SuperTask> { $0.sphereID == sphereID })
    }
    
    private var tasksForDate: [SuperTask] {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: selectedDate)
        
        let filtered = tasks.filter { task in
            if let dueDate = task.dueDate {
                return calendar.isDate(dueDate, inSameDayAs: normalizedDate)
            }
            return calendar.isDate(task.creationDate, inSameDayAs: normalizedDate) ||
                   calendar.isDate(task.lastModifiedDate, inSameDayAs: normalizedDate)
        }
        
        return filtered.filter { task in
            task.statusEnum != .completed && task.statusEnum != .archived
        }.sorted { t1, t2 in
            t1.orderIndex < t2.orderIndex
        }
    }
    
    var body: some View {
        Group {
            if tasksForDate.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .font(.largeTitle)
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No tasks found for this day")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
        } else {
                List {
                    ForEach(tasksForDate) { task in
                    TaskCardView(
                        task: task,
                        onEdit: {
                            taskToEdit = task
                            showEditTaskSheet = true
                        },
                        onRequestDelete: { _ in
                            // Deletion confirmations are handled in the Tasks tab.
                        },
                        onRequestArchive: { _ in
                            // Archiving confirmations are handled in the Tasks tab.
                        }
                    )
                        .frame(maxWidth: .infinity, minHeight: 72)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 1)
                        .background(Color.clear)
                    }
                    .onMove(perform: moveTasksInSphere)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
        }
            .sheet(isPresented: $showEditTaskSheet) {
                AddEditTaskView(taskToEdit: $taskToEdit, allTasksCount: tasks.count)
            }
    }
    
    private func moveTasksInSphere(from source: IndexSet, to destination: Int) {
        HapticSoundManager.shared.playHaptic(style: .medium)
        var reordered = tasksForDate
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, task) in reordered.enumerated() {
            task.orderIndex = index
        }
        try? modelContext.save()
        NotificationCenter.default.postAppEvent(.taskStatusDidChange)
    }
}

// MARK: Сегмент «Привычки» по сфере
struct HabitsForSphereView: View {
    let sphereID: UUID
    let selectedDate: Date
    @Query private var habits: [Habit]
    @Environment(\.modelContext) private var modelContext
    @State private var habitToEdit: Habit? = nil
    @State private var showEditHabitSheet = false
    
    init(sphereID: UUID, selectedDate: Date = .now) {
        self.sphereID = sphereID
        self.selectedDate = selectedDate
        self._habits = Query(filter: #Predicate<Habit> { $0.sphereID == sphereID })
    }
    
    private var scheduledHabits: [Habit] {
        let scheduled = habits.filter { !$0.isArchived && HabitLogicService(habit: $0).isScheduled(on: selectedDate) }
        let activeToday = scheduled.filter { habit in
            let status = habit.completionStatus(on: selectedDate)
            return status == .activeHabit || status == .partialHabit
        }
        
        print("🔍 HabitsForSphereView Debug:")
        print("  Selected Date: \(selectedDate)")
        print("  Sphere ID: \(sphereID)")
        print("  Total habits for sphere: \(habits.count)")
        print("  Scheduled habits: \(scheduled.count)")
        print("  Visible active habits: \(activeToday.count)")
        return activeToday
    }
    
    var body: some View {
        Group {
        if scheduledHabits.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "repeat.circle")
                        .font(.largeTitle)
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No habits found for this day")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
        } else {
                List {
                ForEach(scheduledHabits) { habit in
                    HabitCardView(habit: habit, date: selectedDate, design: .basic, isFutureDate: selectedDate > Date(), onDoubleTap: {
                        habitToEdit = habit
                        showEditHabitSheet = true
                    }, isInSegmented: true)
                        .frame(maxWidth: .infinity, minHeight: 72)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 1)
                        .background(Color.clear)
                    }
                    .onMove(perform: moveHabitsInSphere)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }.sheet(isPresented: $showEditHabitSheet) {
                EditHabitView(modelContext: modelContext, habitToEdit: $habitToEdit, allHabitsCount: habits.count, ruleEffectiveDate: selectedDate)
        }
    }
    
    private func moveHabitsInSphere(from source: IndexSet, to destination: Int) {
        HapticSoundManager.shared.playHaptic(style: .medium)
        var reordered = scheduledHabits
        reordered.move(fromOffsets: source, toOffset: destination)
        let allHabitsDict = Dictionary(uniqueKeysWithValues: habits.map { ($0.id, $0) })
        var newOrderIDs: [UUID] = reordered.map { $0.id }
        let scheduledIDs: Set<UUID> = Set(reordered.map { $0.id })
        for habit in habits.sorted(by: { $0.orderIndex < $1.orderIndex }) where !scheduledIDs.contains(habit.id) {
            newOrderIDs.append(habit.id)
        }
        for (index, habitID) in newOrderIDs.enumerated() {
            allHabitsDict[habitID]?.orderIndex = index
        }
        try? modelContext.save()
        NotificationCenter.default.postAppEvent(.habitStatusDidChange)
    }
}

// MARK: Сегмент «Мемо» по сфере
struct MemoForSphereView: View {
    let sphereID: UUID
    let selectedDate: Date
    @Query private var memoItems: [MemoItem]
    @Environment(\.modelContext) private var modelContext
    @Query private var appDesignSettings: [AppDesignSettings]
    
    @State private var memoToEdit: MemoItem? = nil
    @State private var viewerItem: MemoItem? = nil
    @State private var showAddEditSheet: Bool = false
    
    // States for detail views
    @State private var isReorderMode = false
    @State private var showCompleted = true
    @State private var showListStatistics = true
    @State private var isNoteAlbumReorderMode = false
    @State private var showNoteAlbumStatistics = true
    @State private var showArchivedNotes = false
    @State private var triggerAddNoteForAlbum = false
    @State private var triggerAddListItemForList = false
    @State private var showCounterStatistics = false
    @State private var showStreakStatistics = false
    @State private var showSkillStatistics = false
    @State private var showBudgetStatistics = false
    @State private var showTimeStatistics = false
    @State private var showHealthStatistics = false
    @State private var showMoodStatistics = false
    @State private var showCalendarStatistics = false
    @State private var showDeleteMemoConfirmation = false
    @State private var memoPendingDeletion: MemoItem?

    private var design: AppDesign { appDesignSettings.first?.design ?? .basic }
    
    init(sphereID: UUID, selectedDate: Date = .now) {
        self.sphereID = sphereID
        self.selectedDate = selectedDate
        self._memoItems = Query(sort: \MemoItem.creationDate, order: .reverse)
    }
    
    private var memoWithActivityOnDate: [MemoItem] {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: selectedDate)
        
        return memoItems.filter { memo in
            guard memo.status == .active else { return false }
            guard let data = memo.contentData else { return false }
            
            switch memo.itemType {
            case .counter:
                if let content = try? JSONDecoder().decode(MemoCounterContent.self, from: data) {
                    let isInSphere = content.sphereID == sphereID ||
                                   content.additionalImpacts.contains(where: { $0.sphereID == sphereID })
                    let hasActivity = content.history.contains { (entry: MemoCounterContent.CounterEntry) in
                        calendar.isDate(entry.date, inSameDayAs: normalizedDate)
                    }
                    return isInSphere && hasActivity
                }
            case .streak:
                if let content = try? JSONDecoder().decode(MemoStreakContent.self, from: data) {
                    let isInSphere = content.sphereID == sphereID ||
                                   content.additionalImpacts.contains(where: { $0.sphereID == sphereID })
                    let hasActivity = content.checkHistory.contains { (entry: MemoStreakContent.StreakCheckEntry) in
                        calendar.isDate(entry.date, inSameDayAs: normalizedDate)
                    }
                    return isInSphere && hasActivity
                }
            case .mood:
                if let content = try? JSONDecoder().decode(MemoMoodContent.self, from: data) {
                    return content.entries.contains { (entry: MemoMoodContent.MoodEntry) in
                        calendar.isDate(entry.date, inSameDayAs: normalizedDate)
                    }
                }
            case .health:
                if let content = try? JSONDecoder().decode(MemoHealthContent.self, from: data) {
                    return content.entries.contains { (entry: MemoHealthContent.HealthEntry) in
                        calendar.isDate(entry.date, inSameDayAs: normalizedDate)
                    }
                }
            case .skill:
                if let content = try? JSONDecoder().decode(MemoSkillContent.self, from: data) {
                    return content.skills.contains { (skill: MemoSkillContent.SkillItem) in
                        skill.history.contains { (entry: MemoSkillContent.SkillItem.SkillEntry) in
                            calendar.isDate(entry.date, inSameDayAs: normalizedDate)
                        }
                    }
                }
            case .budget:
                if let content = try? JSONDecoder().decode(MemoBudgetContent.self, from: data) {
                    return content.budgets.contains { (budget: MemoBudgetContent.BudgetItem) in
                        budget.transactions.contains { (transaction: MemoBudgetContent.BudgetItem.BudgetTransaction) in
                            calendar.isDate(transaction.date, inSameDayAs: normalizedDate)
                        }
                    }
                }
            case .time:
                if let content = try? JSONDecoder().decode(MemoTimeContent.self, from: data) {
                    return content.entries.contains { (entry: MemoTimeContent.TimeEntry) in
                        calendar.isDate(entry.date, inSameDayAs: normalizedDate)
                    }
                }
            case .noteAlbum:
                if let content = try? JSONDecoder().decode(MemoNoteAlbumContent.self, from: data) {
                    return content.notes.contains { (note: MemoNoteAlbumContent.NoteItem) in
                        calendar.isDate(note.lastModified, inSameDayAs: normalizedDate)
                    }
                }
            case .list:
                return false
            case .calendar:
                if let content = try? JSONDecoder().decode(MemoCalendarContent.self, from: data) {
                    if content.sphereID == nil { return true }
                    if content.sphereID == sphereID { return true }
                    if content.additionalImpacts.contains(where: { $0.sphereID == sphereID }) { return true }
                    return false
                }
            }
            
            return false
        }
    }
    
    private func noteAlbumDisplayTitle(_ title: String) -> String {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty || t == "Мои заметки" || t == "Альбом заметок" { return "My notes" }
        return title
    }

    private func incrementCounterByStep(_ item: MemoItem) {
        guard var content = (item.contentData.flatMap { try? JSONDecoder().decode(MemoCounterContent.self, from: $0) }) else { return }
        let step = max(1, content.stepValue)
        let newValue = content.currentValue + step
        content.currentValue = newValue
        content.history.append(MemoCounterContent.CounterEntry(date: Date(), value: newValue, note: ""))
        if let data = try? JSONEncoder().encode(content) {
            item.contentData = data
            try? modelContext.save()
        }
    }

    private func decrementCounterByStep(_ item: MemoItem) {
        guard var content = (item.contentData.flatMap { try? JSONDecoder().decode(MemoCounterContent.self, from: $0) }) else { return }
        let step = max(1, content.stepValue)
        let newValue = max(0, content.currentValue - step)
        content.currentValue = newValue
        content.history.append(MemoCounterContent.CounterEntry(date: Date(), value: newValue, note: ""))
        if let data = try? JSONEncoder().encode(content) {
            item.contentData = data
            try? modelContext.save()
        }
    }

    @ViewBuilder
    private func leadingSwipeButton(for item: MemoItem) -> some View {
        switch item.itemType {
        case .noteAlbum:
            HStack {
                Button {
                    viewerItem = item
                    triggerAddNoteForAlbum = true
                } label: { Image(systemName: "checkmark") }
                .tint(.green)
            }
        case .counter:
            HStack {
                Button {
                    incrementCounterByStep(item)
                } label: { Image(systemName: "checkmark") }
                .tint(.green)

                Button {
                    decrementCounterByStep(item)
                } label: { Image(systemName: "arrow.uturn.left") }
                .tint(.gray)
            }
        case .list:
            HStack {
                Button {
                    viewerItem = item
                    triggerAddListItemForList = true
                } label: { Image(systemName: "checkmark") }
                .tint(.green)
            }
        case .health:
            HStack {
                Button {
                    incrementHealthByStep(item)
                } label: { Image(systemName: "checkmark") }
                .tint(.green)

                Button {
                    decrementHealthByStep(item)
                } label: { Image(systemName: "arrow.uturn.left") }
                .tint(.gray)
            }
        case .skill:
            HStack {
                Button {
                    incrementSkillByStep(item)
                } label: { Image(systemName: "checkmark") }
                .tint(.green)

                Button {
                    decrementSkillByStep(item)
                } label: { Image(systemName: "arrow.uturn.left") }
                .tint(.gray)
            }
        case .budget:
            HStack {
                Button {
                    addBudgetStep(item)
                } label: { Image(systemName: "checkmark") }
                .tint(.green)

                Button {
                    subtractBudgetStep(item)
                } label: { Image(systemName: "arrow.uturn.left") }
                .tint(.gray)
            }
        case .time:
            HStack {
                Button {
                    addTimeStep(item)
                } label: { Image(systemName: "checkmark") }
                .tint(.green)

                Button {
                    subtractTimeStep(item)
                } label: { Image(systemName: "arrow.uturn.left") }
                .tint(.gray)
            }
        case .mood:
            Button {
                viewerItem = item
            } label: { Image(systemName: "face.smiling") }
            .tint(.green)
        case .streak:
            if hasStreakOnSelectedDate(for: item) {
                Button {
                    toggleStreakForSelectedDate(item)
                } label: { Image(systemName: "arrow.uturn.backward") }
                .tint(Color(UIColor.systemGray))
            } else {
                Button {
                    toggleStreakForSelectedDate(item)
                } label: { Image(systemName: "flame.fill") }
                .tint(.green)
            }
        case .calendar:
            Button {
                viewerItem = item
            } label: { Image(systemName: "plus.circle") }
            .tint(.green)
        }
    }

    private func incrementHealthByStep(_ item: MemoItem) {
        guard var content = (item.contentData.flatMap { try? JSONDecoder().decode(MemoHealthContent.self, from: $0) }) else { return }
        let step = max(0.1, content.stepValue)
        let newValue = content.currentValue + step
        content.currentValue = newValue
        content.entries.append(MemoHealthContent.HealthEntry(date: Date(), value: step, note: ""))
        if let data = try? JSONEncoder().encode(content) {
            item.contentData = data
            try? modelContext.save()
        }
    }

    private func decrementHealthByStep(_ item: MemoItem) {
        guard var content = (item.contentData.flatMap { try? JSONDecoder().decode(MemoHealthContent.self, from: $0) }) else { return }
        let step = max(0.1, content.stepValue)
        let newValue = max(0, content.currentValue - step)
        let delta = newValue - content.currentValue
        content.currentValue = newValue
        content.entries.append(MemoHealthContent.HealthEntry(date: Date(), value: delta, note: ""))
        if let data = try? JSONEncoder().encode(content) {
            item.contentData = data
            try? modelContext.save()
        }
    }

    private func incrementSkillByStep(_ item: MemoItem) {
        guard var content = (item.contentData.flatMap { try? JSONDecoder().decode(MemoSkillContent.self, from: $0) }) else { return }
        guard var skill = content.skills.first else { return }
        let step = max(0.1, content.stepValue)
        let maxLevel = Double(max(1, content.scale))
        let newLevel = min(skill.currentLevel + step, maxLevel)
        skill.currentLevel = newLevel
        skill.history.append(MemoSkillContent.SkillItem.SkillEntry(date: Date(), level: newLevel, note: ""))
        content.skills[0] = skill
        if let data = try? JSONEncoder().encode(content) {
            item.contentData = data
            try? modelContext.save()
        }
    }

    private func decrementSkillByStep(_ item: MemoItem) {
        guard var content = (item.contentData.flatMap { try? JSONDecoder().decode(MemoSkillContent.self, from: $0) }) else { return }
        guard var skill = content.skills.first else { return }
        let step = max(0.1, content.stepValue)
        let minLevel: Double = 0
        let newLevel = max(minLevel, skill.currentLevel - step)
        skill.currentLevel = newLevel
        skill.history.append(MemoSkillContent.SkillItem.SkillEntry(date: Date(), level: newLevel, note: ""))
        content.skills[0] = skill
        if let data = try? JSONEncoder().encode(content) {
            item.contentData = data
            try? modelContext.save()
        }
    }

    private func addBudgetStep(_ item: MemoItem) {
        guard var content = (item.contentData.flatMap { try? JSONDecoder().decode(MemoBudgetContent.self, from: $0) }) else { return }
        guard var budget = content.budgets.first else { return }
        let step = content.stepValue
        budget.currentBalance += step
        budget.transactions.append(MemoBudgetContent.BudgetItem.BudgetTransaction(date: Date(), amount: step, note: ""))
        content.budgets[0] = budget
        if let data = try? JSONEncoder().encode(content) {
            item.contentData = data
            try? modelContext.save()
        }
    }

    private func subtractBudgetStep(_ item: MemoItem) {
        guard var content = (item.contentData.flatMap { try? JSONDecoder().decode(MemoBudgetContent.self, from: $0) }) else { return }
        guard var budget = content.budgets.first else { return }
        let step = content.stepValue
        budget.currentBalance -= step
        budget.transactions.append(MemoBudgetContent.BudgetItem.BudgetTransaction(date: Date(), amount: -step, note: ""))
        content.budgets[0] = budget
        if let data = try? JSONEncoder().encode(content) {
            item.contentData = data
            try? modelContext.save()
        }
    }

    private func addTimeStep(_ item: MemoItem) {
        guard var content = (item.contentData.flatMap { try? JSONDecoder().decode(MemoTimeContent.self, from: $0) }) else { return }
        let step = max(1, content.stepMinutes)
        content.currentMinutes += step
        content.entries.append(MemoTimeContent.TimeEntry(date: Date(), minutes: step, note: ""))
        if let data = try? JSONEncoder().encode(content) {
            item.contentData = data
            try? modelContext.save()
        }
    }

    private func subtractTimeStep(_ item: MemoItem) {
        guard var content = (item.contentData.flatMap { try? JSONDecoder().decode(MemoTimeContent.self, from: $0) }) else { return }
        let step = max(1, content.stepMinutes)
        let newValue = max(0, content.currentMinutes - step)
        let delta = newValue - content.currentMinutes
        content.currentMinutes = newValue
        content.entries.append(MemoTimeContent.TimeEntry(date: Date(), minutes: delta, note: ""))
        if let data = try? JSONEncoder().encode(content) {
            item.contentData = data
            try? modelContext.save()
        }
    }

    private func hasStreakOnSelectedDate(for item: MemoItem) -> Bool {
        guard let content = (item.contentData.flatMap { try? JSONDecoder().decode(MemoStreakContent.self, from: $0) }) else { return false }
        let day = Calendar.current.startOfDay(for: selectedDate)
        return content.checkHistory.contains { Calendar.current.isDate($0.date, inSameDayAs: day) }
    }

    private func toggleStreakForSelectedDate(_ item: MemoItem) {
        guard var content = (item.contentData.flatMap { try? JSONDecoder().decode(MemoStreakContent.self, from: $0) }) else { return }
        let day = Calendar.current.startOfDay(for: selectedDate)
        let hasDay = content.checkHistory.contains { Calendar.current.isDate($0.date, inSameDayAs: day) }
        if hasDay {
            content.checkHistory.removeAll { Calendar.current.isDate($0.date, inSameDayAs: day) }
        } else {
            content.checkHistory.append(MemoStreakContent.StreakCheckEntry(date: day, note: ""))
        }
        let (current, best) = MemoStreakContent.recalculateStreakValues(history: content.checkHistory, existingBest: content.bestStreak)
        content.currentStreak = current
        content.bestStreak = best
        if let data = try? JSONEncoder().encode(content) {
            item.contentData = data
            try? modelContext.save()
            NotificationCenter.default.postAppEvent(.memoStatusDidChange)
        }
    }
    
    var body: some View {
        Group {
            if memoWithActivityOnDate.isEmpty {
        VStack(spacing: 12) {
                    Image(systemName: "heart.circle")
                        .font(.largeTitle)
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    Text("No memo found for this day")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List {
                    ForEach(memoWithActivityOnDate, id: \.id) { memo in
                        MemoCardView(
                            memoItem: memo,
                            design: design,
                            streakReferenceDate: selectedDate,
                            onDoubleTap: { viewerItem = memo }
                        )
                        .frame(maxWidth: .infinity, minHeight: 72)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 1)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            // Archive / Unarchive
                            Button {
                                memo.status = memo.status == .archived ? .active : .archived
                                try? modelContext.save()
                                NotificationCenter.default.postAppEvent(.memoStatusDidChange)
                            } label: {
                                Image(systemName: memo.status == .archived ? "tray.and.arrow.up" : "archivebox")
                            }
                            .tint(Color(UIColor.systemGray))
                            
                            // Delete
                            Button(role: .destructive) {
                                memoPendingDeletion = memo
                                showDeleteMemoConfirmation = true
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            leadingSwipeButton(for: memo)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .contentMargins(.top, 0, for: .scrollContent)
                .listSectionSpacing(0)
                .background(Color.clear)
            }
        }
        .fullScreenCover(item: $viewerItem) { item in
            NavigationStack {
                memoDetailView(for: item)
            }
        }
        .onChange(of: showAddEditSheet) { oldValue, newValue in
            if !newValue {
                // Завершили редактирование — сбрасываем состояния и закрываем viewer
                memoToEdit = nil
                viewerItem = nil
            }
        }
        .sheet(isPresented: $showAddEditSheet) {
            if let memo = memoToEdit {
                EditMemoView(memoToEdit: $memoToEdit, memoType: memo.itemType)
                    .id("edit-\(memo.id)")
            }
        }
        .frostedDeleteConfirmation(
            isPresented: $showDeleteMemoConfirmation,
            title: "Delete memo?",
            message: "This memo and its data will be permanently deleted.",
            onConfirm: {
                if let memo = memoPendingDeletion {
                    deleteMemo(memo)
                    memoPendingDeletion = nil
                }
            }
        )
    }

    private func deleteMemo(_ memo: MemoItem) {
        modelContext.delete(memo)
        try? modelContext.save()
    }
    
    // MARK: - Memo Detail View
    @ViewBuilder
    private func memoDetailView(for item: MemoItem) -> some View {
        if item.itemType == .list {
            ListContentView(item: item, isReorderMode: $isReorderMode, showCompleted: $showCompleted, showListStatistics: $showListStatistics, triggerAddListItem: $triggerAddListItemForList)
                .navigationTitle(item.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            viewerItem = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.body.weight(.semibold))
                                .foregroundColor(.primary)
                        }
                    }
                    
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack(spacing: 12) {
                            Button {
                                withAnimation {
                                    isReorderMode.toggle()
                                }
                            } label: {
                                Image(systemName: isReorderMode ? "checkmark" : "arrow.up.arrow.down")
                                    .font(.body.weight(.semibold))
                            }
                            
                            Menu {
                                Button {
                                    withAnimation {
                                        showListStatistics.toggle()
                                    }
                                } label: {
                                    Label(showListStatistics ? "Hide statistics" : "Show statistics",
                                          systemImage: showListStatistics ? "chart.bar.fill" : "chart.bar")
                                }
                                
                                Button {
                                    withAnimation {
                                        showCompleted.toggle()
                                    }
                                } label: {
                                    Label(showCompleted ? "Hide completed" : "Show completed",
                                          systemImage: showCompleted ? "eye.slash" : "eye")
                                }
                                
                                Divider()
                                
                                Button {
                                    memoToEdit = item
                                    showAddEditSheet = true
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                
                                Button(role: .destructive) {
                                    modelContext.delete(item)
                                    try? modelContext.save()
                                    viewerItem = nil
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.title3)
                            }
                        }
                    }
                }
        } else if item.itemType == .noteAlbum {
            NoteAlbumContentView(item: item, isReorderMode: $isNoteAlbumReorderMode, showNoteAlbumStatistics: $showNoteAlbumStatistics, showArchivedNotes: $showArchivedNotes, triggerAddNote: $triggerAddNoteForAlbum)
                .navigationTitle(noteAlbumDisplayTitle(item.title))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            viewerItem = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.body.weight(.semibold))
                                .foregroundColor(.primary)
                        }
                    }
                    
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack(spacing: 12) {
                            Button {
                                withAnimation {
                                    isNoteAlbumReorderMode.toggle()
                                }
                            } label: {
                                Image(systemName: isNoteAlbumReorderMode ? "checkmark" : "arrow.up.arrow.down")
                                    .font(.body.weight(.semibold))
                            }
                            
                            Menu {
                            Button {
                                withAnimation {
                                    showNoteAlbumStatistics.toggle()
                                }
                            } label: {
                                Label(showNoteAlbumStatistics ? "Hide statistics" : "Show statistics",
                                      systemImage: showNoteAlbumStatistics ? "chart.bar.fill" : "chart.bar")
                            }
                            
                            Button {
                                withAnimation {
                                    showArchivedNotes.toggle()
                                }
                            } label: {
                                Label(showArchivedNotes ? "Hide archived" : "Show archived",
                                      systemImage: showArchivedNotes ? "archivebox.fill" : "archivebox")
                            }
                            
                            Divider()
                            
                            Button {
                                memoToEdit = item
                                showAddEditSheet = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            
                            Button(role: .destructive) {
                                modelContext.delete(item)
                                try? modelContext.save()
                                viewerItem = nil
                            } label: {
                                Image(systemName: "trash")
                            }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.title3)
                            }
                        }
                    }
                }
        } else if item.itemType == .counter {
            CounterContentView(item: item, showCounterStatistics: $showCounterStatistics)
                .navigationTitle(item.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            viewerItem = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.body.weight(.semibold))
                                .foregroundColor(.primary)
                        }
                    }
                    
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                withAnimation {
                                    showCounterStatistics.toggle()
                                }
                            } label: {
                                Label(showCounterStatistics ? "Hide statistics" : "Show statistics",
                                      systemImage: showCounterStatistics ? "chart.bar.fill" : "chart.bar")
                            }
                            
                            Divider()
                            
                            Button {
                                memoToEdit = item
                                showAddEditSheet = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            
                            Divider()
                            
                            Button(role: .destructive) {
                                modelContext.delete(item)
                                try? modelContext.save()
                                viewerItem = nil
                            } label: {
                                Image(systemName: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                        }
                    }
                }
        } else if item.itemType == .streak {
            StreakContentView(item: item, showStreakStatistics: $showStreakStatistics)
                .navigationTitle(item.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            viewerItem = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.body.weight(.semibold))
                                .foregroundColor(.primary)
                        }
                    }
                    
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                withAnimation {
                                    showStreakStatistics.toggle()
                                }
                            } label: {
                                Label(showStreakStatistics ? "Hide statistics" : "Show statistics",
                                      systemImage: showStreakStatistics ? "chart.bar.fill" : "chart.bar")
                            }
                            
                            Divider()
                            
                            Button {
                                memoToEdit = item
                                showAddEditSheet = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            
                            Divider()
                            
                            Button(role: .destructive) {
                                modelContext.delete(item)
                                try? modelContext.save()
                                viewerItem = nil
                            } label: {
                                Image(systemName: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                        }
                    }
                }
        } else if item.itemType == .skill {
            SkillContentView(item: item, showSkillStatistics: $showSkillStatistics)
                .navigationTitle(item.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            viewerItem = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.body.weight(.semibold))
                                .foregroundColor(.primary)
                        }
                    }
                    
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                withAnimation {
                                    showSkillStatistics.toggle()
                                }
                            } label: {
                                Label(showSkillStatistics ? "Hide statistics" : "Show statistics",
                                      systemImage: showSkillStatistics ? "chart.bar.fill" : "chart.bar")
                            }
                            
                            Divider()
                            
                            Button {
                                memoToEdit = item
                                showAddEditSheet = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            
                            Divider()
                            
                            Button(role: .destructive) {
                                modelContext.delete(item)
                                try? modelContext.save()
                                viewerItem = nil
                            } label: {
                                Image(systemName: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                        }
                    }
                }
        } else if item.itemType == .budget {
            BudgetContentView(item: item, showBudgetStatistics: $showBudgetStatistics)
                .navigationTitle(item.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            viewerItem = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.body.weight(.semibold))
                                .foregroundColor(.primary)
                        }
                    }
                    
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                withAnimation {
                                    showBudgetStatistics.toggle()
                                }
                            } label: {
                                Label(showBudgetStatistics ? "Hide statistics" : "Show statistics",
                                      systemImage: showBudgetStatistics ? "chart.bar.fill" : "chart.bar")
                            }
                            
                            Divider()
                            
                            Button {
                                memoToEdit = item
                                showAddEditSheet = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            
                            Divider()
                            
                            Button(role: .destructive) {
                                modelContext.delete(item)
                                try? modelContext.save()
                                viewerItem = nil
                            } label: {
                                Image(systemName: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                        }
                    }
                }
        } else if item.itemType == .mood {
            MoodContentView(item: item, showMoodStatistics: $showMoodStatistics)
                .navigationTitle(item.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            viewerItem = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.body.weight(.semibold))
                                .foregroundColor(.primary)
                        }
                    }
                    
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                withAnimation {
                                    showMoodStatistics.toggle()
                                }
                            } label: {
                                Label(showMoodStatistics ? "Hide statistics" : "Show statistics",
                                      systemImage: showMoodStatistics ? "chart.bar.fill" : "chart.bar")
                            }
                            
                            Divider()
                            
                            Button {
                                memoToEdit = item
                                showAddEditSheet = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            
                            Divider()
                            
                            Button(role: .destructive) {
                                modelContext.delete(item)
                                try? modelContext.save()
                                viewerItem = nil
                            } label: {
                                Image(systemName: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                        }
                    }
                }
        } else if item.itemType == .time {
            TimeContentView(item: item, showTimeStatistics: $showTimeStatistics)
                .navigationTitle(item.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            viewerItem = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.body.weight(.semibold))
                                .foregroundColor(.primary)
                        }
                    }
                    
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                withAnimation {
                                    showTimeStatistics.toggle()
                                }
                            } label: {
                                Label(showTimeStatistics ? "Hide statistics" : "Show statistics",
                                      systemImage: showTimeStatistics ? "chart.bar.fill" : "chart.bar")
                            }
                            
                            Divider()
                            
                            Button {
                                memoToEdit = item
                                showAddEditSheet = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            
                            Divider()
                            
                            Button(role: .destructive) {
                                modelContext.delete(item)
                                try? modelContext.save()
                                viewerItem = nil
                            } label: {
                                Image(systemName: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                        }
                    }
                }
        } else if item.itemType == .health {
            HealthContentView(item: item, showHealthStatistics: $showHealthStatistics)
                .navigationTitle(item.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            viewerItem = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.body.weight(.semibold))
                                .foregroundColor(.primary)
                        }
                    }
                    
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                withAnimation {
                                    showHealthStatistics.toggle()
                                }
                            } label: {
                                Label(showHealthStatistics ? "Hide statistics" : "Show statistics",
                                      systemImage: showHealthStatistics ? "chart.bar.fill" : "chart.bar")
                            }
                            
                            Divider()
                            
                            Button {
                                memoToEdit = item
                                showAddEditSheet = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            
                            Divider()
                            
                            Button(role: .destructive) {
                                modelContext.delete(item)
                                try? modelContext.save()
                                viewerItem = nil
                            } label: {
                                Image(systemName: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                        }
                    }
                }
        } else if item.itemType == .calendar {
            CalendarContentView(item: item)
                .navigationTitle(item.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            viewerItem = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.body.weight(.semibold))
                                .foregroundColor(.primary)
                        }
                    }
                    
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                showCalendarStatistics = true
                            } label: {
                                Label("Statistics", systemImage: "chart.bar")
                            }
                            
                            Divider()
                            
                            Button {
                                memoToEdit = item
                                showAddEditSheet = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            
                            Divider()
                            
                            Button(role: .destructive) {
                                modelContext.delete(item)
                                try? modelContext.save()
                                viewerItem = nil
                            } label: {
                                Image(systemName: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                        }
                    }
                }
                .fullScreenCover(isPresented: $showCalendarStatistics) {
                    CalendarMemoStatisticsView(item: item)
                }
        } else {
            // Fallback for unknown types (should not happen)
            Text("Unknown memo type")
                .navigationTitle(item.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            viewerItem = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.body.weight(.semibold))
                                .foregroundColor(.primary)
                        }
                    }
                }
        }
    }
}

// MARK: Карточка мемо внутри сегмента Vision
struct MemoItemCard: View {
    let memo: MemoItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: memo.itemType.iconName)
                    .font(.caption)
                    .foregroundColor(memo.itemType.color)
                
                Text(memo.itemType.displayName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            Text(memo.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(8)
        .frame(width: 120, height: 60)
        .background(memo.itemType.color.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(memo.itemType.color.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: Объединённая модель пункта для календаря Vision (цель / задача / привычка / мемо)
enum CalendarItem: Identifiable {
    case goal(Goal)
    case task(SuperTask)
    case habit(Habit)
    case memo(MemoItem)
    
    var id: String {
        switch self {
        case .goal(let goal): return "goal-\(goal.id.uuidString)"
        case .task(let task): return "task-\(task.id.uuidString)"
        case .habit(let habit): return "habit-\(habit.id.uuidString)"
        case .memo(let memo): return "memo-\(memo.id.uuidString)"
        }
    }
    
    var title: String {
        switch self {
        case .goal(let goal): return goal.title
        case .task(let task): return task.title
        case .habit(let habit): return habit.title
        case .memo(let memo): return memo.title
        }
    }
    
    var type: String {
        switch self {
        case .goal: return "Goal"
        case .task: return "Task"
        case .habit: return "Habit"
        case .memo(let memo): return memo.itemType.displayName
        }
    }
    
    var color: Color {
        switch self {
        case .goal(let goal): return Color(hex: goal.colorHex ?? AppConstants.Colors.palette.first!)
        case .task(let task): return Color(hex: task.colorHex ?? AppConstants.Colors.palette.first!)
        case .habit(let habit): return Color(hex: habit.colorHex)
        case .memo(let memo): return memo.itemType.color
        }
    }
    
    var icon: String {
        switch self {
        case .goal: return "target"
        case .task: return "checkmark.circle"
        case .habit: return "repeat"
        case .memo(let memo): return memo.itemType.iconName
        }
    }
}

// MARK: Вью ячейки календаря в сегменте
struct CalendarItemCard: View {
    let item: CalendarItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: item.icon)
                    .font(.caption)
                    .foregroundColor(item.color)
                
                Text(item.type)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            Text(item.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(8)
        .frame(width: 120, height: 60)
        .background(item.color.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(item.color.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
