import SwiftUI
import SwiftData

// MARK: - TASKS SEGMENTED
struct GoalsForSphereView: View {
    let sphereID: UUID
    let selectedDate: Date
    @Query private var goals: [Goal]
    @Environment(\.modelContext) private var modelContext
    @State private var goalToEdit: Goal? = nil
    @State private var showAddEditSheet = false
    private let hapticManager = HapticSoundManager.shared
    
    init(sphereID: UUID, selectedDate: Date = .now) {
        self.sphereID = sphereID
        self.selectedDate = selectedDate
        self._goals = Query(filter: #Predicate<Goal> { $0.sphereID == sphereID })
    }
    
    private var activeGoals: [Goal] {
        // Сортируем: сначала активные, потом выполненные/пропущенные
        return goals.sorted { g1, g2 in
            let g1IsCompleted = g1.status == .completed || g1.status == .missed
            let g2IsCompleted = g2.status == .completed || g2.status == .missed
            if g1IsCompleted != g2IsCompleted {
                return !g1IsCompleted && g2IsCompleted
            }
            return g1.orderIndex < g2.orderIndex
        }
    }
    
    var body: some View {
        Group {
            if activeGoals.isEmpty {
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
                    ForEach(activeGoals) { goal in
                    GoalCardView(goal: goal, goalDesign: .basic) {
                        goalToEdit = goal
                        showAddEditSheet = true
                        }
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 1)
                        .background(Color.clear)
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            leadingSwipeButton(for: goal)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            trailingSwipeButtons(for: goal)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
        }
            .sheet(isPresented: $showAddEditSheet) {
                EditGoalView(goalToEdit: $goalToEdit, allGoalsCount: goals.count)
        }
    }
    
    @ViewBuilder
    private func leadingSwipeButton(for goal: Goal) -> some View {
        let status = goal.status
        Button {
            hapticManager.playHaptic(style: .light)
            let oldStatus = goal.status
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                if status == .completed || status == .missed {
                    // Unmark - вернуть в pending
                    goal.updateStatus(to: .pending)
                    hapticManager.actionUndone()
                } else {
                    // Complete
                    goal.updateStatus(to: .completed)
                    hapticManager.completionSuccess()
                }
                try? modelContext.save()
                // Уведомляем об изменении для обновления анимации
                NotificationCenter.default.post(name: .goalStatusDidChange, object: nil)
            }
        } label: {
            Label(
                status == .completed || status == .missed ? "Unmark" : "Done",
                systemImage: status == .completed || status == .missed ? "arrow.uturn.backward.circle.fill" : "checkmark.circle"
            )
        }
        .tint(status == .completed || status == .missed ? .gray : .green)
    }
    
    @ViewBuilder
    private func trailingSwipeButtons(for goal: Goal) -> some View {
        let status = goal.status
        if status == .completed || status == .missed {
            // Unmark button
            Button {
                hapticManager.playHaptic(style: .light)
                let oldStatus = goal.status
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    goal.updateStatus(to: .pending)
                    hapticManager.actionUndone()
                    try? modelContext.save()
                    // Уведомляем об изменении для обновления анимации
                    NotificationCenter.default.post(name: .goalStatusDidChange, object: nil)
                }
            } label: {
                Label("Unmark", systemImage: "arrow.uturn.backward.circle.fill")
            }
            .tint(.gray)
        } else {
            // Delete and Edit buttons
            Button(role: .destructive) {
                hapticManager.itemDeleted()
                modelContext.delete(goal)
                try? modelContext.save()
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .tint(.red)
            
            Button {
                hapticManager.openPage()
                goalToEdit = goal
                showAddEditSheet = true
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
        }
    }
}

// MARK: - TASKS SEGMENTED
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
    
    private var activeTasks: [SuperTask] {
        return tasks.filter { task in
            task.statusEnum != .completed && task.statusEnum != .cancelled
        }
    }
    
    var body: some View {
        Group {
            if activeTasks.isEmpty {
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
                    ForEach(activeTasks) { task in
                    TaskCardView(task: task, onEdit: {
                        taskToEdit = task
                        showEditTaskSheet = true
                    })
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 1)
                        .background(Color.clear)
                    }
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
}

// MARK: - HABITS SEGMENTED
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
        let scheduled = habits.filter { HabitLogicService(habit: $0).isScheduled(on: selectedDate) }
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
                    HabitCardView(habit: habit, date: selectedDate, design: .basic, isFutureDate: selectedDate > Date()) {
                        habitToEdit = habit
                        showEditHabitSheet = true
                        }
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 1)
                        .background(Color.clear)
                    }
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
}

