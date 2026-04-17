import SwiftUI
import SwiftData

// Presentation · Tasks — главный список задач; фильтрация через `TasksViewModel` → `FilterTasksUseCase`, счётчики — `tasksRepository` из `AppDependencies`.

// MARK: - Экран «Все задачи» (Presentation)
//
// Архитектура как у `AllGoalsView`: MVVM + `FilterTasksUseCase` + `TasksRepository` для `fetchCount`.

// MARK: - TASKS VIEW
struct AllTasksView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appDependencies) private var appDependencies
    @Query(sort: [SortDescriptor(\SuperTask.orderIndex, order: .forward)]) private var allSuperTasks: [SuperTask]
    @Query private var appSettings: [TasksSettings]
    @Query private var spheres: [Sphere]
    
    @State private var searchText: String = ""
    @State private var showAddTaskView: Bool = false
    @State private var taskToEdit: SuperTask?
    @State private var selectedDate: Date = .now
    @State private var swipedTaskID: UUID?
    @State private var selectedSphereID: UUID? = nil
    @State private var selectedTag: String? = nil
    @State private var localShowCompletedTasks: Bool = true
    @State private var localShowArchivedTasks: Bool = false
    @State private var design: TasksViewDesign = .basic
    @Query private var appDesignSettings: [AppDesignSettings]
    @Query private var appCalendarSettings: [AppCalendarSettings]
    @State private var selectedStatus: SuperTask.Status? = nil
    @State private var showSearchBar: Bool = false
    @EnvironmentObject private var calendarManager: CalendarManager
    @State private var showSettingsSheet: Bool = false
    @State private var tasksOrderKey: UUID = UUID()
    @StateObject private var viewModel: TasksViewModel
    @State private var showDeleteTaskConfirmation: Bool = false
    @State private var taskPendingDeletion: SuperTask?
    @State private var showArchiveTaskConfirmation: Bool = false
    @State private var taskPendingArchive: SuperTask?
    
    private let hapticManager = HapticSoundManager.shared

    /// См. комментарий к `resolvedDependencies` в `AllGoalsView`.
    private var resolvedDependencies: AppDependencies {
        if let appDependencies {
            return appDependencies
        }
        return AppDependencies.live(modelContext: modelContext)
    }

    init() {
        _viewModel = StateObject(wrappedValue: TasksViewModel())
    }
    
    
    private var settings: TasksSettings {
        if appSettings.isEmpty {
            let newSettings = TasksSettings()
            modelContext.insert(newSettings)
            return newSettings
        }
        return appSettings[0]
    }
    
    private var filteredAndSortedTasks: [SuperTask] {
        viewModel.filteredTasks(
            allTasks: allSuperTasks,
            selectedDate: calendarManager.selectedDate,
            calendarVisible: globalCalendarVisibility,
            searchText: searchText,
            selectedSphereID: selectedSphereID,
            selectedTag: selectedTag,
            selectedStatus: selectedStatus,
            localShowCompletedTasks: localShowCompletedTasks,
            localShowArchivedTasks: localShowArchivedTasks
        )
    }
    
    private var uniqueTags: [String] {
        Set(allSuperTasks.flatMap { $0.tags.map { $0.name } }).sorted()
    }

    private var hasAnyCompletedTasks: Bool {
        allSuperTasks.contains { $0.statusEnum == .completed }
    }
    
    private var hasAnyArchivedTasks: Bool {
        allSuperTasks.contains { $0.statusEnum == .archived }
    }
    
    private var hasActiveFilters: Bool {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty || selectedStatus != nil || selectedSphereID != nil || selectedTag != nil
    }

    @ViewBuilder
    private var deleteTaskConfirmationOverlay: some View {
        if showDeleteTaskConfirmation, let task = taskPendingDeletion {
            ImpactActionPresenter.dialog(
                isPresented: $showDeleteTaskConfirmation,
                spheres: spheres,
                sphereID: task.sphereID,
                negativeImpact: task.negativeImpact,
                title: "Delete task?",
                message: "This task and its subtasks will be permanently deleted.",
                messageWithImpact: "Delete this task. You can also apply its miss decrease to the area.",
                primaryTitle: "Delete",
                primaryTint: .red,
                secondaryTitleFormat: "Delete and apply negative impact (-%@%%) on area",
                secondaryTint: .red,
                onPrimary: {
                    hapticManager.itemDeleted()
                    taskPendingDeletion = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        deleteTaskAndOptionallyApplyNegativeImpact(task, applyNegativeImpact: false)
                    }
                },
                onSecondary: {
                    hapticManager.itemDeleted()
                    taskPendingDeletion = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        deleteTaskAndOptionallyApplyNegativeImpact(task, applyNegativeImpact: true)
                    }
                },
                onCancel: { taskPendingDeletion = nil }
            )
        }
    }

    @ViewBuilder
    private var archiveTaskConfirmationOverlay: some View {
        if showArchiveTaskConfirmation, let task = taskPendingArchive {
            ImpactActionPresenter.dialog(
                isPresented: $showArchiveTaskConfirmation,
                spheres: spheres,
                sphereID: task.sphereID,
                negativeImpact: task.negativeImpact,
                title: "Archive task?",
                message: "This task will be archived.",
                messageWithImpact: "Archive this task. You can also apply its miss decrease to the area.",
                primaryTitle: "Archive",
                primaryTint: .gray,
                secondaryTitleFormat: "Archive and apply negative impact (-%@%%) on area",
                secondaryTint: .gray,
                onPrimary: {
                    hapticManager.selectionChanged()
                    taskPendingArchive = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation(.smooth(duration: 0.4)) {
                            archiveTaskAndOptionallyApplyNegativeImpact(task, applyNegativeImpact: false)
                        }
                    }
                },
                onSecondary: {
                    hapticManager.selectionChanged()
                    taskPendingArchive = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation(.smooth(duration: 0.4)) {
                            archiveTaskAndOptionallyApplyNegativeImpact(task, applyNegativeImpact: true)
                        }
                    }
                },
                onCancel: { taskPendingArchive = nil }
            )
        }
    }
    
    
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MainTabHeaderRow(
                    showSearchBar: showSearchBar,
                    calendarVisible: globalCalendarVisibility,
                    searchContent: {
                        SearchBarView(searchText: $searchText, isVisible: $showSearchBar, placeholder: "search tasks...")
                    },
                    calendarContent: {
                        calendarView(
                            selectedDate: $calendarManager.selectedDate,
                            weekStartDate: $calendarManager.weekStartDate,
                            isVisible: globalCalendarVisibilityBinding
                        )
                    },
                    menuContent: {
                        // Add Task on top
                        Button {
                            hapticManager.openPage()
                            taskToEdit = nil
                            showAddTaskView = true
                        } label: {
                            Label("Add Task", systemImage: "plus.circle")
                        }
                        Divider()
                        
                        // Group all filters under a nested menu
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
                                Label(showSearchBar ? "Hide Search" : "Search Tasks", systemImage: "magnifyingglass")
                            }
                            
                            if hasAnyCompletedTasks {
                                Button {
                                    hapticManager.selectionChanged()
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        localShowCompletedTasks.toggle()
                                        settings.showCompletedTasks = localShowCompletedTasks
                                        try? modelContext.save()
                                    }
                                } label: {
                                    if localShowCompletedTasks {
                                        Label("Hide Completed", systemImage: "eye.slash")
                                    } else {
                                        let completedTasksCount = allSuperTasks.filter { $0.statusEnum == .completed }.count
                                        Label("Show Completed (\(completedTasksCount))", systemImage: "eye")
                                    }
                                }
                            }
                            
                            if hasAnyArchivedTasks {
                                Button {
                                    hapticManager.selectionChanged()
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        localShowArchivedTasks.toggle()
                                        settings.showArchivedTasks = localShowArchivedTasks
                                        try? modelContext.save()
                                    }
                                } label: {
                                    Label(
                                        localShowArchivedTasks ? "Hide Archived" : "Show Archived",
                                        systemImage: localShowArchivedTasks ? "archivebox.fill" : "archivebox"
                                    )
                                }
                            }
                            MainTabFilterMenus.sphereSubmenu(
                                spheres: spheres,
                                selectedSphereID: Binding(
                                    get: { selectedSphereID },
                                    set: { newValue in
                                        hapticManager.selectionChanged()
                                        withAnimation { selectedSphereID = newValue }
                                    }
                                )
                            )
                            Menu("Filter by Status") {
                                Button {
                                    hapticManager.selectionChanged()
                                    selectedStatus = nil
                                } label: {
                                    HStack {
                                        Text("All Statuses")
                                        Spacer()
                                        if selectedStatus == nil { Image(systemName: "checkmark") }
                                    }
                                }
                                ForEach(SuperTask.Status.allCases, id: \.self) { status in
                                    Button {
                                        hapticManager.selectionChanged()
                                        selectedStatus = status
                                    } label: {
                                        HStack {
                                            Text(status.displayString)
                                            Spacer()
                                            if selectedStatus == status { Image(systemName: "checkmark") }
                                        }
                                    }
                                }
                            }
                            MainTabFilterMenus.tagSubmenu(
                                tags: uniqueTags,
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
                                    selectedStatus = nil
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

                if filteredAndSortedTasks.isEmpty {
                    EmptyStateView.noTasks()
                        .tabEmptyStateLayout()
                } else {
                    List {
                        ForEach(filteredAndSortedTasks, id: \.id) { task in
                            TaskCardView(task: task, onEdit: {
                                taskToEdit = task
                                showAddTaskView = true
                            }, onRequestDelete: { t in
                                taskPendingDeletion = t
                                showDeleteTaskConfirmation = true
                            }, onRequestArchive: { t in
                                taskPendingArchive = t
                                showArchiveTaskConfirmation = true
                            })
                            .id(task.id)
                            .mainTabListCardRowChrome()
                            .mainTabListCardRowSwipeClipping()
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .move(edge: .bottom).combined(with: .opacity)
                            ))
                        }
                        .onMove(perform: moveTasks)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .scrollIndicators(.hidden)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .animation(.smooth(duration: 0.4), value: filteredAndSortedTasks.map { "\($0.id)-\($0.statusEnum.rawValue)" })
                    .animation(.smooth(duration: 0.4), value: tasksOrderKey)
                }
            }
            .background {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea(edges: .top)
            }
            .sheet(isPresented: $showAddTaskView) {
                AddEditTaskView(taskToEdit: $taskToEdit, allTasksCount: (try? resolvedDependencies.tasksRepository.fetchCount()) ?? allSuperTasks.count)
            }
            .onAppear {
                // Ensure a single global settings object
                if appDesignSettings.count > 1 {
                    if let keep = appDesignSettings.first {
                        for extra in appDesignSettings.dropFirst() { modelContext.delete(extra) }
                        try? modelContext.save()
                        design = (keep.design == .basic) ? .basic : .rainbow
                    }
                }
                // Default to Basic, but sync with global if available
                if let global = appDesignSettings.first {
                    design = (global.design == .basic) ? .basic : .rainbow
                } else {
                    design = .basic // Default to Basic
                }
                // Load persisted visibility of completed tasks
                localShowCompletedTasks = settings.showCompletedTasks
                localShowArchivedTasks = settings.showArchivedTasks
            }
            .onChange(of: design) { oldValue, newValue in
                hapticManager.selectionChanged()
                settings.design = newValue
                // Propagate to app-wide settings
                let global = appDesignSettings.first ?? {
                    let s = AppDesignSettings()
                    modelContext.insert(s)
                    return s
                }()
                global.design = (newValue == .basic) ? .basic : .rainbow
                try? modelContext.save()
            }
            // Live sync if global changes elsewhere
            .onChange(of: (appDesignSettings.first?.design ?? .basic)) { _, newValue in
                let mapped: TasksViewDesign = (newValue == .basic) ? .basic : .rainbow
                design = mapped
                settings.design = mapped
            }
            // Listen notification to force immediate UI update across tabs
            .onReceive(NotificationCenter.default.publisher(for: .appDesignDidChange)) { _ in
                if let global = appDesignSettings.first {
                    let mapped: TasksViewDesign = (global.design == .basic) ? .basic : .rainbow
                    design = mapped
                    settings.design = mapped
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .appCalendarVisibilityDidChange)) { _ in
                calendarManager.isVisible = globalCalendarVisibility
            }
            .onReceive(NotificationCenter.default.publisher(for: .taskStatusDidChange)) { _ in
                // Обновляем ключ для триггера анимации перемещения карточек
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    tasksOrderKey = UUID()
                }
            }
            .sheet(isPresented: $showSettingsSheet) {
                SettingsView()
            }
            .overlay { deleteTaskConfirmationOverlay }
            .overlay { archiveTaskConfirmationOverlay }
            
        }
    }

    private func deleteTaskAndOptionallyApplyNegativeImpact(_ task: SuperTask, applyNegativeImpact: Bool) {
        if applyNegativeImpact, task.negativeImpact > 0, let sphereID = task.sphereID {
            let fetch = FetchDescriptor<Sphere>(predicate: #Predicate<Sphere> { $0.id == sphereID })
            if let sphere = try? modelContext.fetch(fetch).first {
                sphere.satisfaction = max(0.0, min(100.0, sphere.satisfaction - task.negativeImpact))
            }
        }
        modelContext.delete(task)
        try? modelContext.save()
        NotificationCenter.default.postAppEvent(.taskStatusDidChange)
        NotificationCenter.default.postAppEvent(.sphereSatisfactionDidChange)
    }

    private func archiveTaskAndOptionallyApplyNegativeImpact(_ task: SuperTask, applyNegativeImpact: Bool) {
        if applyNegativeImpact, task.negativeImpact > 0, let sphereID = task.sphereID {
            let fetch = FetchDescriptor<Sphere>(predicate: #Predicate<Sphere> { $0.id == sphereID })
            if let sphere = try? modelContext.fetch(fetch).first {
                sphere.satisfaction = max(0.0, min(100.0, sphere.satisfaction - task.negativeImpact))
            }
        }
        task.updateStatus(to: .archived)
        try? modelContext.save()
        NotificationCenter.default.postAppEvent(.taskStatusDidChange)
        NotificationCenter.default.postAppEvent(.sphereSatisfactionDidChange)
    }
    
    private func moveTasks(from source: IndexSet, to destination: Int) {
        var tasks = filteredAndSortedTasks
        tasks.move(fromOffsets: source, toOffset: destination)
        
        for (index, task) in tasks.enumerated() {
            task.orderIndex = index
        }
        try? modelContext.save()
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
}
