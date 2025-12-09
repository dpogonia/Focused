import SwiftUI // WITH WHITE
import SwiftData

// MARK: - HABITS VIEW
struct AllHabitsView: View {
    @Environment(\.modelContext) private var modelContext
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
    @State private var habitsViewCurrentDesign: HabitsViewDesign = .basic
    @State private var searchText: String = ""
    @State private var showSearchBar: Bool = false
    @StateObject private var compactCalendarManager = CalendarManager()
    @State private var showSettingsSheet: Bool = false
    @State private var safeAreaTop: CGFloat = 0
    @State private var habitsOrderKey: UUID = UUID()
    
    private let hapticManager = HapticSoundManager.shared
    
    // Get safe area top directly
    private func updateSafeAreaTop() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            if let window = windowScene.windows.first {
                safeAreaTop = window.safeAreaInsets.top
            } else if let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) {
                safeAreaTop = keyWindow.safeAreaInsets.top
            }
        }
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
        globalCalendarVisibility ? compactCalendarManager.selectedDate : selectedDate
    }
    private var normalizedActiveSelectedDate: Date {
        Calendar.current.startOfDay(for: activeSelectedDate)
    }
    private var listIdentityKey: String {
        "\(normalizedActiveSelectedDate.timeIntervalSince1970)-\(localShowCompletedHabits)"
    }
    
    private var filteredAndSortedHabits: [Habit] {
        let normalizedSelectedDate = normalizedActiveSelectedDate
        
        var tempHabits = allHabits.filter { habit in
            HabitLogicService(habit: habit).isScheduled(on: normalizedSelectedDate)
        }
        
        if !searchText.isEmpty {
            tempHabits = tempHabits.filter { $0.title.lowercased().contains(searchText.lowercased()) }
        }
        
        if let selectedSphereID = selectedSphereID {
            tempHabits = tempHabits.filter { $0.sphereID == selectedSphereID }
        }
        
        if let selectedTag = selectedTag {
            tempHabits = tempHabits.filter { $0.tags.contains(where: { $0.name == selectedTag }) }
        }
        
        let applyCompletionFilter = !localShowCompletedHabits
        if applyCompletionFilter {
            tempHabits = tempHabits.filter { habit in
                let status = habit.completionStatus(on: normalizedSelectedDate)
                return status == .activeHabit || status == .partialHabit
            }
        }
        
        tempHabits.sort { h1, h2 in
            if h1.isPassive != h2.isPassive {
                return !h1.isPassive && h2.isPassive
            }
            let status1 = h1.completionStatus(on: normalizedSelectedDate)
            let status2 = h2.completionStatus(on: normalizedSelectedDate)
            if status1 != status2 {
                return status1 < status2
            }
            return h1.orderIndex < h2.orderIndex
        }
        return tempHabits
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
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: Calendar and Menu HStack
                HStack(spacing: 0) {
                    if showSearchBar {
                        SearchBarView(
                            searchText: $searchText,
                            isVisible: $showSearchBar,
                            placeholder: "Search habits..."
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        calendarView(
                            selectedDate: $compactCalendarManager.selectedDate,
                            weekStartDate: $compactCalendarManager.weekStartDate,
                            isVisible: globalCalendarVisibilityBinding
                        )
                        .opacity(globalCalendarVisibility ? 1 : 0)
                        .allowsHitTesting(globalCalendarVisibility && !showSearchBar)
                        .animation(.easeInOut(duration: 0.25), value: globalCalendarVisibility)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    EllipsisMenuButton {
                        // Add habit
                        Button {
                            hapticManager.openPage()
                            addHabit = true
                        } label: {
                            Label("Add habit", systemImage: "plus.circle")
                        }
                        Divider()
                        // Filters
                        Menu("Filter") {
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
                            Button {
                                hapticManager.selectionChanged()
                                withAnimation {
                                    localShowCompletedHabits.toggle()
                                    currentSettings.showCompletedAndSkippedHabits = localShowCompletedHabits
                                    try? modelContext.save()
                                }
                            } label: {
                                Label(localShowCompletedHabits ? "Hide completed" : "Show completed",
                                      systemImage: localShowCompletedHabits ? "eye.slash" : "eye")
                            }
                            Menu("Filter by Sphere") {
                                ForEach(spheres) { sphere in
                                    Button {
                                        hapticManager.selectionChanged()
                                        withAnimation { selectedSphereID = sphere.id }
                                    } label: {
                                        HStack {
                                            Text(sphere.title)
                                            Spacer()
                                            if selectedSphereID == sphere.id {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                                Button {
                                    hapticManager.selectionChanged()
                                    withAnimation { selectedSphereID = nil }
                                } label: {
                                    HStack {
                                        Text("Clear filter")
                                        Spacer()
                                        if selectedSphereID == nil {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                            Menu("Filter by Tag") {
                                ForEach(uniqueHabitTags, id: \.self) { tag in
                                    Button {
                                        selectedTag = tag
                                        hapticManager.selectionChanged()
                                    } label: {
                                        HStack {
                                            Text(tag)
                                            Spacer()
                                            if selectedTag == tag {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                                Button {
                                    selectedTag = nil
                                    hapticManager.selectionChanged()
                                } label: {
                                    HStack {
                                        Text("Clear filter")
                                        Spacer()
                                        if selectedTag == nil {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
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
                    .padding(.trailing, 16)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, safeAreaTop)
                .animation(.easeInOut(duration: 0.3), value: showSearchBar)
                
                if filteredAndSortedHabits.isEmpty {
                    EmptyStateView.noHabits()
                        .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - 200)
                        .background(Color(UIColor.systemGroupedBackground))
                } else {
                    List {
                        ForEach(filteredAndSortedHabits, id: \.id) { habit in
                            HabitCardView(habit: habit, date: normalizedActiveSelectedDate, design: habitsViewCurrentDesign, isFutureDate: isFutureDate, onDoubleTap: {
                                hapticManager.playHaptic(style: .medium)
                                habitToEdit = habit
                                showEditHabitView = true
                            })
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .move(edge: .bottom).combined(with: .opacity)
                            ))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                        .onMove(perform: moveHabit)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentMargins(.top, 0, for: .scrollContent)
                    .listSectionSpacing(0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: filteredAndSortedHabits.map { "\($0.id)-\($0.completionStatus(on: normalizedActiveSelectedDate).rawValue)" })
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: habitsOrderKey)
                    .id(listIdentityKey)
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .ignoresSafeArea(edges: .top)
            .sheet(isPresented: $addHabit) {
                EditHabitView(modelContext: modelContext, habitToEdit: .constant(nil), allHabitsCount: allHabits.count, ruleEffectiveDate: normalizedActiveSelectedDate)
            }
            .sheet(isPresented: $showEditHabitView) {
                EditHabitView(modelContext: modelContext, habitToEdit: $habitToEdit, ruleEffectiveDate: normalizedActiveSelectedDate)
                    .onDisappear {
                        habitToEdit = nil
                    }
            }
        }
        .onAppear {
            updateSafeAreaTop()
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
            compactCalendarManager.isVisible = globalCalendarVisibility
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
            NotificationCenter.default.post(name: .habitStatusDidChange, object: nil)
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

