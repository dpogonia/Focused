import SwiftUI
import SwiftData

// MARK: - TASKS VIEW
struct AllTasksView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\SuperTask.orderIndex, order: .forward), SortDescriptor(\SuperTask.priority, order: .reverse)]) private var allSuperTasks: [SuperTask]
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
    @State private var design: TasksViewDesign = .basic
    @Query private var appDesignSettings: [AppDesignSettings]
    @Query private var appCalendarSettings: [AppCalendarSettings]
    @State private var selectedPriority: SuperTask.PriorityEnum? = nil
    @State private var selectedStatus: SuperTask.Status? = nil
    @State private var showSearchBar: Bool = false
    @StateObject private var compactCalendarManager = CalendarManager()
    @State private var showSettingsSheet: Bool = false
    @State private var safeAreaTop: CGFloat = 0
    @State private var tasksOrderKey: UUID = UUID()
    
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
    
    private var settings: TasksSettings {
        if appSettings.isEmpty {
            let newSettings = TasksSettings()
            modelContext.insert(newSettings)
            return newSettings
        }
        return appSettings[0]
    }
    
    private var filteredAndSortedTasks: [SuperTask] {
        var tempTasks = allSuperTasks
        
        // Calendar filtering
        if globalCalendarVisibility {
            let calendarFilter = TasksCalendarFilter(tasks: tempTasks)
            tempTasks = calendarFilter.filterForDate(compactCalendarManager.selectedDate)
        }
        
        if !searchText.isEmpty {
            tempTasks = tempTasks.filter { $0.title.lowercased().contains(searchText.lowercased()) || ($0.descript?.lowercased().contains(searchText.lowercased()) ?? false) }
        }
        
        if let selectedSphereID = selectedSphereID {
            tempTasks = tempTasks.filter { $0.sphereID == selectedSphereID }
        }
        
        if let selectedTag = selectedTag {
            tempTasks = tempTasks.filter { $0.tags.contains(where: { $0.name == selectedTag }) }
        }
        
        if let selectedPriority = selectedPriority {
            tempTasks = tempTasks.filter { $0.priorityEnum == selectedPriority }
        }
        
        if let selectedStatus = selectedStatus {
            tempTasks = tempTasks.filter { $0.statusEnum == selectedStatus }
        }
        
        // Filter completed tasks
        if !localShowCompletedTasks {
            tempTasks = tempTasks.filter { $0.statusEnum != .completed && $0.statusEnum != .cancelled }
        }
        
        tempTasks.sort { t1, t2 in
            if t1.statusEnum != t2.statusEnum {
                return t1.statusEnum < t2.statusEnum
            }
            if t1.priority != t2.priority {
                return t1.priority > t2.priority
            }
            if let due1 = t1.dueDate, let due2 = t2.dueDate {
                return due1 < due2
            }
            return t1.orderIndex < t2.orderIndex
        }
        
        return tempTasks
    }
    
    private var uniqueTags: [String] {
        Set(allSuperTasks.flatMap { $0.tags.map { $0.name } }).sorted()
    }
    
    private var hasActiveFilters: Bool {
        selectedPriority != nil || selectedStatus != nil || selectedSphereID != nil || selectedTag != nil
    }
    
    
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: Calendar and Menu HStack
                HStack(spacing: 0) {
                    if showSearchBar {
                        SearchBarView(searchText: $searchText, isVisible: $showSearchBar, placeholder: "Search tasks...")
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
                                Label(showSearchBar ? "Hide Search" : "Search Tasks", systemImage: "magnifyingglass")
                            }
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
                                    let completedTasksCount = allSuperTasks.filter { $0.statusEnum == .completed || $0.statusEnum == .cancelled }.count
                                    if completedTasksCount > 0 {
                                        Label("Show Completed (\(completedTasksCount))", systemImage: "eye")
                                    } else {
                                        Label("Show Completed", systemImage: "eye")
                                    }
                                }
                            }
                            Menu("Filter by Sphere") {
                                Button {
                                    hapticManager.selectionChanged()
                                    withAnimation { selectedSphereID = nil }
                                } label: {
                                    HStack {
                                        Text("All Spheres")
                                        Spacer()
                                        if selectedSphereID == nil { Image(systemName: "checkmark") }
                                    }
                                }
                                ForEach(spheres) { sphere in
                                    Button {
                                        hapticManager.selectionChanged()
                                        withAnimation { selectedSphereID = sphere.id }
                                    } label: {
                                        HStack {
                                            Text(sphere.title)
                                            Spacer()
                                            if selectedSphereID == sphere.id { Image(systemName: "checkmark") }
                                        }
                                    }
                                }
                            }
                            Menu("Filter by Priority") {
                                Button {
                                    hapticManager.selectionChanged()
                                    selectedPriority = nil
                                } label: {
                                    HStack {
                                        Text("All Priorities")
                                        Spacer()
                                        if selectedPriority == nil { Image(systemName: "checkmark") }
                                    }
                                }
                                ForEach(SuperTask.PriorityEnum.allCases, id: \.self) { priority in
                                    Button {
                                        hapticManager.selectionChanged()
                                        selectedPriority = priority
                                    } label: {
                                        HStack {
                                            Text(priority.displayString)
                                            Spacer()
                                            if selectedPriority == priority { Image(systemName: "checkmark") }
                                        }
                                    }
                                }
                            }
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
                            Menu("Filter by Tag") {
                                Button {
                                    hapticManager.selectionChanged()
                                    selectedTag = nil
                                } label: {
                                    HStack {
                                        Text("All Tags")
                                        Spacer()
                                        if selectedTag == nil { Image(systemName: "checkmark") }
                                    }
                                }
                                ForEach(uniqueTags, id: \.self) { tag in
                                    Button {
                                        selectedTag = tag
                                        hapticManager.selectionChanged()
                                    } label: {
                                        HStack {
                                            Text(tag)
                                            Spacer()
                                            if selectedTag == tag { Image(systemName: "checkmark") }
                                        }
                                    }
                                }
                            }
                            if hasActiveFilters {
                                Button("Clear All Filters") {
                                    hapticManager.selectionChanged()
                                    withAnimation {
                                        selectedPriority = nil
                                        selectedStatus = nil
                                        selectedSphereID = nil
                                        selectedTag = nil
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
                
                if filteredAndSortedTasks.isEmpty {
                    EmptyStateView.noTasks()
                        .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - 200)
                        .background(Color(UIColor.systemGroupedBackground))
                } else {
                    List {
                        ForEach(filteredAndSortedTasks, id: \.id) { task in
                            TaskCardView(task: task, onEdit: {
                                taskToEdit = task
                                showAddTaskView = true
                            })
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 1)
                            .background(Color.clear)
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .move(edge: .bottom).combined(with: .opacity)
                            ))
                            .onDrag {
                                NSItemProvider(object: task.id.uuidString as NSString)
                            }
                            .onDrop(of: [.text], delegate: TaskDropDelegate(task: task, tasks: filteredAndSortedTasks, modelContext: modelContext))
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: filteredAndSortedTasks.map { "\($0.id)-\($0.statusEnum.rawValue)" })
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: tasksOrderKey)
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .ignoresSafeArea(edges: .top)
            .sheet(isPresented: $showAddTaskView) {
                AddEditTaskView(taskToEdit: $taskToEdit, allTasksCount: allSuperTasks.count)
            }
            .onAppear {
                updateSafeAreaTop()
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
                compactCalendarManager.isVisible = globalCalendarVisibility
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
            
        }
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
