import SwiftUI
import SwiftData

// Presentation · Habits — список привычек на дату; `HabitsViewModel` → `FilterHabitsUseCase`, `habitsRepository` из `AppDependencies` при необходимости.

// MARK: - Экран «Все привычки» (Presentation)
//
// MVVM + `FilterHabitsUseCase`; `HabitsRepository` для счётчика в форме создания привычки.

// MARK: - HABITS VIEW
struct AllHabitsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appDependencies) private var appDependencies
    @Query(sort: [SortDescriptor(\Habit.orderIndex, order: .forward)]) private var allHabits: [Habit]
    @Query private var appSettings: [HabitsSettings]
    @Query private var appDesignSettings: [AppDesignSettings]
    @Query private var appCalendarSettings: [AppCalendarSettings]
    @Query private var spheres: [Sphere]
    
    @State private var addHabit: Bool = false
    @State private var showEditHabitView: Bool = false
    @State private var habitToEdit: Habit?
    @State private var selectedDate: Date = .now
    @State private var weekStartDate: Date = Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now))!
    @State private var swipedHabitID: UUID?
    @State private var selectedSphereID: UUID? = nil
    @State private var selectedTag: String? = nil
    
    @State private var localShowCompletedHabits: Bool = true
    @State private var localShowArchivedHabits: Bool = false
    @State private var habitsViewCurrentDesign: HabitsViewDesign = .basic
    @State private var searchText: String = ""
    @State private var showSearchBar: Bool = false
    @EnvironmentObject private var calendarManager: CalendarManager
    @State private var showSettingsSheet: Bool = false
    @State private var habitsOrderKey: UUID = UUID()
    @StateObject private var viewModel: HabitsViewModel
    
    private let hapticManager = HapticSoundManager.shared

    /// См. комментарий к `resolvedDependencies` в `AllGoalsView`.
    private var resolvedDependencies: AppDependencies {
        if let appDependencies {
            return appDependencies
        }
        return AppDependencies.live(modelContext: modelContext)
    }

    init() {
        _viewModel = StateObject(wrappedValue: HabitsViewModel())
    }
    
    
    private var currentSettings: HabitsSettings {
        if appSettings.isEmpty {
            let newSettings = HabitsSettings()
            modelContext.insert(newSettings)
            try? modelContext.save()
            return newSettings
        }
        return appSettings[0]
    }
    
    private var globalCalendarVisibility: Bool {
        return appCalendarSettings.first?.isVisible ?? true
    }
    
    private var globalCalendarVisibilityBinding: Binding<Bool> {
        Binding(
            get: { globalCalendarVisibility },
            set: { _ in
                // Calendar visibility is controlled globally from Vision
            }
        )
    }
    
    // Active selected date (uses compact calendar when visible)
    private var activeSelectedDate: Date {
        globalCalendarVisibility ? calendarManager.selectedDate : selectedDate
    }
    private var normalizedActiveSelectedDate: Date {
        Calendar.current.startOfDay(for: activeSelectedDate)
    }
    private var listIdentityKey: String {
        "\(normalizedActiveSelectedDate.timeIntervalSince1970)-\(localShowCompletedHabits)-\(localShowArchivedHabits)"
    }
    
    private var filteredAndSortedHabits: [Habit] {
        viewModel.filteredHabits(
            allHabits: allHabits,
            selectedDate: normalizedActiveSelectedDate,
            searchText: searchText,
            selectedSphereID: selectedSphereID,
            selectedTag: selectedTag,
            localShowCompletedHabits: localShowCompletedHabits,
            localShowArchivedHabits: localShowArchivedHabits
        )
    }
    
    private var hasAnyArchivedHabits: Bool {
        allHabits.contains { $0.isArchived }
    }
    
    private var completedHabitsCountForSelectedDate: Int {
        allHabits.filter { habit in
            switch habit.completionStatus(on: normalizedActiveSelectedDate) {
            case .completedHabit, .missedHabit, .skippedHabit:
                return true
            case .activeHabit, .partialHabit:
                return false
            }
        }.count
    }
    
    private var hasAnyCompletedHabitsForSelectedDate: Bool {
        completedHabitsCountForSelectedDate > 0
    }
    
    private var hasActiveFilters: Bool {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty || selectedSphereID != nil || selectedTag != nil
    }
    
    private var uniqueHabitTags: [String] {
        Set(allHabits.flatMap { $0.tags.map { $0.name } }).sorted()
    }
    
    private var currentMonthAndYear: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: activeSelectedDate).uppercased()
    }
    
    private var isTodaySelected: Bool {
        Calendar.current.isDateInToday(activeSelectedDate)
    }
    
    private var isFutureDate: Bool {
        let today = Calendar.current.startOfDay(for: .now)
        let selected = Calendar.current.startOfDay(for: activeSelectedDate)
        return selected > today
    }

    /// Как `mainContent` + `goalsList` в `AllGoalsView`.
    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            MainTabHeaderRow(
                showSearchBar: showSearchBar,
                calendarVisible: globalCalendarVisibility,
                searchContent: {
                    SearchBarView(
                        searchText: $searchText,
                        isVisible: $showSearchBar,
                        placeholder: "search habits..."
                    )
                },
                calendarContent: {
                    calendarView(
                        selectedDate: $calendarManager.selectedDate,
                        weekStartDate: $calendarManager.weekStartDate,
                        isVisible: globalCalendarVisibilityBinding
                    )
                },
                menuContent: {
                    // Add habit
                    Button {
                        hapticManager.openPage()
                        addHabit = true
                    } label: {
                        Label("Add habit", systemImage: "plus.circle")
                    }
                    Divider()
                    // Filters
                    Menu {
                        Button {
                            hapticManager.selectionChanged()
                            withAnimation(.easeInOut(duration: 0.3)) {
                                if globalCalendarVisibility {
                                    // Calendar visibility is controlled globally from Vision
                                }
                                showSearchBar.toggle()
                                if !showSearchBar {
                                    searchText = ""
                                }
                            }
                        } label: {
                            Label(showSearchBar ? "Hide search" : "Search habits", systemImage: "magnifyingglass")
                        }
                        
                        if hasAnyCompletedHabitsForSelectedDate {
                            Button {
                                hapticManager.selectionChanged()
                                withAnimation {
                                    localShowCompletedHabits.toggle()
                                    currentSettings.showCompletedAndSkippedHabits = localShowCompletedHabits
                                    try? modelContext.save()
                                }
                            } label: {
                                if localShowCompletedHabits {
                                    Label("Hide completed", systemImage: "eye.slash")
                                } else {
                                    Label("Show completed (\(completedHabitsCountForSelectedDate))", systemImage: "eye")
                                }
                            }
                        }
                        
                        if hasAnyArchivedHabits {
                            Button {
                                hapticManager.selectionChanged()
                                withAnimation {
                                    localShowArchivedHabits.toggle()
                                    currentSettings.showArchivedHabits = localShowArchivedHabits
                                    try? modelContext.save()
                                }
                            } label: {
                                Label(
                                    localShowArchivedHabits ? "Hide archived" : "Show archived",
                                    systemImage: localShowArchivedHabits ? "archivebox.fill" : "archivebox"
                                )
                            }
                        }
                        MainTabFilterMenus.sphereSubmenu(
                            spheres: spheres,
                            selectedSphereID: Binding(
                                get: { selectedSphereID },
                                set: { newValue in
                                    withAnimation { selectedSphereID = newValue }
                                }
                            ),
                            onSelectionChange: { hapticManager.selectionChanged() }
                        )
                        MainTabFilterMenus.tagSubmenu(
                            tags: uniqueHabitTags,
                            selectedTag: $selectedTag,
                            onSelectionChange: { hapticManager.selectionChanged() }
                        )
                        
                    } label: {
                        Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                    }
                    
                    if hasActiveFilters {
                        Button {
                            hapticManager.selectionChanged()
                            withAnimation {
                                showSearchBar = false
                                searchText = ""
                                selectedSphereID = nil
                                selectedTag = nil
                            }
                        } label: {
                            Label("Clear filters", systemImage: "xmark.circle")
                        }
                    }
                    Divider()
                    Button {
                        hapticManager.selectionChanged()
                        showSettingsSheet = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            )

            habitsList
        }
    }

    @ViewBuilder
    private var habitsList: some View {
        if filteredAndSortedHabits.isEmpty {
            emptyStateView
        } else {
            List {
                ForEach(filteredAndSortedHabits, id: \.id) { habit in
                    HabitCardView(habit: habit, date: normalizedActiveSelectedDate, design: habitsViewCurrentDesign, isFutureDate: isFutureDate, onDoubleTap: {
                        hapticManager.playHaptic(style: .medium)
                        habitToEdit = habit
                        showEditHabitView = true
                    })
                    .id(habit.id)
                    .mainTabListRowHabitsChrome()
                    // Как в Goals/Tasks: лишний clipping убирает «дёрганья» при свайпе/перестановке на некоторых iOS.
                    .mainTabListCardRowSwipeClipping()
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
                }
                .onMove(perform: moveHabit)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentMargins(.top, 0, for: .scrollContent)
            .listSectionSpacing(0)
            .animation(.smooth(duration: 0.4), value: filteredAndSortedHabits.map { "\($0.id)-\($0.completionStatus(on: normalizedActiveSelectedDate).rawValue)" })
            .animation(.smooth(duration: 0.4), value: habitsOrderKey)
            // Пересоздаём `List` только при смене даты, чтобы диффинг строк был максимально плавным.
            .id(normalizedActiveSelectedDate.timeIntervalSince1970)
        }
    }

    @ViewBuilder
    private var emptyStateView: some View {
        EmptyStateView.noHabits()
            .tabEmptyStateLayout()
    }

    var body: some View {
        NavigationStack {
            mainContent
                .background {
                    Color(UIColor.systemGroupedBackground)
                        .ignoresSafeArea(edges: .top)
                }
                .sheet(isPresented: $addHabit) {
                EditHabitView(modelContext: modelContext, habitToEdit: .constant(nil), allHabitsCount: (try? resolvedDependencies.habitsRepository.fetchCount()) ?? allHabits.count, ruleEffectiveDate: normalizedActiveSelectedDate)
            }
            .sheet(isPresented: $showEditHabitView) {
                EditHabitView(modelContext: modelContext, habitToEdit: $habitToEdit, ruleEffectiveDate: normalizedActiveSelectedDate)
                    .onDisappear {
                        habitToEdit = nil
                    }
            }
        }
        .onAppear {
            // Ensure single settings instance and sync local flag
            if appSettings.count > 1 {
                            for extra in appSettings.dropFirst() { modelContext.delete(extra) }
                            try? modelContext.save()
                        } else if appSettings.isEmpty {
                            let s = HabitsSettings()
                            modelContext.insert(s)
                            try? modelContext.save()
                        }
                        localShowCompletedHabits = currentSettings.showCompletedAndSkippedHabits
                        localShowArchivedHabits = currentSettings.showArchivedHabits
            // Ensure a single global settings object
            if appDesignSettings.count > 1 {
                if let keep = appDesignSettings.first {
                    for extra in appDesignSettings.dropFirst() { modelContext.delete(extra) }
                    try? modelContext.save()
                    habitsViewCurrentDesign = (keep.design == .basic) ? .basic : .colorful
                }
            }
            // Default to Basic, but sync with global if available
            if let global = appDesignSettings.first {
                habitsViewCurrentDesign = (global.design == .basic) ? .basic : .colorful
            } else {
                habitsViewCurrentDesign = .basic // Default to Basic
            }
        }
        // Live sync if global changes elsewhere
        .onChange(of: (appDesignSettings.first?.design ?? .basic)) { _, newValue in
            let mapped: HabitsViewDesign = (newValue == .basic) ? .basic : .colorful
            habitsViewCurrentDesign = mapped
            currentSettings.currentDesign = mapped
        }
        // Listen notification to force immediate UI update across tabs
        .onReceive(NotificationCenter.default.publisher(for: .appDesignDidChange)) { _ in
            if let global = appDesignSettings.first {
                let mapped: HabitsViewDesign = (global.design == .basic) ? .basic : .colorful
                habitsViewCurrentDesign = mapped
                currentSettings.currentDesign = mapped
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .appCalendarVisibilityDidChange)) { _ in
            calendarManager.isVisible = globalCalendarVisibility
        }
        .onReceive(NotificationCenter.default.publisher(for: .habitStatusDidChange)) { _ in
            // Обновляем ключ для триггера анимации перемещения карточек
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                habitsOrderKey = UUID()
            }
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsView()
        }
    }
    
    private func toggleCompleted(for habit: Habit, on date: Date) {
        let isCompleted = habit.isCompletedHabit(on: date)
        habit.updateStatus(to: isCompleted ? .activeHabit : .completedHabit, on: date)
        
        if isCompleted {
            hapticManager.actionUndone()
        } else {
            hapticManager.completionSuccess()
        }
    }
    
    private func toggleSkipped(for habit: Habit, on date: Date) {
        let isSkipped = habit.isMissedHabit(on: date)
        habit.updateStatus(to: isSkipped ? .activeHabit : .missedHabit, on: date)
        
        if isSkipped {
            hapticManager.actionUndone()
        } else {
            hapticManager.itemSkipped()
        }
    }
    
    private func toggleNotApplicable(for habit: Habit, on date: Date) {
        let isNotApplicable = habit.isSkippedHabit(on: date)
        habit.updateStatus(to: isNotApplicable ? .activeHabit : .skippedHabit, on: date)
        
        if isNotApplicable {
            hapticManager.actionUndone()
        } else {
            hapticManager.itemSkipped()
        }
    }
    
    private func deleteHabit(_ habit: Habit) {
        modelContext.delete(habit)
        hapticManager.itemDeleted()
        reindexAllHabits()
    }
    
    private func moveHabit(from source: IndexSet, to destination: Int) {
        hapticManager.playHaptic(style: .medium)
        var reorderedFilteredHabits = filteredAndSortedHabits
        guard !source.isEmpty else { return }
        reorderedFilteredHabits.move(fromOffsets: source, toOffset: destination)
        
        let allHabitsDict = Dictionary(uniqueKeysWithValues: allHabits.map { ($0.id, $0) })
        var newOrderIDs: [UUID] = []
        let scheduledHabitsIDs: Set<UUID> = Set(reorderedFilteredHabits.map { $0.id })
        
        newOrderIDs.append(contentsOf: reorderedFilteredHabits.map { $0.id })
        
        for habit in allHabits.sorted(by: { $0.orderIndex < $1.orderIndex }) {
            if !scheduledHabitsIDs.contains(habit.id) {
                newOrderIDs.append(habit.id)
            }
        }
        
        for (index, habitID) in newOrderIDs.enumerated() {
            if let habit = allHabitsDict[habitID] {
                habit.orderIndex = index
            }
        }
        
        do {
            try modelContext.save()
            // Уведомляем об изменении для обновления анимации
            NotificationCenter.default.postAppEvent(.habitStatusDidChange)
        } catch {
            print("Failed to save model context after move: \(error.localizedDescription)")
        }
    }
    
    private func reindexAllHabits() {
        let sortedAllHabits = allHabits.sorted(by: { $0.orderIndex < $1.orderIndex })
        
        for (index, habit) in sortedAllHabits.enumerated() {
            if habit.orderIndex != index {
                habit.orderIndex = index
            }
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to save model context after reindexing: \(error.localizedDescription)")
        }
    }
}