// MARK: - MEMO SEGMENTED
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
    @State private var showListStatistics = false
    @State private var isNoteAlbumReorderMode = false
    @State private var showNoteAlbumStatistics = false
    @State private var showCounterStatistics = false
    @State private var showStreakStatistics = false
    @State private var showSkillStatistics = false
    @State private var showBudgetStatistics = false
    
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
            case .tracker:
                if let content = try? JSONDecoder().decode(MemoTrackerContent.self, from: data) {
                    return content.entries.contains { (entry: MemoTrackerContent.TrackerEntry) in
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
            }
            
            return false
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
                        Button {
                            viewerItem = memo
                        } label: {
                            MemoCardView(memoItem: memo, design: design)
                        }
                        .buttonStyle(.plain)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .padding(.horizontal, 1)
                        .padding(.vertical, 1)
                        .contextMenu {
                            Button {
                                memoToEdit = memo
                                showAddEditSheet = true
                            } label: {
                                Label("Edit Memo", systemImage: "pencil")
                            }
                            
                            Button {
                                viewerItem = memo
                            } label: {
                                Label("View Details", systemImage: "doc.text.magnifyingglass")
                            }
                            
                            Button {
                                let newMemo = MemoItem(title: memo.title + " (copy)", orderIndex: memo.orderIndex + 1, type: memo.itemType, tags: memo.tags)
                                newMemo.contentData = memo.contentData
                                modelContext.insert(newMemo)
                                try? modelContext.save()
                            } label: {
                                Label("Duplicate", systemImage: "plus.square.on.square")
                            }
                            
                            Button(role: .destructive) {
                                modelContext.delete(memo)
                                try? modelContext.save()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                modelContext.delete(memo)
                                try? modelContext.save()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            
                            Button {
                                memoToEdit = memo
                                showAddEditSheet = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.orange)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                // Archive/Unarchive item
                                if memo.status == .archived {
                                    memo.status = .active
                                } else {
                                    memo.status = .archived
                                }
                                try? modelContext.save()
                                NotificationCenter.default.post(name: .memoStatusDidChange, object: nil)
                            } label: {
                                Label(
                                    memo.status == .archived ? "Unarchive" : "Archive",
                                    systemImage: memo.status == .archived ? "tray.and.arrow.up" : "archivebox"
                                )
                            }
                            .tint(.blue)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 10)
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
        .sheet(isPresented: $showAddEditSheet) {
            if let memo = memoToEdit {
                EditMemoView(memoToEdit: $memoToEdit, memoType: memo.itemType)
                    .id("edit-\(memo.id)")
            }
        }
    }
    
    // MARK: - Memo Detail View
    @ViewBuilder
    private func memoDetailView(for item: MemoItem) -> some View {
        if item.itemType == .list {
            ListContentView(item: item, isReorderMode: $isReorderMode, showCompleted: $showCompleted, showListStatistics: $showListStatistics)
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
                                    isReorderMode.toggle()
                                }
                            } label: {
                                Label(isReorderMode ? "Готово" : "Изменить порядок",
                                      systemImage: isReorderMode ? "checkmark" : "arrow.up.arrow.down")
                            }
                            
                            Button {
                                withAnimation {
                                    showCompleted.toggle()
                                }
                            } label: {
                                Label(showCompleted ? "Скрыть завершенные" : "Показать завершенные",
                                      systemImage: showCompleted ? "eye.slash" : "eye")
                            }
                            
                            Button {
                                withAnimation {
                                    showListStatistics.toggle()
                                }
                            } label: {
                                Label(showListStatistics ? "Скрыть статистику" : "Показать статистику",
                                      systemImage: showListStatistics ? "chart.bar.fill" : "chart.bar")
                            }
                            
                            Divider()
                            
                            Button {
                                memoToEdit = item
                                showAddEditSheet = true
                            } label: {
                                Label("Редактировать", systemImage: "pencil")
                            }
                            
                            Divider()
                            
                            Button(role: .destructive) {
                                modelContext.delete(item)
                                try? modelContext.save()
                                viewerItem = nil
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                        }
                    }
                }
        } else if item.itemType == .noteAlbum {
            NoteAlbumContentView(item: item, isReorderMode: $isNoteAlbumReorderMode, showNoteAlbumStatistics: $showNoteAlbumStatistics)
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
                                    isNoteAlbumReorderMode.toggle()
                                }
                            } label: {
                                Label(isNoteAlbumReorderMode ? "Готово" : "Изменить порядок",
                                      systemImage: isNoteAlbumReorderMode ? "checkmark" : "arrow.up.arrow.down")
                            }
                            
                            Button {
                                withAnimation {
                                    showNoteAlbumStatistics.toggle()
                                }
                            } label: {
                                Label(showNoteAlbumStatistics ? "Скрыть статистику" : "Показать статистику",
                                      systemImage: showNoteAlbumStatistics ? "chart.bar.fill" : "chart.bar")
                            }
                            
                            Divider()
                            
                            Button {
                                memoToEdit = item
                                showAddEditSheet = true
                            } label: {
                                Label("Редактировать", systemImage: "pencil")
                            }
                            
                            Divider()
                            
                            Button(role: .destructive) {
                                modelContext.delete(item)
                                try? modelContext.save()
                                viewerItem = nil
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
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
                                Label(showCounterStatistics ? "Скрыть статистику" : "Показать статистику",
                                      systemImage: showCounterStatistics ? "chart.bar.fill" : "chart.bar")
                            }
                            
                            Divider()
                            
                            Button {
                                memoToEdit = item
                                showAddEditSheet = true
                            } label: {
                                Label("Редактировать", systemImage: "pencil")
                            }
                            
                            Divider()
                            
                            Button(role: .destructive) {
                                modelContext.delete(item)
                                try? modelContext.save()
                                viewerItem = nil
                            } label: {
                                Label("Удалить", systemImage: "trash")
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
                                Label(showStreakStatistics ? "Скрыть статистику" : "Показать статистику",
                                      systemImage: showStreakStatistics ? "chart.bar.fill" : "chart.bar")
                            }
                            
                            Divider()
                            
                            Button {
                                memoToEdit = item
                                showAddEditSheet = true
                            } label: {
                                Label("Редактировать", systemImage: "pencil")
                            }
                            
                            Divider()
                            
                            Button(role: .destructive) {
                                modelContext.delete(item)
                                try? modelContext.save()
                                viewerItem = nil
                            } label: {
                                Label("Удалить", systemImage: "trash")
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
                                Label(showSkillStatistics ? "Скрыть статистику" : "Показать статистику",
                                      systemImage: showSkillStatistics ? "chart.bar.fill" : "chart.bar")
                            }
                            
                            Divider()
                            
                            Button {
                                memoToEdit = item
                                showAddEditSheet = true
                            } label: {
                                Label("Редактировать", systemImage: "pencil")
                            }
                            
                            Divider()
                            
                            Button(role: .destructive) {
                                modelContext.delete(item)
                                try? modelContext.save()
                                viewerItem = nil
                            } label: {
                                Label("Удалить", systemImage: "trash")
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
                                Label(showBudgetStatistics ? "Скрыть статистику" : "Показать статистику",
                                      systemImage: showBudgetStatistics ? "chart.bar.fill" : "chart.bar")
                            }
                            
                            Divider()
                            
                            Button {
                                memoToEdit = item
                                showAddEditSheet = true
                            } label: {
                                Label("Редактировать", systemImage: "pencil")
                            }
                            
                            Divider()
                            
                            Button(role: .destructive) {
                                modelContext.delete(item)
                                try? modelContext.save()
                                viewerItem = nil
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                        }
                    }
                }
        } else if item.itemType == .mood {
            MoodContentView(item: item)
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
                                memoToEdit = item
                                showAddEditSheet = true
                            } label: {
                                Label("Редактировать", systemImage: "pencil")
                            }
                            
                            Divider()
                            
                            Button(role: .destructive) {
                                modelContext.delete(item)
                                try? modelContext.save()
                                viewerItem = nil
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                        }
                    }
                }
        } else if item.itemType == .time {
            TimeContentView(item: item)
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
                                memoToEdit = item
                                showAddEditSheet = true
                            } label: {
                                Label("Редактировать", systemImage: "pencil")
                            }
                            
                            Divider()
                            
                            Button(role: .destructive) {
                                modelContext.delete(item)
                                try? modelContext.save()
                                viewerItem = nil
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                        }
                    }
                }
        } else if item.itemType == .health {
            HealthContentView(item: item)
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
                                memoToEdit = item
                                showAddEditSheet = true
                            } label: {
                                Label("Редактировать", systemImage: "pencil")
                            }
                            
                            Divider()
                            
                            Button(role: .destructive) {
                                modelContext.delete(item)
                                try? modelContext.save()
                                viewerItem = nil
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                        }
                    }
                }
        } else if item.itemType == .tracker {
            TrackerContentView(item: item)
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
                                memoToEdit = item
                                showAddEditSheet = true
                            } label: {
                                Label("Редактировать", systemImage: "pencil")
                            }
                            
                            Divider()
                            
                            Button(role: .destructive) {
                                modelContext.delete(item)
                                try? modelContext.save()
                                viewerItem = nil
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                        }
                    }
                }
        } else {
            // Fallback for unknown types (should not happen)
            Text("Неизвестный тип мемо")
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

// MARK: - MEMO ITEM CARD
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

// MARK: - CALENDAR ITEM
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

// MARK: - CALENDAR ITEM CARD VIEW
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
