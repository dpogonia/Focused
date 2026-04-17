import SwiftUI
import SwiftData

// MARK: - Экран «Все цели» (Presentation)
//
// **Слои:**
// - Данные: преимущественно `@Query` (SwiftData) + локальный `@State`.
// - Логика списка: `GoalsViewModel` → `FilterGoalsUseCase` (см. `Features/Goals/Interactor`).
// - Счётчик для редакторов: `resolvedDependencies.goalsRepository` (**Repository**) из `AppDependencies` (fallback без env).
//
// **Паттерны:** MVVM, Repository, DI через Environment.

// MARK: - ALL GOALS VIEW
struct AllGoalsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appDependencies) private var appDependencies
    @Query(sort: [SortDescriptor(\Goal.orderIndex, order: .forward)]) private var allGoals: [Goal]
    @Query private var appSettings: [GoalsSettings]
    @Query private var appDesignSettings: [AppDesignSettings]
    @Query private var appCalendarSettings: [AppCalendarSettings]
    @Query private var spheres: [Sphere]
    @State private var searchText: String = ""
    @State private var showEditGoalView: Bool = false
    @State private var goalToEdit: Goal?
    @State private var selectedSphereID: UUID? = nil
    @State private var selectedTag: String? = nil
    @State private var localShowCompletedGoals: Bool = true
    @State private var localShowArchivedGoals: Bool = false
    @State private var allGoalsDesign: AllGoalsViewDesign = .basic
    @State private var showSearchBar: Bool = false
    @EnvironmentObject private var calendarManager: CalendarManager
    @State private var showSettingsSheet: Bool = false
    @State private var goalsOrderKey: UUID = UUID()
    @StateObject private var viewModel: GoalsViewModel
    @State private var showDeleteGoalConfirmation: Bool = false
    @State private var goalPendingDeletion: Goal?
    @State private var showArchiveGoalConfirmation: Bool = false
    @State private var goalPendingArchive: Goal?
    /// Анимация свайпа «выполнено»: заголовок меняется до сохранения (как задержка в Tasks).
    @State private var goalLeadingSwipeVisual: (id: UUID, titleCompleted: Bool)? = nil
    
    private let hapticManager = HapticSoundManager.shared
    
    /// Задержки как в `TaskCardView.performCompleteTaskAnimationThenSave` / uncomplete.
    private static let goalSwipeCompleteSaveDelay: TimeInterval = 0.65
    private static let goalSwipeUncompleteSaveDelay: TimeInterval = 1.0

    /// Если `ContentView` уже положил `appDependencies` в Environment — используем его; иначе собираем из `modelContext` (превью/изолированные экраны).
    private var resolvedDependencies: AppDependencies {
        if let appDependencies {
            return appDependencies
        }
        return AppDependencies.live(modelContext: modelContext)
    }

    init() {
        _viewModel = StateObject(wrappedValue: GoalsViewModel())
    }
    
    
    private var goalsSettings: GoalsSettings {
        if appSettings.isEmpty {
            let newSettings = GoalsSettings()
            modelContext.insert(newSettings)
            return newSettings
        }
        return appSettings[0]
    }
    
    private var filteredAndSortedGoals: [Goal] {
        viewModel.filteredGoals(
            allGoals: allGoals,
            selectedDate: calendarManager.selectedDate,
            calendarVisible: globalCalendarVisibility,
            globalCalendarSettings: appCalendarSettings,
            searchText: searchText,
            selectedSphereID: selectedSphereID,
            selectedTag: selectedTag,
            localShowCompletedGoals: localShowCompletedGoals,
            localShowArchivedGoals: localShowArchivedGoals
        )
    }
    
    private var uniqueTags: [String] {
        Set(allGoals.flatMap { $0.tags.map { $0.name } }).sorted()
    }
    
    private var completedGoalsCount: Int {
        allGoals.filter { $0.status == .completed || $0.status == .missed }.count
    }
    
    private var hasAnyCompletedGoals: Bool {
        completedGoalsCount > 0
    }
    
    private var hasAnyArchivedGoals: Bool {
        allGoals.contains { $0.status == .archived }
    }
    
    private var allGoalsCount: Int {
        (try? resolvedDependencies.goalsRepository.fetchCount()) ?? 0
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
    
    @ViewBuilder
    private var searchBarSection: some View {
        SearchBarView(
            searchText: $searchText,
            isVisible: $showSearchBar,
            placeholder: "search goals..."
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    @ViewBuilder
    private var addGoalButton: some View {
        Button {
            hapticManager.openPage()
            goalToEdit = nil
            showEditGoalView = true
        } label: {
            Label("Add Goal", systemImage: "plus.circle")
        }
    }
    
    @ViewBuilder
    private var searchButton: some View {
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
            Label(showSearchBar ? "Hide Search" : "Search Goals", systemImage: "magnifyingglass")
        }
    }
    
    
    @ViewBuilder
    private var completedGoalsButton: some View {
        if hasAnyCompletedGoals {
            Button {
                hapticManager.selectionChanged()
                withAnimation {
                    localShowCompletedGoals.toggle()
                    goalsSettings.showCompletedGoals = localShowCompletedGoals
                    try? modelContext.save()
                }
            } label: {
                if localShowCompletedGoals {
                    Label("Hide Completed", systemImage: "eye.slash")
                } else {
                    Label("Show Completed (\(completedGoalsCount))", systemImage: "eye")
                }
            }
        }
    }
    
    @ViewBuilder
    private var filterMenu: some View {
        Menu {
            searchButton
            completedGoalsButton
            archivedGoalsButton
            sphereFilterMenu
            tagFilterMenu
        } label: {
            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
        }
    }
    
    @ViewBuilder
    private var archivedGoalsButton: some View {
        if hasAnyArchivedGoals {
            Button {
                hapticManager.selectionChanged()
                withAnimation(.easeInOut(duration: 0.3)) {
                    localShowArchivedGoals.toggle()
                    goalsSettings.showArchivedGoals = localShowArchivedGoals
                    try? modelContext.save()
                }
            } label: {
                Label(
                    localShowArchivedGoals ? "Hide Archived" : "Show Archived",
                    systemImage: localShowArchivedGoals ? "archivebox.fill" : "archivebox"
                )
            }
        }
    }
    
    @ViewBuilder
    private var sphereFilterMenu: some View {
        MainTabFilterMenus.sphereSubmenu(spheres: spheres, selectedSphereID: $selectedSphereID)
    }
    
    @ViewBuilder
    private var tagFilterMenu: some View {
        MainTabFilterMenus.tagSubmenu(tags: uniqueTags, selectedTag: $selectedTag)
    }
    
    private func visualTitleCompleted(for goal: Goal) -> Bool? {
        guard let v = goalLeadingSwipeVisual, v.id == goal.id else { return nil }
        return v.titleCompleted
    }
    
    private var hasActiveFilters: Bool {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty || selectedSphereID != nil || selectedTag != nil
    }
    
    @ViewBuilder
    private func goalRowView(for goal: Goal) -> some View {
        GoalCardView(goal: goal, goalDesign: allGoalsDesign, visualTitleCompleted: visualTitleCompleted(for: goal)) {
            hapticManager.openPage()
            goalToEdit = goal
            showEditGoalView = true
        }
        .mainTabListCardRowChrome()
        .mainTabListCardRowSwipeClipping()
        .mainTabListRowSwipeActions {
            leadingSwipeButton(for: goal)
        } trailing: {
            trailingSwipeButtons(for: goal)
        }
        .transition(.asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .move(edge: .bottom).combined(with: .opacity)
        ))
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
        // Trailing: первый в коде — у внешнего края (жёлтый), последний — у карточки (красный).
        // Визуально слева направо от карточки: красная, серая, жёлтая.
        Button {
            hapticManager.selectionChanged()
            goalToEdit = goal
            showEditGoalView = true
        } label: {
            Image(systemName: "pencil")
        }
        .tint(.yellow)
        
        // Archive / Unarchive (like Memo: icon changes when archived)
        Button {
            hapticManager.selectionChanged()
            goalPendingArchive = goal
            showArchiveGoalConfirmation = true
        } label: {
            Image(systemName: status == .archived ? "tray.and.arrow.up" : "archivebox")
        }
        .tint(Color(UIColor.systemGray))
        
        Button {
            goalPendingDeletion = goal
            showDeleteGoalConfirmation = true
        } label: {
            Image(systemName: "trash")
        }
        .tint(.red)
    }
    
    private func deleteGoal(_ goal: Goal) {
        modelContext.delete(goal)
        try? modelContext.save()
    }
    
    private func deleteGoalAndOptionallyApplyNegativeImpact(_ goal: Goal, applyNegativeImpact: Bool) {
        if applyNegativeImpact, goal.negativeImpact > 0, let sphereID = goal.sphereID {
            let fetch = FetchDescriptor<Sphere>(predicate: #Predicate<Sphere> { $0.id == sphereID })
            if let sphere = try? modelContext.fetch(fetch).first {
                sphere.satisfaction = max(0.0, min(100.0, sphere.satisfaction - goal.negativeImpact))
            }
        }
        modelContext.delete(goal)
        try? modelContext.save()
        NotificationCenter.default.postAppEvent(.goalStatusDidChange)
        NotificationCenter.default.postAppEvent(.sphereSatisfactionDidChange)
    }

    private func archiveGoalAndOptionallyApplyNegativeImpact(_ goal: Goal, applyNegativeImpact: Bool) {
        if applyNegativeImpact, goal.negativeImpact > 0, let sphereID = goal.sphereID {
            let fetch = FetchDescriptor<Sphere>(predicate: #Predicate<Sphere> { $0.id == sphereID })
            if let sphere = try? modelContext.fetch(fetch).first {
                sphere.satisfaction = max(0.0, min(100.0, sphere.satisfaction - goal.negativeImpact))
            }
        }
        goal.updateStatus(to: .archived)
        try? modelContext.save()
        NotificationCenter.default.postAppEvent(.goalStatusDidChange)
        NotificationCenter.default.postAppEvent(.sphereSatisfactionDidChange)
    }
    
    private func moveGoals(from source: IndexSet, to destination: Int) {
        hapticManager.playHaptic(style: .medium)
        
        // Важно: `filteredAndSortedGoals` может быть под фильтрами (completed/archived/tag/sphere/search).
        // Если переиндексировать только подмножество, остальные цели сохранят старые `orderIndex`,
        // из-за чего при смене статуса/фильтра карточки «прыгают» (часто улетают наверх).
        var reorderedFiltered = filteredAndSortedGoals
        reorderedFiltered.move(fromOffsets: source, toOffset: destination)
        
        // 1) Новый порядок: сначала текущий (видимый) блок после dnd,
        // 2) затем все остальные цели в их текущем порядке.
        let allByID = Dictionary(uniqueKeysWithValues: allGoals.map { ($0.id, $0) })
        let reorderedIDs = reorderedFiltered.map { $0.id }
        let reorderedSet = Set(reorderedIDs)
        
        var newOrderIDs: [UUID] = []
        newOrderIDs.append(contentsOf: reorderedIDs)
        
        for goal in allGoals.sorted(by: { $0.orderIndex < $1.orderIndex }) {
            if !reorderedSet.contains(goal.id) {
                newOrderIDs.append(goal.id)
            }
        }
        
        for (index, id) in newOrderIDs.enumerated() {
            allByID[id]?.orderIndex = index
        }
        
        try? modelContext.save()
        NotificationCenter.default.postAppEvent(.goalStatusDidChange)
        withAnimation(.smooth(duration: 0.4)) {
            goalsOrderKey = UUID()
        }
    }
    
    var body: some View {
        NavigationStack {
            mainContent
                .background {
                    Color(UIColor.systemGroupedBackground)
                        .ignoresSafeArea(edges: .top)
                }
                .sheet(isPresented: $showEditGoalView) {
                    EditGoalView(goalToEdit: $goalToEdit, allGoalsCount: allGoalsCount) { date in
                        if let date = date, globalCalendarVisibility {
                            calendarManager.selectedDate = date
                        }
                    }
                }
                .onAppear {
                    setupInitialState()
                    // Load persisted flag
                    localShowCompletedGoals = goalsSettings.showCompletedGoals
                    localShowArchivedGoals = goalsSettings.showArchivedGoals
                }
                .sheet(isPresented: $showSettingsSheet) {
                    SettingsView()
                }
                .overlay {
                    if showDeleteGoalConfirmation, let goal = goalPendingDeletion {
                        ImpactActionPresenter.dialog(
                            isPresented: $showDeleteGoalConfirmation,
                            spheres: spheres,
                            sphereID: goal.sphereID,
                            negativeImpact: goal.negativeImpact,
                            title: "Delete goal?",
                            message: "This goal will be permanently deleted.",
                            messageWithImpact: "Delete this goal. You can also apply its miss decrease to the area.",
                            primaryTitle: "Delete",
                            primaryTint: .red,
                            secondaryTitleFormat: "Delete and apply negative impact (-%@%%) on area",
                            secondaryTint: .red,
                            onPrimary: {
                                hapticManager.itemDeleted()
                                goalPendingDeletion = nil
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    deleteGoalAndOptionallyApplyNegativeImpact(goal, applyNegativeImpact: false)
                                }
                            },
                            onSecondary: {
                                hapticManager.itemDeleted()
                                goalPendingDeletion = nil
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    deleteGoalAndOptionallyApplyNegativeImpact(goal, applyNegativeImpact: true)
                                }
                            },
                            onCancel: { goalPendingDeletion = nil }
                        )
                    }
                }
                .overlay {
                    if showArchiveGoalConfirmation, let goal = goalPendingArchive {
                        let isArchived = goal.status == .archived
                        ImpactActionPresenter.dialog(
                            isPresented: $showArchiveGoalConfirmation,
                            spheres: spheres,
                            sphereID: goal.sphereID,
                            negativeImpact: goal.negativeImpact,
                            allowSecondaryAction: !isArchived,
                            title: isArchived ? "Unarchive goal?" : "Archive goal?",
                            message: isArchived ? "This goal will return to the active list." : "This goal will be archived.",
                            messageWithImpact: "Archive this goal. You can also apply its miss decrease to the area.",
                            primaryTitle: isArchived ? "Unarchive" : "Archive",
                            primaryTint: .gray,
                            secondaryTitleFormat: "Archive and apply negative impact (-%@%%) on area",
                            secondaryTint: .gray,
                            onPrimary: {
                                hapticManager.selectionChanged()
                                goalPendingArchive = nil
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    withAnimation(.smooth(duration: 0.4)) {
                                        if isArchived {
                                            goal.updateStatus(to: .pending)
                                            try? modelContext.save()
                                            NotificationCenter.default.postAppEvent(.goalStatusDidChange)
                                        } else {
                                            archiveGoalAndOptionallyApplyNegativeImpact(goal, applyNegativeImpact: false)
                                        }
                                    }
                                }
                            },
                            onSecondary: {
                                hapticManager.selectionChanged()
                                goalPendingArchive = nil
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    withAnimation(.smooth(duration: 0.4)) {
                                        archiveGoalAndOptionallyApplyNegativeImpact(goal, applyNegativeImpact: true)
                                    }
                                }
                            },
                            onCancel: { goalPendingArchive = nil }
                        )
                    }
                }
                .onChange(of: (appDesignSettings.first?.design ?? .basic)) { _, newValue in
                    allGoalsDesign = (newValue == .basic) ? .basic : .rainbow
                }
                .onReceive(NotificationCenter.default.publisher(for: .appDesignDidChange)) { _ in
                    if let global = appDesignSettings.first {
                        allGoalsDesign = (global.design == .basic) ? .basic : .rainbow
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .appCalendarVisibilityDidChange)) { _ in
                    calendarManager.isVisible = globalCalendarVisibility
                }
                .onReceive(NotificationCenter.default.publisher(for: .goalStatusDidChange)) { _ in
                    // Как `AllTasksView` / `.taskStatusDidChange`: тот же spring для смены ключа порядка.
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        goalsOrderKey = UUID()
                    }
                }
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            // Верхняя полоса: общий компонент `MainTabHeaderRow` (см. `MainTabChrome.swift`).
            MainTabHeaderRow(
                showSearchBar: showSearchBar,
                calendarVisible: globalCalendarVisibility,
                searchContent: { searchBarSection },
                calendarContent: {
                    calendarView(
                        selectedDate: $calendarManager.selectedDate,
                        weekStartDate: $calendarManager.weekStartDate,
                        isVisible: globalCalendarVisibilityBinding
                    )
                },
                menuContent: {
                    addGoalButton
                    Divider()
                    filterMenu
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

            goalsList
        }
    }
    
    @ViewBuilder
    private var goalsList: some View {
        if filteredAndSortedGoals.isEmpty {
            emptyStateView
        } else {
            List {
                ForEach(filteredAndSortedGoals) { goal in
                    goalRowView(for: goal)
                        .id(goal.id)
                }
                .onMove(perform: moveGoals)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.smooth(duration: 0.4), value: filteredAndSortedGoals.map { "\($0.id)-\($0.status.rawValue)" })
            .animation(.smooth(duration: 0.4), value: goalsOrderKey)
        }
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        EmptyStateView.noGoals()
            .tabEmptyStateLayout()
    }
    
    
    private func setupInitialState() {
        // Ensure a single global settings object
        if appDesignSettings.count > 1 {
            if let keep = appDesignSettings.first {
                for extra in appDesignSettings.dropFirst() { modelContext.delete(extra) }
                try? modelContext.save()
                allGoalsDesign = (keep.design == .basic) ? .basic : .rainbow
            }
        }
        // Default to Basic, but sync with global if available
        if let global = appDesignSettings.first {
            allGoalsDesign = (global.design == .basic) ? .basic : .rainbow
        } else {
            allGoalsDesign = .basic // Default to Basic
        }
    }
    
    private var emptyAllGoalsView: some View {
        VStack(spacing: 24) {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: "target")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)
                Text("Goals help your spheres grow.\nLet's create one!")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }
}
