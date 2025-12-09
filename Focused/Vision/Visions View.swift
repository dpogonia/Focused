import SwiftUI // new
import SwiftData

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
    @State private var linearSortDescending: Bool? = nil // nil = по порядку добавления (дефолт)
    @State private var linearHeightMode: LinearHeightMode = .regular
    @State private var barsSortDescending: Bool? = nil // nil = по порядку добавления (дефолт)
    @State private var barsWidthMode: BarsWidthMode = .regular
    @StateObject private var сalendarManager = CalendarManager()
    private let hapticManager = HapticSoundManager.shared
    @State private var mainVisionTabIndex: Int = 1
    @State private var showSettingsSheet: Bool = false
    @State private var safeAreaTop: CGFloat = 0
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
    
    private func updateSafeAreaTop() { // Get safe area top directly
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            if let window = windowScene.windows.first {
                safeAreaTop = window.safeAreaInsets.top
            } else if let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) {
                safeAreaTop = keyWindow.safeAreaInsets.top
            }
        }
    }
    
    enum AIType: String, CaseIterable {
        case analyticsAI = "Analytics"
        case visionAI = "Lifetime Vision"
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
    
    // UNIFIED SPHERES STYLE CONTAINER HEIGHT
    private var unifiedSpheresContainerHeight: CGFloat {
        return UIScreen.main.bounds.height * 0.45
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
    
    private func resetLinearFilters() {
        linearSortDescending = nil // Сброс на сортировку по порядку добавления
    }
    
    private func resetBarsFilters() {
        barsSortDescending = nil // Сброс на сортировку по порядку добавления
        barsWidthMode = .regular
    }
    
    // AI GENERATION
    private func generateAIVision(for sphere: Sphere) async -> String {
        let apiKey = ""
        let url = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("https://dev.example.com", forHTTPHeaderField: "HTTP-Referer")
        
        let habitsList = habits.filter { $0.sphereID == sphere.id }.map { $0.title }.joined(separator: ", ")
        let goalsList = goals.filter { $0.sphereID == sphere.id }.map { $0.title }.joined(separator: ", ")
        let tasksList = tasks.filter { $0.sphereID == sphere.id }.map { $0.title }.joined(separator: ", ")
        
        let prompt = """
        Create a creative and motivating vision for \(selectedVisionType.rawValue.lowercased()) for the life sphere "\(sphere.title)" with the current satisfaction level \(String(format: "%.0f", sphere.satisfaction))%.
        For context, here are the related goals: \(goalsList.isEmpty ? "not set" : goalsList).
        Related tasks: \(tasksList.isEmpty ? "not set" : tasksList).
        Related habits: \(habitsList.isEmpty ? "not set" : habitsList).
        Add emojis, possibly a short inspiring quote, and make the text vivid, as if it were a personal success plan.
        Important: Output ONLY the vision text, without any introductions, explanations, or comments. Start immediately with the vision.
        Example: 🚀 You will conquer the peaks in Finance, reaching 90% satisfaction! With your goals... [vision text]. 'Quote'. 🌟
        """
        
        let body: [String: Any] = [
            "model": "deepseek/deepseek-chat",
            "messages": [["role": "user", "content": prompt]],
            "temperature": 0.8,
            "max_tokens": 400
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body, options: []) else {
            return "Error: Could not create request body."
        }
        request.httpBody = jsonData
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                if let rawString = String(data: data, encoding: .utf8) {
                    print("Raw API Error Response: \(rawString)")
                }
                return "ERROR API: Code \(httpResponse.statusCode). Check console for more."
            }
            
            let apiResponse = try JSONDecoder().decode(OpenRouterResponse.self, from: data)
            return apiResponse.choices.first?.message.content ?? "Try again"
        } catch {
            return "ERROR: \(error.localizedDescription). Check console for more."
        }
    }
    
    var body: some View {
        NavigationStack {
            // MAIN GEOMETRY VIEW
            GeometryReader { geometry in
                ZStack {
                    // MAIN CONTENT VIEW
                    visionContainerView(geometry: geometry, safeAreaTop: safeAreaTop)
                    //.border(Color.blue, width: 30) // DEBUG
                    
                    if isCircleDragging {
                        Color.clear
                            .contentShape(Rectangle())
                            .gesture(DragGesture())
                    }
                }
            }
            //.border(Color.black, width: 20) // DEBUG
            .ignoresSafeArea(edges: .top)
            
            // ADD DEFAULT SPHERES OR SHOW SELECTED SPHERE
            .onAppear {
                updateSafeAreaTop()
                if selectedSphere == nil && !spheres.isEmpty {
                    selectedSphere = spheres.first
                }
                addDefaultSpheres()
                visionsStyle = currentVisionsSettings.style
                сalendarManager.isVisible = calendarVisibility
            }
            
            // HIDES CALENDAR IF TURNED OFF IN SETTINGS
            .onReceive(NotificationCenter.default.publisher(for: .appCalendarVisibilityDidChange)) { _ in
                сalendarManager.isVisible = calendarVisibility
            }
            //.border(Color.yellow.opacity(0.5), width: 10) // DEBUG NAVIGATION STACK
            
            
        }
        
        // EDIT SPHERE VIEW
        .sheet(isPresented: $showAddEditSheet) {
            AddEditSphereView(sphereToEdit: $sphereToEdit, spheresCount: spheres.count)
        }
        // SPHERE SETTINGS VIEW
        .sheet(isPresented: $showSettingsSheet) {
            SettingsView()
        }
        .confirmationDialog("Sphere actions", isPresented: $showSphereActionMenu, presenting: sphereActionMenuTarget) { sphere in
            Button("Edit") {
                sphereToEdit = sphere
                showAddEditSheet = true
            }
            Button("Delete", role: .destructive) {
                sphereToDelete = sphere
                showDeleteConfirmation = true
            }
            Button("Cancel", role: .cancel) { }
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
    
    // VISION TABS VIEW
    @ViewBuilder
    private func visionContainerView(geometry: GeometryProxy, safeAreaTop: CGFloat) -> some View {
        VStack(spacing: 0) {
            // MARK: Calendar and Menu HStack
            HStack(spacing: 0) {
                calendarView(
                    selectedDate: $сalendarManager.selectedDate,
                    weekStartDate: $сalendarManager.weekStartDate,
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
                        Menu("Style") {
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
                        }
                        
                        Menu("Filter") {
                            if visionsStyle == .circle {
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
                                Button {
                                    hapticManager.selectionChanged()
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        currentVisionsSettings.showDashedLines = !(currentVisionsSettings.showDashedLines ?? false)
                                        try? modelContext.save()
                                    }
                                } label: {
                                    HStack {
                                        let isEnabled = currentVisionsSettings.showDashedLines ?? false
                                        Label(isEnabled ? "Hide Dashed Lines" : "Show Dashed Lines", systemImage: isEnabled ? "circle.dashed" : "circle")
                                        Spacer()
                                        if isEnabled {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                                Button {
                                    hapticManager.selectionChanged()
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        currentVisionsSettings.showFiftyPercent = !(currentVisionsSettings.showFiftyPercent ?? false)
                                        try? modelContext.save()
                                    }
                                } label: {
                                    HStack {
                                        let isEnabled = currentVisionsSettings.showFiftyPercent ?? false
                                        Label(isEnabled ? "Hide 50% Circle" : "Show 50% Circle", systemImage: isEnabled ? "circle.fill" : "circle")
                                        Spacer()
                                        if isEnabled {
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
                                   .padding(.top, safeAreaTop)
            if !spheres.isEmpty {
                ZStack {
                    currentVisionPage
                        .id(mainVisionTabIndex)
                        .transition(pagerTransition)
                }
                .frame(height: unifiedSpheresContainerHeight)
                .animation(.easeInOut(duration: 0.3), value: mainVisionTabIndex)
                
                pagerFooter
                
                segmentedView
                    .frame(maxWidth: .infinity)
                    .layoutPriority(1)
            } else {
                Color.clear
                    .frame(height: unifiedSpheresContainerHeight)
            }
            //.border(Color.orange.opacity(0.3), width: 15) // DEBUG
        }
        .frame(maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
        //.border(Color.red, width: 40) // DEBUG
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
                showIcons: currentVisionsSettings.showIcons,
                showDashedLines: currentVisionsSettings.showDashedLines ?? false,
                showFiftyPercent: currentVisionsSettings.showFiftyPercent ?? false,
                onEdit: { sphere in
                    hapticManager.selectionChanged()
                    sphereToEdit = sphere
                    showAddEditSheet = true
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
        } else if visionsStyle == .bars {
            SpheresBarsView(
                spheres: spheres,
                selectedSphere: $selectedSphere,
                onEdit: { sphere in
                    hapticManager.selectionChanged()
                    sphereToEdit = sphere
                    showAddEditSheet = true
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
            .padding(.horizontal, unifiedSpheresHorizontalPadding)
        } else if visionsStyle == .linear {
            SpheresLinearView(
                spheres: spheres,
                selectedSphere: $selectedSphere,
                onEdit: { sphere in
                    hapticManager.selectionChanged()
                    sphereToEdit = sphere
                    showAddEditSheet = true
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
            .padding(.horizontal, unifiedSpheresHorizontalPadding)
            //.border(Color.black, width: 10) // DEBUG
        }
    }
    
    // MARK: 3RD SELECTED SPHERE CARD VIEW
    @ViewBuilder
    private func selectedSphereCard(sphere: Sphere) -> some View {
        let color = Color(hex: sphere.colorHex)
        // Используем preview значение во время drag для Bars и Linear View, иначе реальное значение
        let dragPreviewValue: Double? = {
            if barsDragPreviewSphereID == sphere.id {
                return barsDragPreviewValue
            } else if linearDragPreviewSphereID == sphere.id {
                return linearDragPreviewValue
            }
            return nil
        }()
        let satisfaction = dragPreviewValue ?? sphere.satisfaction
        let potentialIncrease = totalPositiveImpact(for: sphere)
        let projected = max(0.0, min(100.0, satisfaction + potentialIncrease))
        let showsProjected = projected >= 10.0 && projected > satisfaction + 0.1
        
        HStack(spacing: 8) {
            Image(systemName: sphere.iconName)
            
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
            //.clipShape(Circle())
                .foregroundColor(.white)
            //.background(Color.white.opacity(0.0))
            
            Text(sphere.title)
                .font(.subheadline).bold()
                .foregroundColor(.white)
                .lineLimit(1)
                .truncationMode(.tail)
            Text("\(String(format: "%.1f", satisfaction))%")
                .font(.caption).bold()
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.18))
                .clipShape(Capsule())
                .foregroundColor(.white)
            if showsProjected {
                Text("→ \(Int(round(projected)))%")
                    .font(.caption).bold()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.12))
                    .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
                    .clipShape(Capsule())
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(color)
                //.shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
        )
        .onTapGesture(count: 2) {
            presentSphereActionMenu(for: sphere)
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
        
        sphereToDelete = nil
    }
    
    // MARK: - PAGE DOTS VIEW
    private var pagerIndicator: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { idx in
                Capsule()
                    .fill(idx == mainVisionTabIndex ? Color(hex: selectedSphere?.colorHex ?? "#007AFF") : Color.gray.opacity(0.3))
                    .frame(width: idx == mainVisionTabIndex ? 16 : 6, height: 6)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: mainVisionTabIndex)
            }
        }
    }
    
    private let pagerDragThreshold: CGFloat = 60
    
    private var currentVisionPage: AnyView {
        switch mainVisionTabIndex {
        case 0:
            if let sphere = selectedSphere ?? spheres.first {
                return AnyView(
                    VisionPageView(
                        title: "Lifetime Vision",
                        icon: sphere.iconName,
                        vision: sphere.visionAI,
                        color: Color(hex: sphere.colorHex),
                        isSelected: true,
                        onTap: { hapticManager.selectionChanged() },
                        onEdit: { newText in sphere.visionAI = newText },
                        isGenerating: isGenerating && mainVisionTabIndex == 0,
                        onGenerate: {
                            hapticManager.selectionChanged()
                            isGenerating = true
                            selectedVisionType = .visionAI
                            Task {
                                let newVision = await generateAIVision(for: sphere)
                                withAnimation(.easeInOut) { sphere.visionAI = newVision }
                                isGenerating = false
                            }
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                )
            }
        case 1:
            return AnyView(spheresMainView)
        case 2:
            if let sphere = selectedSphere ?? spheres.first {
                return AnyView(
                    VisionPageView(
                        title: "Analytics",
                        icon: sphere.iconName,
                        vision: sphere.analyticsAI,
                        color: Color(hex: sphere.colorHex),
                        isSelected: true,
                        onTap: { hapticManager.selectionChanged() },
                        onEdit: { newText in sphere.analyticsAI = newText },
                        isGenerating: isGenerating && mainVisionTabIndex == 2,
                        onGenerate: {
                            hapticManager.selectionChanged()
                            isGenerating = true
                            selectedVisionType = .analyticsAI
                            Task {
                                let newVision = await generateAIVision(for: sphere)
                                withAnimation(.easeInOut) { sphere.analyticsAI = newVision }
                                isGenerating = false
                            }
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                )
            }
        default:
            break
        }
        return AnyView(EmptyView())
    }
    
    @ViewBuilder
    private var pagerFooter: some View {
        HStack {
            if mainVisionTabIndex == 1, let sphere = selectedSphere {
                selectedSphereCard(sphere: sphere)
            } else {
                Spacer()
            }
            Spacer()
            pagerIndicator
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .frame(height: 50)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 10)
                .onEnded { value in
                    guard !isCircleDragging else { return }
                    if value.translation.width < -pagerDragThreshold {
                        pagerTransition = .asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        )
                        mainVisionTabIndex = min(2, mainVisionTabIndex + 1)
                    } else if value.translation.width > pagerDragThreshold {
                        pagerTransition = .asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        )
                        mainVisionTabIndex = max(0, mainVisionTabIndex - 1)
                    }
                }
        )
    }
    
    // MARK: 4th SEGMENTED ENTIRE VIEW
    private var segmentedView: some View {
        Group {
            if let sphere = selectedSphere {
                VStack(alignment: .leading, spacing: 12) {
                    segmentedSection(for: sphere)
                }
                .padding(.top, 1)
                .frame(maxHeight: .infinity)
                //.border(Color.red, width: 3) // DEBUG
            } else { // TO DO: MAKE DEFAULT VIEW BETTER
                VStack {
                    Spacer()
                    Text("Choose sphere to see details")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxHeight: .infinity)
            }
        }
    }
    
    // VISIONS TABS VIEWS
    private func visionsSection(for sphere: Sphere) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            GeometryReader { geometry in
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 20) {
                            
                            // AI ANALYTICS CARD VIEW
                            VisionPageView(
                                title: "AI Analytics",
                                icon: sphere.iconName,
                                vision: sphere.analyticsAI,
                                color: Color(hex: sphere.colorHex),
                                isSelected: selectedVisionType == .analyticsAI,
                                onTap: {
                                    hapticManager.selectionChanged()
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        selectedVisionType = .analyticsAI
                                    }
                                },
                                onEdit: { newText in
                                    sphere.analyticsAI = newText
                                },
                                isGenerating: isGenerating && selectedVisionType == .analyticsAI,
                                onGenerate: {
                                    hapticManager.selectionChanged()
                                    isGenerating = true
                                    selectedVisionType = .analyticsAI
                                    Task {
                                        let newVision = await generateAIVision(for: sphere)
                                        withAnimation(.easeInOut) {
                                            sphere.analyticsAI = newVision
                                        }
                                        isGenerating = false
                                    }
                                }
                            )
                            .padding([.leading, .trailing], 20)
                            .frame(width: geometry.size.width, height: 240)
                            .id("Analytics")
                            
                            // LIFETIME VISION CARD VIEW
                            VisionPageView(
                                title: "Lifetime Vision",
                                icon: sphere.iconName,
                                vision: sphere.visionAI,
                                color: Color(hex: sphere.colorHex),
                                isSelected: selectedVisionType == .visionAI,
                                onTap: {
                                    hapticManager.selectionChanged()
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        selectedVisionType = .visionAI
                                    }
                                },
                                onEdit: { newText in
                                    sphere.visionAI = newText
                                },
                                isGenerating: isGenerating && selectedVisionType == .visionAI,
                                onGenerate: {
                                    hapticManager.selectionChanged()
                                    isGenerating = true
                                    selectedVisionType = .visionAI
                                    Task {
                                        let newVision = await generateAIVision(for: sphere)
                                        withAnimation(.easeInOut) {
                                            sphere.visionAI = newVision
                                        }
                                        isGenerating = false
                                    }
                                }
                            )
                            .padding([.leading, .trailing], 20)
                            .frame(width: geometry.size.width, height: 240)
                            .id("Lifetime Vision")
                        }
                        .padding(.horizontal, 16)
                    }
                    .onAppear {
                        let targetId = selectedVisionType == .analyticsAI ? "Analytics" : "Lifetime Vision"
                        proxy.scrollTo(targetId, anchor: .center)
                    }
                    .onChange(of: selectedVisionType) { oldValue, newValue in
                        let targetId = newValue == .analyticsAI ? "Analytics" : "Lifetime Vision"
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            proxy.scrollTo(targetId, anchor: .center)
                        }
                    }
                    // SWIPE GESTURES TO CHANGE VIEWS
                    .simultaneousGesture(
                        DragGesture()
                            .onEnded { value in
                                let threshold: CGFloat = 50
                                let currentIndex = selectedVisionType == .analyticsAI ? 0 : 1
                                
                                if value.translation.width > threshold && currentIndex > 0 {
                                    hapticManager.selectionChanged()
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        selectedVisionType = .analyticsAI
                                    }
                                } else if value.translation.width < -threshold && currentIndex < 1 {
                                    hapticManager.selectionChanged()
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        selectedVisionType = .visionAI
                                    }
                                }
                            }
                    )
                }
            }
            .frame(height: 260)
        }
    }
    
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
                    GoalsForSphereView(sphereID: sphere.id, selectedDate: сalendarManager.selectedDate)
                case .tasks:
                    TasksForSphereView(sphereID: sphere.id, selectedDate: сalendarManager.selectedDate)
                case .habits:
                    HabitsForSphereView(sphereID: sphere.id, selectedDate: сalendarManager.selectedDate)
                case .memo:
                    MemoForSphereView(
                        sphereID: sphere.id,
                        selectedDate: сalendarManager.selectedDate
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
    
    // DEFAULT SPHERES VIEW
    private func addDefaultSpheres() {
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: "defaultsSpheresAdded") && spheres.isEmpty {
            let defaultSpheres = [
                Sphere(title: "Mental", satisfaction: 35.0, colorHex: "#AF52DE", iconName: "lightbulb.fill", orderIndex: 0),
                Sphere(title: "Social", satisfaction: 45.5, colorHex: "#FF9500", iconName: "person.2.fill", orderIndex: 1),
                Sphere(title: "Finance", satisfaction: 50.0, colorHex: "#00C7BE", iconName: "dollarsign.circle.fill", orderIndex: 2),
                Sphere(title: "Skills", satisfaction: 40.0, colorHex: "#32ADE6", iconName: "book.fill", orderIndex: 3),
                Sphere(title: "Health", satisfaction: 75.0, colorHex: "#FF2D55", iconName: "heart.fill", orderIndex: 4),
                Sphere(title: "Sports", satisfaction: 80.0, colorHex: "#FFCC00", iconName: "dumbbell.fill", orderIndex: 5)
            ]
            for sphere in defaultSpheres {
                modelContext.insert(sphere)
            }
            defaults.set(true, forKey: "defaultsSpheresAdded")
        }
    }
}
