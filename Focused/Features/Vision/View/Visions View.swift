import SwiftUI
import SwiftData

// MARK: - Вкладка Vision (View)
//
// Визуализации сфер жизни + AI-тексты. Данные через `@Query`.
// Логика — `VisionsViewModel.swift` в этой же папке `Features/Vision/View/`; **Facade** `SphereSatisfactionFacade` + `VisionAnalyticsServicing`.
// Переключение других вкладок с этого экрана: `@EnvironmentObject var rootCoordinator: RootCoordinator` + `selectTab(...)`.

// MAIN VISION TAB VIEW
struct VisionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Sphere.orderIndex) private var spheres: [Sphere]
    @Query(sort: \Habit.orderIndex) private var habits: [Habit]
    @Query private var tasks: [SuperTask]
    @Query private var goals: [Goal]
    @Query private var memoItems: [MemoItem]
    @Query private var visionsSettings: [VisionsSettings]
    @Query private var appDesignSettings: [AppDesignSettings]
    @Query private var appCalendarSettings: [AppCalendarSettings]
    
    @State private var sphereToEdit: Sphere?
    @State private var showAddEditSheet: Bool = false
    @State private var selectedSphere: Sphere? = nil
    @State private var selectedVisionType: AIType = .analyticsAI
    @State private var selectedCategory: segmentedCategory = .goals
    @State private var isGenerating: Bool = false
    @State private var visionsStyle: VisionsStyle = .circle
    @State private var bottomPagerIndex: Int = 0
    @State private var linearSortDescending: Bool? = nil // nil = по порядку добавления (дефолт)
    @State private var linearHeightMode: LinearHeightMode = .regular
    @State private var barsSortDescending: Bool? = nil // nil = по порядку добавления (дефолт)
    @State private var barsWidthMode: BarsWidthMode = .regular
    @EnvironmentObject private var calendarManager: CalendarManager
    @StateObject private var viewModel = VisionsViewModel()
    private let hapticManager = HapticSoundManager.shared
    @State private var mainVisionTabIndex: Int = 1
    @State private var showSettingsSheet: Bool = false
    @State private var showDashboard: Bool = false
    @State private var showVisionSheet: Bool = false
    @State private var showAnalyticsSheet: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    @State private var sphereToDelete: Sphere? = nil
    @State private var showSphereActionMenu: Bool = false
    @State private var sphereActionMenuTarget: Sphere?
    @State private var isCircleDragging: Bool = false
    @State private var pagerTransition: AnyTransition = .identity
    @State private var barsDragPreviewSphereID: UUID? = nil
    @State private var barsDragPreviewValue: Double? = nil
    @State private var linearDragPreviewSphereID: UUID? = nil
    @State private var linearDragPreviewValue: Double? = nil
    
    enum AIType: String, CaseIterable {
        case analyticsAI = "Analytics"
        case visionAI = "Vision"
    }
    
    enum segmentedCategory: String, CaseIterable {
        case goals = "Goals"
        case tasks = "Tasks"
        case habits = "Habits"
        case memo = "Memo"
    }
    
    // UNIFIED HORIZONTAL PADDING
    private var unifiedSpheresHorizontalPadding: CGFloat {
        return 16
    }
    
    // VISIONS SETTINGS
    private var currentVisionsSettings: VisionsSettings {
        if visionsSettings.isEmpty {
            let newSettings = VisionsSettings()
            modelContext.insert(newSettings)
            return newSettings
        }
        return visionsSettings[0]
    }
    
    // CALENDAR VISIBILITY
    private var calendarVisibility: Bool {
        return appCalendarSettings.first?.isVisible ?? true
    }
    private var calendarVisibilityBinding: Binding<Bool> {
        Binding(
            get: { calendarVisibility },
            set: { newValue in
                let global = appCalendarSettings.first ?? {
                    let s = AppCalendarSettings()
                    modelContext.insert(s)
                    return s
                }()
                global.isVisible = newValue
                try? modelContext.save()
            }
        )
    }

    /// Точка «сегодня» в общем календаре берёт цвет активной сферы (как круг Vision).
    private func syncCalendarAccentSphereID() {
        let global = appCalendarSettings.first ?? {
            let s = AppCalendarSettings()
            modelContext.insert(s)
            return s
        }()
        let effective = selectedSphere ?? spheres.first
        global.accentSphereID = effective?.id
        try? modelContext.save()
    }
    
    // CALCULATE POTENTIAL SPHERE INCREASE
    private func totalPositiveImpact(for sphere: Sphere) -> Double {
        let relatedGoals = goals.filter { $0.sphereID == sphere.id && $0.status != .completed }
        let goalSum = relatedGoals.reduce(0.0) { $0 + max(0.0, $1.positiveImpact) }
        let memoSum: Double = memoItems.reduce(0.0) { partial, memo in
            guard let data = memo.contentData,
                  let content = try? JSONDecoder().decode(MemoCounterContent.self, from: data) else { return partial }
            var total = partial
            if content.sphereID == sphere.id {
                total += max(0.0, content.positiveImpact)
            }
            for imp in content.additionalImpacts where imp.sphereID == sphere.id {
                total += max(0.0, imp.positiveImpact)
            }
            return total
        }
        return goalSum + memoSum
    }
    
    private func presentSphereActionMenu(for sphere: Sphere) {
        hapticManager.selectionChanged()
        sphereActionMenuTarget = sphere
        showSphereActionMenu = true
    }

    private func dismissSphereActionMenu() {
        showSphereActionMenu = false
        sphereActionMenuTarget = nil
    }
    
    private func resetLinearFilters() {
        linearSortDescending = nil // Сброс на сортировку по порядку добавления
    }
    
    private func resetBarsFilters() {
        barsSortDescending = nil // Сброс на сортировку по порядку добавления
        barsWidthMode = .regular
    }
    
    var body: some View {
        NavigationStack {
            visionContainerView()
                .background {
                    Color(UIColor.systemGroupedBackground)
                        .ignoresSafeArea(edges: .top)
                }
                // ADD DEFAULT SPHERES OR SHOW SELECTED SPHERE
                .onAppear {
                    if selectedSphere == nil && !spheres.isEmpty {
                        selectedSphere = spheres.first
                    }
                    visionsStyle = currentVisionsSettings.style
                    calendarManager.isVisible = calendarVisibility
                    syncCalendarAccentSphereID()
                }
                .onChange(of: selectedSphere?.id) { _, _ in
                    syncCalendarAccentSphereID()
                }
                .onChange(of: spheres.count) { _, _ in
                    if selectedSphere == nil, !spheres.isEmpty {
                        selectedSphere = spheres.first
                    }
                    syncCalendarAccentSphereID()
                }
                // HIDES CALENDAR IF TURNED OFF IN SETTINGS
                .onReceive(NotificationCenter.default.publisher(for: .appCalendarVisibilityDidChange)) { _ in
                    calendarManager.isVisible = calendarVisibility
                }
        }
        // Иначе NavigationStack оставляет место под невидимый bar — календарь оказывается ниже, чем на других вкладках
        .toolbar(.hidden, for: .navigationBar)
        
        // EDIT SPHERE VIEW
        .sheet(isPresented: $showAddEditSheet) {
            AddEditSphereView(
                sphereToEdit: $sphereToEdit,
                spheresCount: spheres.count,
                onDidSaveNewSphere: { newSphere in
                    selectedSphere = newSphere
                }
            )
        }
        // SPHERE SETTINGS VIEW
        .sheet(isPresented: $showSettingsSheet) {
            SettingsView()
        }
        // DASHBOARD VIEW
        .sheet(isPresented: $showDashboard) {
            DashboardView()
        }
        // VISION SHEET (Lifetime Vision → Vision)
        .sheet(isPresented: $showVisionSheet) {
            visionSheetContent(type: .visionAI, onDismiss: { showVisionSheet = false })
        }
        // ANALYTICS SHEET
        .sheet(isPresented: $showAnalyticsSheet) {
            visionSheetContent(type: .analyticsAI, onDismiss: { showAnalyticsSheet = false })
        }
        .confirmationDialog(
            "Are you sure you want to delete this sphere? This cannot be undone.",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteSphere()
            }
            Button("Cancel", role: .cancel) { }
        }
    }
    
    // MARK: - Vision / Analytics Sheet Content
    @ViewBuilder
    private func visionSheetContent(type: AIType, onDismiss: @escaping () -> Void) -> some View {
        let sphere = selectedSphere ?? spheres.first
        let title = type == .visionAI ? "Vision" : "Analytics"
        let iconName = type == .visionAI ? "sparkles" : "chart.line.uptrend.xyaxis"

        NavigationStack {
            Group {
                if let sphere = sphere {
                    let color = Color(hex: sphere.colorHex)
                    let visionText = type == .visionAI ? sphere.visionAI : sphere.analyticsAI
                    VisionPageView(
                        title: title,
                        icon: sphere.iconName,
                        vision: visionText,
                        color: color,
                        isSelected: true,
                        onTap: { hapticManager.selectionChanged() },
                        onEdit: { newText in
                            if type == .visionAI { sphere.visionAI = newText } else { sphere.analyticsAI = newText }
                            try? modelContext.save()
                        },
                        isGenerating: isGenerating,
                        onGenerate: {
                            hapticManager.selectionChanged()
                            isGenerating = true
                            Task {
                                let newVision = await viewModel.generateAIVision(
                                    for: sphere,
                                    type: type,
                                    goals: goals,
                                    tasks: tasks,
                                    habits: habits,
                                    memoItems: memoItems
                                )
                                withAnimation(.easeInOut) {
                                    if type == .visionAI { sphere.visionAI = newVision } else { sphere.analyticsAI = newVision }
                                }
                                isGenerating = false
                            }
                        },
                        fullWindowLayout: true
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(12)
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: iconName)
                            .font(.system(size: 56))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("Select a sphere first")
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        hapticManager.selectionChanged()
                        onDismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // VISION TABS VIEW
    @ViewBuilder
    private func visionContainerView() -> some View {
        GeometryReader { geo in
            let spheresH = geo.size.height * 0.55
            let containerW = geo.size.width
            ZStack(alignment: .topLeading) {
        VStack(spacing: 0) {
            // MARK: Calendar and Menu HStack
            HStack(spacing: 0) {
                calendarView(
                    selectedDate: $calendarManager.selectedDate,
                    weekStartDate: $calendarManager.weekStartDate,
                    isVisible: calendarVisibilityBinding
                )
                .opacity(calendarVisibility ? 1 : 0)
                .allowsHitTesting(calendarVisibility)
                .animation(.easeInOut(duration: 0.25), value: calendarVisibility)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                EllipsisMenuButton {
                    Button {
                        hapticManager.openPage()
                        sphereToEdit = nil
                        showAddEditSheet = true
                    } label: {
                        Label("Add Area", systemImage: "plus.circle")
                    }
                    .disabled(spheres.count >= 12)
                    if mainVisionTabIndex == 1 {
                        Divider()
                        Menu {
                            Button {
                                hapticManager.selectionChanged()
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    visionsStyle = .circle
                                    currentVisionsSettings.style = .circle
                                    try? modelContext.save()
                                }
                            } label: {
                                HStack {
                                    Text("Circle")
                                    Spacer()
                                    if visionsStyle == .circle {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                            Button {
                                hapticManager.selectionChanged()
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    visionsStyle = .circlePro
                                    currentVisionsSettings.style = .circlePro
                                    try? modelContext.save()
                                }
                            } label: {
                                HStack {
                                    Text("Circle Pro")
                                    Spacer()
                                    if visionsStyle == .circlePro {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                            Button {
                                hapticManager.selectionChanged()
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    visionsStyle = .triangle
                                    currentVisionsSettings.style = .triangle
                                    try? modelContext.save()
                                }
                            } label: {
                                HStack {
                                    Text("Triangle")
                                    Spacer()
                                    if visionsStyle == .triangle {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                            Button {
                                hapticManager.selectionChanged()
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    visionsStyle = .bars
                                    currentVisionsSettings.style = .bars
                                    try? modelContext.save()
                                }
                            } label: {
                                HStack {
                                    Text("Bars")
                                    Spacer()
                                    if visionsStyle == .bars {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                            
                            Button {
                                hapticManager.selectionChanged()
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    visionsStyle = .linear
                                    currentVisionsSettings.style = .linear
                                    try? modelContext.save()
                                }
                            } label: {
                                HStack {
                                    Text("Linear")
                                    Spacer()
                                    if visionsStyle == .linear {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                            Button {
                                hapticManager.selectionChanged()
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    visionsStyle = .radar
                                    currentVisionsSettings.style = .radar
                                    try? modelContext.save()
                                }
                            } label: {
                                HStack {
                                    Text("Radar")
                                    Spacer()
                                    if visionsStyle == .radar {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        } label: {
                            Label("Style", systemImage: "paintbrush")
                        }
                        
                        Menu {
                            if visionsStyle == .circle || visionsStyle == .circlePro || visionsStyle == .triangle {
                                Button {
                                    hapticManager.selectionChanged()
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        currentVisionsSettings.showIcons.toggle()
                                        try? modelContext.save()
                                    }
                                } label: {
                                    HStack {
                                        Label(currentVisionsSettings.showIcons ? "Hide Icons" : "Show Icons", systemImage: currentVisionsSettings.showIcons ? "eye.slash" : "eye")
                                        Spacer()
                                        if currentVisionsSettings.showIcons {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                            if visionsStyle == .bars {
                                Button {
                                    hapticManager.selectionChanged()
                                    barsSortDescending = nil
                                } label: {
                                    HStack {
                                        Text("Default Sort")
                                        Spacer()
                                        if barsSortDescending == nil {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                                Button {
                                    hapticManager.selectionChanged()
                                    barsSortDescending = true
                                } label: {
                                    HStack {
                                        Text("Sort ↓")
                                        Spacer()
                                        if barsSortDescending == true {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                                Button {
                                    hapticManager.selectionChanged()
                                    barsSortDescending = false
                                } label: {
                                    HStack {
                                        Text("Sort ↑")
                                        Spacer()
                                        if barsSortDescending == false {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                                Divider()
                                ForEach(BarsWidthMode.allCases) { mode in
                                    Button {
                                        hapticManager.selectionChanged()
                                        barsWidthMode = mode
                                    } label: {
                                        HStack {
                                            Text("Width: \(mode.title)")
                                            Spacer()
                                            if barsWidthMode == mode {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                                Divider()
                                Button {
                                    hapticManager.selectionChanged()
                                    resetBarsFilters()
                                } label: {
                                    Text("Reset filters")
                                }
                            }
                            if visionsStyle == .linear {
                                Button {
                                    hapticManager.selectionChanged()
                                    linearSortDescending = nil
                                } label: {
                                    HStack {
                                        Text("Default Sort")
                                        Spacer()
                                        if linearSortDescending == nil {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                                Button {
                                    hapticManager.selectionChanged()
                                    linearSortDescending = true
                                } label: {
                                    HStack {
                                        Text("Sort ↓")
                                        Spacer()
                                        if linearSortDescending == true {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                                Button {
                                    hapticManager.selectionChanged()
                                    linearSortDescending = false
                                } label: {
                                    HStack {
                                        Text("Sort ↑")
                                        Spacer()
                                        if linearSortDescending == false {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                                Divider()
                                ForEach(LinearHeightMode.allCases) { mode in
                                    Button {
                                        hapticManager.selectionChanged()
                                        linearHeightMode = mode
                                    } label: {
                                        HStack {
                                            Text("Height: \(mode.title)")
                                            Spacer()
                                            if linearHeightMode == mode {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                                Divider()
                                Button {
                                    hapticManager.selectionChanged()
                                    resetLinearFilters()
                                } label: {
                                    Text("Reset filters")
                                }
                            }
                        } label: {
                            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                        }
                        Button {
                            hapticManager.selectionChanged()
                            showDashboard = true
                        } label: {
                            Label("Dashboard", systemImage: "chart.bar.xaxis")
                        }
                        Button {
                            hapticManager.selectionChanged()
                            showVisionSheet = true
                        } label: {
                            Label("Vision", systemImage: "sparkles")
                        }
                        Button {
                            hapticManager.selectionChanged()
                            showAnalyticsSheet = true
                        } label: {
                            Label("Analytics", systemImage: "chart.line.uptrend.xyaxis")
                        }
                        Button {
                            hapticManager.selectionChanged()
                            showSettingsSheet = true
                        } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                                           }
                                       }
                                       .padding(.trailing, 16)
                                   }
                                   .frame(maxWidth: .infinity)
            if !spheres.isEmpty {
                ZStack {
                    currentVisionPage
                        .id(mainVisionTabIndex)
                        .transition(pagerTransition)
                }
                .frame(height: spheresH)
                .animation(.easeInOut(duration: 0.3), value: mainVisionTabIndex)
                
                bottomPagerView
                    .frame(maxWidth: .infinity)
                    .layoutPriority(1)
            } else {
                Color.clear
                    .frame(height: spheresH)
            }
            //.border(Color.orange.opacity(0.3), width: 15) // DEBUG
        }
        .frame(maxHeight: .infinity)

        if showSphereActionMenu, let sphere = sphereActionMenuTarget {
            sphereActionMenuOverlayContent(sphere: sphere, containerWidth: containerW)
        }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func sphereActionMenuOverlayContent(sphere: Sphere, containerWidth: CGFloat) -> some View {
        let cardWidth = min(320.0, containerWidth - 48)
        let canDeleteSphere = spheres.count > 3

        return ZStack {
            Color.black.opacity(0.38)
                .ignoresSafeArea()
                .onTapGesture { dismissSphereActionMenu() }

            VStack(spacing: 14) {
                Button {
                    hapticManager.selectionChanged()
                    dismissSphereActionMenu()
                    sphereToEdit = sphere
                    showAddEditSheet = true
                } label: {
                    Text("Edit")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color(UIColor.systemBlue))
                        )
                }
                .buttonStyle(.plain)

                Button {
                    guard canDeleteSphere else { return }
                    dismissSphereActionMenu()
                    sphereToDelete = sphere
                    showDeleteConfirmation = true
                } label: {
                    Text("Delete")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color(UIColor.systemRed).opacity(canDeleteSphere ? 1 : 0.45))
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canDeleteSphere)
            }
            .padding(22)
            .frame(width: cardWidth)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.42), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.22), radius: 28, x: 0, y: 14)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: 2ND MAIN SPHERES VIEW
    @ViewBuilder
    private var spheresMainView: some View {
        if visionsStyle == .circle {
            VisionCircleView(
                spheres: spheres,
                goals: goals,
                selectedSphere: $selectedSphere,
                isGenerating: $isGenerating,
                displayMode: .continuous,
                showIcons: currentVisionsSettings.showIcons,
                showEdgeIcons: true,
                showCenterPulseIcon: true,
                onEdit: { sphere in
                    hapticManager.selectionChanged()
                    sphereToEdit = sphere
                    showAddEditSheet = true
                },
                onRequestActions: { sphere in
                    presentSphereActionMenu(for: sphere)
                },
                onAdd: {
                    hapticManager.openPage()
                    sphereToEdit = nil
                    showAddEditSheet = true
                },
                onDragStateChange: { active in
                    isCircleDragging = active
                }
            )
            .padding(.horizontal, unifiedSpheresHorizontalPadding)
        } else if visionsStyle == .circlePro {
            VisionCircleLabeledRingView(
                spheres: spheres,
                goals: goals,
                selectedSphere: $selectedSphere,
                isGenerating: $isGenerating,
                showIcons: currentVisionsSettings.showIcons,
                onEdit: { sphere in
                    hapticManager.selectionChanged()
                    sphereToEdit = sphere
                    showAddEditSheet = true
                },
                onRequestActions: { sphere in
                    presentSphereActionMenu(for: sphere)
                },
                onAdd: {
                    hapticManager.openPage()
                    sphereToEdit = nil
                    showAddEditSheet = true
                },
                onDragStateChange: { active in
                    isCircleDragging = active
                }
            )
            .padding(.horizontal, unifiedSpheresHorizontalPadding)
        } else if visionsStyle == .triangle {
            VisionTriangleProView(
                spheres: spheres,
                goals: goals,
                selectedSphere: $selectedSphere,
                isGenerating: $isGenerating,
                onEdit: { sphere in
                    hapticManager.selectionChanged()
                    sphereToEdit = sphere
                    showAddEditSheet = true
                },
                onRequestActions: { sphere in
                    presentSphereActionMenu(for: sphere)
                },
                onAdd: {
                    hapticManager.openPage()
                    sphereToEdit = nil
                    showAddEditSheet = true
                },
                onDragStateChange: { active in
                    isCircleDragging = active
                }
            )
            .padding(.horizontal, unifiedSpheresHorizontalPadding / 3)
        } else if visionsStyle == .bars {
            SpheresBarsView(
                spheres: spheres,
                selectedSphere: $selectedSphere,
                onEdit: { sphere in
                    hapticManager.selectionChanged()
                    sphereToEdit = sphere
                    showAddEditSheet = true
                },
                onRequestActions: { sphere in
                    presentSphereActionMenu(for: sphere)
                },
                onAdd: {
                    hapticManager.openPage()
                    sphereToEdit = nil
                    showAddEditSheet = true
                },
                sortDescending: barsSortDescending,
                widthMode: barsWidthMode,
                onDragStateChange: { active in
                    isCircleDragging = active
                },
                onDragPreviewChange: { sphereID, previewValue in
                    barsDragPreviewSphereID = sphereID
                    barsDragPreviewValue = previewValue
                }
            )
            .padding(.horizontal, unifiedSpheresHorizontalPadding / 2)
        } else if visionsStyle == .linear {
            SpheresLinearView(
                spheres: spheres,
                selectedSphere: $selectedSphere,
                onEdit: { sphere in
                    hapticManager.selectionChanged()
                    sphereToEdit = sphere
                    showAddEditSheet = true
                },
                onRequestActions: { sphere in
                    presentSphereActionMenu(for: sphere)
                },
                sortDescending: $linearSortDescending,
                heightMode: $linearHeightMode,
                onDragStateChange: { active in
                    isCircleDragging = active
                },
                onDragPreviewChange: { sphereID, previewValue in
                    linearDragPreviewSphereID = sphereID
                    linearDragPreviewValue = previewValue
                }
            )
            .padding(.horizontal, unifiedSpheresHorizontalPadding / 2)
        } else if visionsStyle == .radar {
            RadarStyleView(
                spheres: spheres,
                selectedSphere: $selectedSphere,
                onEdit: { sphere in
                    hapticManager.selectionChanged()
                    sphereToEdit = sphere
                    showAddEditSheet = true
                },
                onAddSphere: {
                    hapticManager.openPage()
                    sphereToEdit = nil
                    showAddEditSheet = true
                }
            )
            .padding(.horizontal, unifiedSpheresHorizontalPadding / 2)
            //.border(Color.black, width: 10) // DEBUG
        }
    }
    
    // MARK: DELETE SPHERE FUNCTION
    private func deleteSphere() {
        guard let sphere = sphereToDelete else { return }
        
        
        if selectedSphere?.id == sphere.id { // If selected sphere deleted, deselect choice
            selectedSphere = nil
        }
        
        modelContext.delete(sphere)
        hapticManager.itemDeleted()
        
        do {
            try modelContext.save()
        } catch {
            print("Error deleting sphere: \(error)")
        }

        syncCalendarAccentSphereID()
        sphereToDelete = nil
    }
    
    // MARK: - PAGE DOTS VIEW (скрыт: только 1 страница — spheres; Vision/Analytics в меню)
    private var pagerIndicator: some View {
        EmptyView()
        // Закомментировано — было 3 страницы (Lifetime Vision, Spheres, Analytics)
        // HStack(spacing: 3) {
        //     ForEach(0..<3, id: \.self) { idx in
        //         Capsule()
        //             .fill(idx == mainVisionTabIndex ? Color(hex: selectedSphere?.colorHex ?? "#007AFF") : Color.gray.opacity(0.3))
        //             .frame(width: idx == mainVisionTabIndex ? 16 : 6, height: 6)
        //             .animation(.spring(response: 0.3, dampingFraction: 0.7), value: mainVisionTabIndex)
        //     }
        // }
    }
    
    private let pagerDragThreshold: CGFloat = 60
    
    private var currentVisionPage: AnyView {
        // Закомментировано: Lifetime Vision и Analytics перенесены в меню (Vision / Analytics)
        // case 0: Lifetime Vision
        // case 2: Analytics
        switch mainVisionTabIndex {
        // case 0:
        //     if let sphere = selectedSphere ?? spheres.first {
        //         return AnyView(
        //             VisionPageView(
        //                 title: "Lifetime Vision",
        //                 icon: sphere.iconName,
        //                 vision: sphere.visionAI,
        //                 color: Color(hex: sphere.colorHex),
        //                 isSelected: true,
        //                 onTap: { hapticManager.selectionChanged() },
        //                 onEdit: { newText in sphere.visionAI = newText },
        //                 isGenerating: isGenerating && mainVisionTabIndex == 0,
        //                 onGenerate: { ... }
        //             )
        //             .padding(.horizontal, 16)
        //             .padding(.vertical, 4)
        //         )
        //     }
        case 1:
            return AnyView(spheresMainView)
        // case 2:
        //     if let sphere = selectedSphere ?? spheres.first {
        //         return AnyView(
        //             VisionPageView(
        //                 title: "Analytics",
        //                 icon: sphere.iconName,
        //                 vision: sphere.analyticsAI,
        //                 ...
        //             )
        //         )
        //     }
        default:
            break
        }
        return AnyView(spheresMainView)
    }
    
    // MARK: 4th SEGMENTED ENTIRE VIEW
    private var bottomPagerView: some View {
        Group {
            if let sphere = selectedSphere {
                TabView(selection: $bottomPagerIndex) {
                    VisionLifeSpheresPageView(spheres: spheres)
                        .tag(0)
                    
                    VisionMomentumFullCardView(
                        sphere: sphere,
                        goals: goals.filter { $0.sphereID == sphere.id },
                        tasks: tasks.filter { $0.sphereID == sphere.id },
                        habits: habits.filter { $0.sphereID == sphere.id },
                        positiveImpactPotential: totalPositiveImpact(for: sphere)
                    )
                    .tag(1)
                    
                    VisionGoalsGridView(
                        goals: goals,
                        fallbackIconName: (selectedSphere?.iconName ?? spheres.first?.iconName) ?? "target",
                        fallbackColorHex: (selectedSphere?.colorHex ?? spheres.first?.colorHex) ?? "#007AFF"
                    )
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            } else {
                VStack {
                    Spacer()
                    Text("Choose sphere to see momentum")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    // VISIONS TABS VIEWS — закомментировано: Vision и Analytics перенесены в меню (модальные окна)
    // private func visionsSection(for sphere: Sphere) -> some View {
    //     VStack(alignment: .leading, spacing: 2) {
    //         GeometryReader { geometry in
    //             ScrollViewReader { proxy in
    //                 ScrollView(.horizontal, showsIndicators: false) {
    //                     HStack(spacing: 20) {
    //                         VisionPageView(title: "AI Analytics", ...)
    //                         VisionPageView(title: "Lifetime Vision", ...)
    //                     }
    //                 }
    //                 .onAppear { ... }
    //                 .onChange(of: selectedVisionType) { ... }
    //                 .simultaneousGesture(DragGesture()...)
    //             }
    //         }
    //         .frame(height: 260)
    //     }
    // }
    
    // SEGMENTED CONTROL SECTIONS VIEW
    @ViewBuilder
    private func segmentedSection(for sphere: Sphere) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("items", selection: $selectedCategory) {
                ForEach(segmentedCategory.allCases, id: \.rawValue) { category in
                    Text(category.rawValue).tag(category)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal, 10)
            
            Group {
                switch selectedCategory {
                case .goals:
                    GoalsForSphereView(sphereID: sphere.id, selectedDate: calendarManager.selectedDate)
                case .tasks:
                    TasksForSphereView(sphereID: sphere.id, selectedDate: calendarManager.selectedDate)
                case .habits:
                    HabitsForSphereView(sphereID: sphere.id, selectedDate: calendarManager.selectedDate)
                case .memo:
                    MemoForSphereView(
                        sphereID: sphere.id,
                        selectedDate: calendarManager.selectedDate
                    )
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(maxHeight: .infinity)
    }
    
    // EMPTY SEGMENTED TEXT VIEW
    private func emptyStateText(_ text: String) -> some View {
        VStack {
            Spacer()
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        
    }
    
    // SCROLL VIEW OF CARDS INSIDE SEGMENTED VIEW
    @ViewBuilder
    private func itemsScrollView<T: Identifiable>(items: [T], @ViewBuilder content: @escaping (T) -> ItemView) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(items, id: \.id) { item in
                    content(item)
                }
            }
        }
    }
    
    // ITEM CARD VIEW
    private struct ItemView: View {
        let title: String
        let isCompleted: Bool
        
        var body: some View {
            HStack(spacing: 8) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isCompleted ? .green : .gray)
                Text(title)
                    .font(.subheadline)
                    .lineLimit(2)
            }
            .padding()
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        }
    }
    
}
