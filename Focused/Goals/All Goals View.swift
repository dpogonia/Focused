import SwiftUI
import SwiftData

// MARK: - ALL GOALS VIEW
struct AllGoalsView: View {
    @Environment(\.modelContext) private var modelContext
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
    @State private var allGoalsDesign: AllGoalsViewDesign = .basic
    @State private var showSearchBar: Bool = false
    @StateObject private var calendarManager = CalendarManager()
    @State private var showSettingsSheet: Bool = false
    @State private var safeAreaTop: CGFloat = 0
    @State private var goalsOrderKey: UUID = UUID()
    
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
    
    private var goalsSettings: GoalsSettings {
        if appSettings.isEmpty {
            let newSettings = GoalsSettings()
            modelContext.insert(newSettings)
            return newSettings
        }
        return appSettings[0]
    }
    
    private var filteredAndSortedGoals: [Goal] {
        var tempGoals = allGoals
        
        // Calendar filtering
        if globalCalendarVisibility {
            let calendarFilter = GoalsCalendarFilter(goals: tempGoals)
            tempGoals = calendarFilter.filterForDate(calendarManager.selectedDate)
        }
        
        if !searchText.isEmpty {
            tempGoals = tempGoals.filter { $0.title.lowercased().contains(searchText.lowercased()) || ($0.descript?.lowercased().contains(searchText.lowercased()) ?? false) }
        }
        
        if let selectedSphereID = selectedSphereID {
            tempGoals = tempGoals.filter { $0.sphereID == selectedSphereID }
        }
        
        if let selectedTag = selectedTag {
            tempGoals = tempGoals.filter { $0.tags.contains(where: { $0.name == selectedTag }) }
        }
        
        let applyCompletionFilter = selectedSphereID == nil && !localShowCompletedGoals
        if applyCompletionFilter {
            tempGoals = tempGoals.filter { $0.status != .completed && $0.status != .missed }
        }
        
        tempGoals.sort { g1, g2 in
            if g1.isFlagged != g2.isFlagged {
                return g1.isFlagged && !g2.isFlagged
            }
            // Выполненные и пропущенные цели внизу
            let g1IsCompleted = g1.status == .completed || g1.status == .missed
            let g2IsCompleted = g2.status == .completed || g2.status == .missed
            if g1IsCompleted != g2IsCompleted {
                return !g1IsCompleted && g2IsCompleted
            }
            if g1.status != g2.status {
                return g1.status < g2.status
            }
            if let due1 = g1.dueDate, let due2 = g2.dueDate {
                return due1 < due2
            }
            return g1.orderIndex < g2.orderIndex
        }
        
        return tempGoals
    }
    
    private var uniqueTags: [String] {
        Set(allGoals.flatMap { $0.tags.map { $0.name } }).sorted()
    }
    
    private var allGoalsCount: Int {
        (try? modelContext.fetchCount(FetchDescriptor<Goal>())) ?? 0
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
            placeholder: "Search goals..."
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
        Button {
            hapticManager.selectionChanged()
            withAnimation {
                localShowCompletedGoals.toggle()
                goalsSettings.showCompletedGoals = localShowCompletedGoals
                try? modelContext.save()
            }
        } label: {
            Label(localShowCompletedGoals ? "Hide Completed" : "Show Completed", systemImage: localShowCompletedGoals ? "eye.slash" : "eye")
        }
    }
    
    @ViewBuilder
    private var filterMenu: some View {
        Menu("Filter") {
            searchButton
            completedGoalsButton
            sphereFilterMenu
            tagFilterMenu
        }
    }
    
    @ViewBuilder
    private var sphereFilterMenu: some View {
        Menu("Filter by Sphere") {
            ForEach(spheres) { sphere in
                Button {
                    selectedSphereID = sphere.id
                } label: {
                    HStack {
                        Text(sphere.title)
                        Spacer()
                        if selectedSphereID == sphere.id { Image(systemName: "checkmark") }
                    }
                }
            }
            Button {
                selectedSphereID = nil
            } label: {
                HStack {
                    Text("Clear Filter")
                    Spacer()
                    if selectedSphereID == nil { Image(systemName: "checkmark") }
                }
            }
        }
    }
    
    @ViewBuilder
    private var tagFilterMenu: some View {
        Menu("Filter by Tag") {
            ForEach(uniqueTags, id: \.self) { tag in
                Button {
                    selectedTag = tag
                } label: {
                    HStack {
                        Text(tag)
                        Spacer()
                        if selectedTag == tag { Image(systemName: "checkmark") }
                    }
                }
            }
            Button {
                selectedTag = nil
            } label: {
                HStack {
                    Text("Clear Filter")
                    Spacer()
                    if selectedTag == nil { Image(systemName: "checkmark") }
                }
            }
        }
    }
    
    @ViewBuilder
    private func goalRowView(for goal: Goal) -> some View {
        GoalCardView(goal: goal, goalDesign: allGoalsDesign) {
            hapticManager.openPage()
            goalToEdit = goal
            showEditGoalView = true
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
        .onDrag {
            NSItemProvider(object: goal.id.uuidString as NSString)
        }
        .onDrop(of: [.text], delegate: GoalDropDelegate(goal: goal, goals: filteredAndSortedGoals, modelContext: modelContext))
    }
    
    @ViewBuilder
    private func leadingSwipeButton(for goal: Goal) -> some View {
        let status = goal.status
        Button {
            hapticManager.playHaptic(style: .light)
            //let oldStatus = goal.status
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
                //let oldStatus = goal.status
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
                showEditGoalView = true
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
        }
    }
    
    var body: some View {
        NavigationStack {
            mainContent
                .background(Color(UIColor.systemGroupedBackground))
                .ignoresSafeArea(edges: .top)
                .sheet(isPresented: $showEditGoalView) {
                    EditGoalView(goalToEdit: $goalToEdit, allGoalsCount: allGoalsCount)
                }
                .onAppear {
                    updateSafeAreaTop()
                    setupInitialState()
                    // Load persisted flag
                    localShowCompletedGoals = goalsSettings.showCompletedGoals
                }
                .sheet(isPresented: $showSettingsSheet) {
                    SettingsView()
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
                    // Обновляем ключ для триггера анимации перемещения карточек
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        goalsOrderKey = UUID()
                    }
                }
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            // MARK: Calendar and Menu HStack
            HStack(spacing: 0) {
                if showSearchBar {
                    searchBarSection
                } else {
                    calendarView(
                        selectedDate: $calendarManager.selectedDate,
                        weekStartDate: $calendarManager.weekStartDate,
                        isVisible: globalCalendarVisibilityBinding
                    )
                    .opacity(globalCalendarVisibility ? 1 : 0)
                    .allowsHitTesting(globalCalendarVisibility && !showSearchBar)
                    .animation(.easeInOut(duration: 0.25), value: globalCalendarVisibility)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                EllipsisMenuButton {
                    addGoalButton
                    Divider()
                    filterMenu
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
            
            goalsList
        }
    }
    
    @ViewBuilder
    private var goalsList: some View {
        if filteredAndSortedGoals.isEmpty {
            emptyStateView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(filteredAndSortedGoals) { goal in
                    goalRowView(for: goal)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: filteredAndSortedGoals.map { "\($0.id)-\($0.status.rawValue)" })
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: goalsOrderKey)
        }
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        EmptyStateView.noGoals()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(UIColor.systemGroupedBackground))
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
