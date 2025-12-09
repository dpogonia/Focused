import SwiftUI
import SwiftData

// MARK: - Main Memo View
struct AllMemoView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MemoItem.creationDate, order: .reverse) private var memoItems: [MemoItem]
    @Query private var appCalendarSettings: [AppCalendarSettings]
    @Query private var memoSettings: [MemoSettings]
    @Query private var appDesignSettings: [AppDesignSettings]
    
    @State private var showAddEditSheet = false
    @State private var memoToEdit: MemoItem?
    @State private var newMemoType: MemoItemType = .noteAlbum
    @State private var pendingMemoType: MemoItemType? = nil
    @State private var showViewer = false
    @State private var viewerItem: MemoItem?
    @State private var showStatistics = false
    @State private var currentSheetId = UUID()
    
    @State private var searchText = ""
    @State private var selectedTypeFilter: MemoItemType?
    @State private var selectedTagFilter: String?
    @State private var showFilters = false
    @State private var showTagFilter = false
    @State private var showSearchBar = false
    @State private var sortOrder: SortOrder = .newest
    @StateObject private var compactCalendarManager = CalendarManager()
    @State private var localShowCompletedMemos: Bool = true
    @State private var memoDesign: AppDesign = .basic
    @State private var selectedMemoItem: MemoItem?
    @State private var isReorderMode = false
    @State private var showCompleted = true
    @State private var showListStatistics = false
    @State private var isNoteAlbumReorderMode = false
    @State private var showNoteAlbumStatistics = false
    @State private var showCounterStatistics = false
    @State private var showStreakStatistics = false
    @State private var showSkillStatistics = false
    @State private var showBudgetStatistics = false
    @State private var safeAreaTop: CGFloat = 0
    @State private var showQuickTimeEditor = false
    @State private var showQuickSkillEditor = false
    @State private var memosOrderKey: UUID = UUID()
    
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
    
    enum SortOrder: String, CaseIterable {
        case newest = "newest"
        case oldest = "oldest"
        case alphabetical = "alphabetical"
        case type = "type"
        
        var displayName: String {
            switch self {
            case .newest: "Newest first"
            case .oldest: "Older first"
            case .alphabetical: "Alphabetically"
            case .type: "Type sorted"
            }
        }
        
        var icon: String {
            switch self {
            case .newest: "clock.arrow.circlepath"
            case .oldest: "clock.badge.checkmark"
            case .alphabetical: "textformat.abc"
            case .type: "folder"
            }
        }
    }
    
    private var filteredAndSortedItems: [MemoItem] {
        var items = memoItems
        
        // Calendar filtering
        if globalCalendarVisibility {
            let calendarFilter = MemoCalendarFilter(memoItems: items)
            items = calendarFilter.filterForDate(compactCalendarManager.selectedDate)
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            items = items.filter { item in
                item.title.localizedCaseInsensitiveContains(searchText) ||
                (item.contentData != nil && String(data: item.contentData!, encoding: .utf8)?.localizedCaseInsensitiveContains(searchText) == true)
            }
        }
        
        // Apply type filter
        if let selectedType = selectedTypeFilter {
            items = items.filter { $0.itemType == selectedType }
        }
        
        // Apply tag filter
        if let selectedTag = selectedTagFilter {
            items = items.filter { $0.tags.contains(selectedTag) }
        }
        
        // Apply completed filter (Memo doesn't have a universal completed status yet).
        // As a pragmatic default, hide items tagged as "completed" when toggle is off.
        if !localShowCompletedMemos {
            items = items.filter { !$0.tags.contains("completed") }
        }
        
        // Apply sorting
        switch sortOrder {
        case .newest:
            items.sort { item1, item2 in
                // Сначала по статусу (active сверху, archived снизу)
                if item1.status != item2.status {
                    return item1.status == .active
                }
                // Затем по дате создания
                return item1.creationDate > item2.creationDate
            }
        case .oldest:
            items.sort { item1, item2 in
                // Сначала по статусу (active сверху, archived снизу)
                if item1.status != item2.status {
                    return item1.status == .active
                }
                // Затем по дате создания
                return item1.creationDate < item2.creationDate
            }
        case .alphabetical:
            items.sort { item1, item2 in
                // Сначала по статусу (active сверху, archived снизу)
                if item1.status != item2.status {
                    return item1.status == .active
                }
                // Затем по алфавиту
                return item1.title.localizedCaseInsensitiveCompare(item2.title) == .orderedAscending
            }
        case .type:
            items.sort { item1, item2 in
                // Сначала по статусу (active сверху, archived снизу)
                if item1.status != item2.status {
                    return item1.status == .active
                }
                // Затем по типу
                return item1.itemType.displayName.localizedCaseInsensitiveCompare(item2.itemType.displayName) == .orderedAscending
            }
        }
        return items
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
                            placeholder: "Search memos..."
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
                        memoMenuContent
                    }
                    .padding(.trailing, 16)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, safeAreaTop)
                .animation(.easeInOut(duration: 0.3), value: showSearchBar)
                
                // Filter Panel
                if showFilters {
                    // Filter panel UI removed in favor of menu-based filters
                }
                
                // Content
                Group {
                    if filteredAndSortedItems.isEmpty {
                        if memoItems.isEmpty {
                            EmptyStateView.noMemos()
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - 200)
                                .background(Color(UIColor.systemGroupedBackground))
                        } else {
                            EmptyStateView.noResults(searchText: searchText)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - 200)
                                .background(Color(UIColor.systemGroupedBackground))
                        }
                    } else {
                        memoList
                    }
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .ignoresSafeArea(edges: .top)
            .onAppear {
                updateSafeAreaTop()
                localShowCompletedMemos = currentMemoSettings.showCompletedMemos
                // Sync memo design with global
                if let global = appDesignSettings.first { memoDesign = global.design } else { memoDesign = .basic }
            }
            .onReceive(NotificationCenter.default.publisher(for: .appDesignDidChange)) { _ in
                if let global = appDesignSettings.first { memoDesign = global.design }
            }
            .onChange(of: pendingMemoType) { oldValue, newValue in
                if let newType = newValue {
                    newMemoType = newType
                    currentSheetId = UUID()
                    showAddEditSheet = true
                    pendingMemoType = nil
                }
            }
            .onChange(of: showAddEditSheet) { oldValue, newValue in
                if !newValue {
                    // Sheet закрыт, сбрасываем состояния
                    memoToEdit = nil
                    pendingMemoType = nil
                }
            }
            .onChange(of: showViewer) { oldValue, newValue in
                if !newValue {
                    // Viewer закрыт, сбрасываем состояния
                    viewerItem = nil
                }
            }
            .sheet(isPresented: $showAddEditSheet) {
                if showAddEditSheet {
                    switch newMemoType {
                    case .noteAlbum:
                        EditMemoView(memoToEdit: $memoToEdit, memoType: .noteAlbum)
                            .id("note-\(currentSheetId)")
                    case .list:
                        EditMemoView(memoToEdit: $memoToEdit, memoType: .list)
                            .id("list-\(currentSheetId)")
                    case .counter:
                        EditMemoView(memoToEdit: $memoToEdit, memoType: .counter)
                            .id("counter-\(currentSheetId)")
                    case .streak:
                        EditMemoView(memoToEdit: $memoToEdit, memoType: .streak)
                            .id("streak-\(currentSheetId)")
                    case .mood:
                        EditMemoView(memoToEdit: $memoToEdit, memoType: .mood)
                            .id("mood-\(currentSheetId)")
                    case .skill:
                        EditMemoView(memoToEdit: $memoToEdit, memoType: .skill)
                            .id("skill-\(currentSheetId)")
                    case .budget:
                        EditMemoView(memoToEdit: $memoToEdit, memoType: .budget)
                            .id("budget-\(currentSheetId)")
                    case .time:
                        EditMemoView(memoToEdit: $memoToEdit, memoType: .time)
                            .id("time-\(currentSheetId)")
                    case .health:
                        EditMemoView(memoToEdit: $memoToEdit, memoType: .health)
                            .id("health-\(currentSheetId)")
                    case .tracker:
                        EditMemoView(memoToEdit: $memoToEdit, memoType: .tracker)
                            .id("tracker-\(currentSheetId)")
                    }
                }
            }
            .sheet(isPresented: $showQuickTimeEditor) {
                EditMemoView(memoToEdit: .constant(nil), memoType: .time)
            }
            .sheet(isPresented: $showQuickSkillEditor) {
                SkillEditorSheet(skill: nil) { newSkill in
                    createMemoFromQuickSkill(newSkill)
                    showQuickSkillEditor = false
                }
            }
            .sheet(isPresented: $showStatistics) {
                MemoStatisticsView(memoItems: memoItems)
            }
            .sheet(isPresented: $showTagFilter) {
                TagFilterView(selectedTag: $selectedTagFilter, allTags: Array(Set(memoItems.flatMap { $0.tags })).sorted())
            }
            .fullScreenCover(item: $selectedMemoItem) { item in
                NavigationStack {
                    memoDetailView(for: item)
                }
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
    // MARK: - Filter Panel
    private var filterPanel: some View {
        VStack(spacing: 12) {
            Divider()
            
            // Type Filter
            VStack(alignment: .leading, spacing: 8) {
                Text("Filter by type")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                    ForEach(MemoItemType.allCases.filter { $0 != .tracker }) { type in
                        Button {
                            withAnimation(.spring()) {
                                if selectedTypeFilter == type {
                                    selectedTypeFilter = nil
                                } else {
                                    selectedTypeFilter = type
                                }
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: type.iconName)
                                    .font(.title3)
                                    .foregroundColor(selectedTypeFilter == type ? .white : type.color)
                                Text(type.displayName)
                                    .font(.caption2)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(height: 60)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedTypeFilter == type ? type.color : Color(UIColor.secondarySystemBackground))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(selectedTypeFilter == type ? type.color : Color.clear, lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // Sort Options
            VStack(alignment: .leading, spacing: 8) {
                Text("Sorting")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Picker("Sorting", selection: $sortOrder) {
                    ForEach(SortOrder.allCases, id: \.self) { order in
                        Label(order.displayName, systemImage: order.icon)
                            .tag(order)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // Clear Filters Button
            if selectedTypeFilter != nil || selectedTagFilter != nil {
                Button("Clear filter") {
                    withAnimation(.spring()) {
                        selectedTypeFilter = nil
                        selectedTagFilter = nil
                        searchText = ""
                    }
                }
                .foregroundColor(.red)
                .padding(.top, 8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .background(Color(UIColor.systemBackground))
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    // MARK: - Memo List
    private var memoList: some View {
        List {
                ForEach(filteredAndSortedItems) { item in
                    Button {
                        selectedMemoItem = item
                    } label: {
                        MemoCardView(memoItem: item, design: memoDesign)
                    }
                    .buttonStyle(.plain)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .padding(.horizontal, 1)
                    .padding(.vertical, 1)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
                        .contextMenu {
                            Button {
                                memoToEdit = item
                                showAddEditSheet = true
                            } label: {
                                Label("Edit Memo", systemImage: "pencil")
                            }
                            
                            Button {
                                viewerItem = item
                                showViewer = true
                            } label: {
                                Label("View Details", systemImage: "doc.text.magnifyingglass")
                            }
                            
                            Button {
                                duplicateMemo(item)
                            } label: {
                                Label("Duplicate", systemImage: "plus.square.on.square")
                            }
                            
                            Button(role: .destructive) {
                                if let index = filteredAndSortedItems.firstIndex(where: { $0.id == item.id }) {
                                    deleteMemo(at: IndexSet([index]))
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                if let index = filteredAndSortedItems.firstIndex(where: { $0.id == item.id }) {
                                    deleteMemo(at: IndexSet([index]))
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            
                            Button {
                                memoToEdit = item
                                showAddEditSheet = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.orange)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                // Archive/Unarchive item
                                if item.status == .archived {
                                    item.status = .active
                                } else {
                                    item.status = .archived
                                }
                                try? modelContext.save()
                                NotificationCenter.default.post(name: .memoStatusDidChange, object: nil)
                            } label: {
                                Label(
                                    item.status == .archived ? "Unarchive" : "Archive",
                                    systemImage: item.status == .archived ? "tray.and.arrow.up" : "archivebox"
                                )
                            }
                            .tint(.blue)
                        }
                }
                .onDelete(perform: deleteMemo)
            }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .padding(.horizontal, 10)
        .contentMargins(.top, 0, for: .scrollContent)
        .listSectionSpacing(0)
        .background(Color(UIColor.systemGroupedBackground))
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: filteredAndSortedItems.map { "\($0.id)-\($0.creationDate.timeIntervalSince1970)" })
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: memosOrderKey)
        .refreshable {
            // Simulate refresh
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
        .onAppear {
            // Sync calendar visibility with global settings
            compactCalendarManager.isVisible = globalCalendarVisibility
        }
            .onReceive(NotificationCenter.default.publisher(for: .appCalendarVisibilityDidChange)) { _ in
                compactCalendarManager.isVisible = globalCalendarVisibility
            }
            .onReceive(NotificationCenter.default.publisher(for: .memoStatusDidChange)) { _ in
                // Обновляем ключ для триггера анимации перемещения карточек
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    memosOrderKey = UUID()
                }
            }
    }
    
    // MARK: - Memo Detail View
    @ViewBuilder
    private func memoDetailView(for item: MemoItem) -> some View {
        if item.itemType == .list {
            // Special view for lists
            ListContentView(item: item, isReorderMode: $isReorderMode, showCompleted: $showCompleted, showListStatistics: $showListStatistics)
                .navigationTitle(item.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            selectedMemoItem = nil
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
                                selectedMemoItem = nil
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
            // Special view for note albums
            NoteAlbumContentView(item: item, isReorderMode: $isNoteAlbumReorderMode, showNoteAlbumStatistics: $showNoteAlbumStatistics)
                .navigationTitle(item.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            selectedMemoItem = nil
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
                                selectedMemoItem = nil
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
            // Special view for counters
            CounterContentView(item: item, showCounterStatistics: $showCounterStatistics)
                .navigationTitle(item.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            selectedMemoItem = nil
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
                                selectedMemoItem = nil
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
            // Special view for streaks
            StreakContentView(item: item, showStreakStatistics: $showStreakStatistics)
                .navigationTitle(item.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            selectedMemoItem = nil
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
                                selectedMemoItem = nil
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
            // Special view for skills
            SkillContentView(item: item, showSkillStatistics: $showSkillStatistics)
                .navigationTitle(item.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            selectedMemoItem = nil
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
                                selectedMemoItem = nil
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
            // Special view for budgets
            BudgetContentView(item: item, showBudgetStatistics: $showBudgetStatistics)
                .navigationTitle(item.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            selectedMemoItem = nil
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
                                selectedMemoItem = nil
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
            // Special view for mood
            MoodContentView(item: item)
                .navigationTitle(item.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            selectedMemoItem = nil
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
                                selectedMemoItem = nil
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
            // Special view for time
            TimeContentView(item: item)
                .navigationTitle(item.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            selectedMemoItem = nil
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
                                selectedMemoItem = nil
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
            // Special view for health
            HealthContentView(item: item)
                .navigationTitle(item.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            selectedMemoItem = nil
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
                                selectedMemoItem = nil
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
            // Special view for tracker
            TrackerContentView(item: item)
                .navigationTitle(item.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            selectedMemoItem = nil
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
                                selectedMemoItem = nil
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
                            selectedMemoItem = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.body.weight(.semibold))
                                .foregroundColor(.primary)
                        }
                    }
                }
        }
    }
    
    private func createNewMemo(_ type: MemoItemType) {
        memoToEdit = nil
        pendingMemoType = type
    }
    
    private func deleteMemo(at offsets: IndexSet) {
        for index in offsets {
            let memo = memoItems[index]
            modelContext.delete(memo)
        }
    }
    
    private func duplicateMemo(_ memo: MemoItem) {
        let duplicatedMemo = MemoItem(
            title: "\(memo.title) (копия)",
            orderIndex: memo.orderIndex,
            type: memo.itemType,
            tags: memo.tags
        )
        duplicatedMemo.contentData = memo.contentData
        modelContext.insert(duplicatedMemo)
        
        do {
            try modelContext.save()
        } catch {
            print("Error duplicating memo: \(error)")
        }
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
    
    
    private func startQuickHealthCreation() {
        hapticManager.selectionChanged()
        let newMemo = MemoItem(
            title: MemoItemType.health.displayName,
            orderIndex: Int(Date().timeIntervalSince1970),
            type: .health
        )
        
        if let data = try? JSONEncoder().encode(MemoHealthContent()) {
            newMemo.contentData = data
        }
        
        modelContext.insert(newMemo)
        
        do {
            try modelContext.save()
            selectedMemoItem = newMemo
        } catch {
            print("Error creating quick health memo: \(error)")
        }
    }
    
    private func createMemoFromQuickNoteAlbum(_ note: MemoNoteAlbumItem) {
        var sanitizedNote = note
        let trimmedTitle = sanitizedNote.title.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitizedNote.title = trimmedTitle
        
        let memoTitle = trimmedTitle.isEmpty ? "Без названия" : trimmedTitle
        let orderIndex = Int(Date().timeIntervalSince1970)
        
        let newMemo = MemoItem(
            title: memoTitle,
            orderIndex: orderIndex,
            type: .noteAlbum
        )
        
        if let data = try? JSONEncoder().encode([sanitizedNote]) {
            newMemo.contentData = data
        }
        
        modelContext.insert(newMemo)
        
        do {
            try modelContext.save()
            hapticManager.completionSuccess()
        } catch {
            print("Error saving quick note memo: \(error)")
        }
    }
    
    private func createMemoFromQuickSkill(_ skill: MemoSkillContent.SkillItem) {
        var content = MemoSkillContent()
        var sanitizedSkill = skill
        sanitizedSkill.name = sanitizedSkill.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if sanitizedSkill.name.isEmpty {
            sanitizedSkill.name = MemoItemType.skill.displayName
        }
        
        // Add initial history entry
        var skillWithHistory = sanitizedSkill
        skillWithHistory.history.append(
            MemoSkillContent.SkillItem.SkillEntry(
                date: Date(),
                level: sanitizedSkill.currentLevel,
                note: "Начальный уровень"
            )
        )
        
        content.skills = [skillWithHistory]
        content.currentLevel = sanitizedSkill.currentLevel
        content.colorHex = sanitizedSkill.colorHex
        content.iconName = sanitizedSkill.iconName
        content.customImageData = sanitizedSkill.customImageData
        
        let orderIndex = Int(Date().timeIntervalSince1970)
        let newMemo = MemoItem(
            title: sanitizedSkill.name,
            orderIndex: orderIndex,
            type: .skill
        )
        
        if let data = try? JSONEncoder().encode(content) {
            newMemo.contentData = data
        }
        
        modelContext.insert(newMemo)
        
        do {
            try modelContext.save()
            selectedMemoItem = newMemo
            hapticManager.completionSuccess()
        } catch {
            print("Error creating quick skill memo: \(error)")
        }
    }
    
    
}

private extension AllMemoView {
    var currentMemoSettings: MemoSettings {
        if let first = memoSettings.first { return first }
        let s = MemoSettings()
        modelContext.insert(s)
        return s
    }
    
    @ViewBuilder
    var memoMenuContent: some View {
        addMemoMenu
        Divider()
        filterMenu
        Divider()
        settingsMenuButton
    }
    
    private var addMemoMenu: some View {
        Menu("Add memo", systemImage: "plus.circle") {
            ForEach(MemoItemType.allCases.filter { $0 != .tracker }) { type in
                Button {
                    memoToEdit = nil
                    switch type {
                    case .noteAlbum:
                        memoToEdit = nil
                        newMemoType = .noteAlbum
                        currentSheetId = UUID()
                        showAddEditSheet = true
                    case .health:
                        memoToEdit = nil
                        newMemoType = .health
                        currentSheetId = UUID()
                        showAddEditSheet = true
                    case .time:
                        memoToEdit = nil
                        newMemoType = .time
                        currentSheetId = UUID()
                        showAddEditSheet = true
                    case .budget:
                        memoToEdit = nil
                        newMemoType = .budget
                        currentSheetId = UUID()
                        showAddEditSheet = true
                    case .skill:
                        memoToEdit = nil
                        newMemoType = .skill
                        currentSheetId = UUID()
                        showAddEditSheet = true
                    case .mood:
                        memoToEdit = nil
                        newMemoType = .mood
                        currentSheetId = UUID()
                        showAddEditSheet = true
                    default:
                        pendingMemoType = type
                    }
                } label: {
                    Label("New \(type.displayName.lowercased())", systemImage: type.iconName)
                }
            }
        }
    }
    
    @ViewBuilder
    private var filterMenu: some View {
        Menu("Filter") {
            filterSearchButton
            toggleCompletedButton
            filterByTypeMenu
            filterByTagMenu
            sortMenu
            Divider()
            filtersPanelButton
            calendarFilterMenu
            Button("Statistics") { showStatistics = true }
        }
    }
    
    private var settingsMenuButton: some View {
        Button {
            showStatistics = false
            hapticManager.selectionChanged()
            showTagFilter = false
            pendingMemoType = nil
            showAddEditSheet = false
            showViewer = false
            showStatistics = false
        } label: {
            Label("Settings", systemImage: "gearshape")
        }
    }
    
    private var filterSearchButton: some View {
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
            Label(showSearchBar ? "Hide Search" : "Show Search", systemImage: "magnifyingglass")
        }
    }
    
    private var toggleCompletedButton: some View {
        Group {
            if !memoItems.isEmpty {
                Button {
                    hapticManager.selectionChanged()
                    withAnimation(.easeInOut(duration: 0.3)) {
                        localShowCompletedMemos.toggle()
                        let settings = currentMemoSettings
                        settings.showCompletedMemos = localShowCompletedMemos
                        try? modelContext.save()
                    }
                } label: {
                    Label(localShowCompletedMemos ? "Hide Completed" : "Show Completed", systemImage: localShowCompletedMemos ? "eye.slash" : "eye")
                }
            }
        }
    }
    
    private var filterByTypeMenu: some View {
        Menu("Filter by type") {
            Button {
                selectedTypeFilter = nil
            } label: {
                HStack {
                    Text("All Types")
                    Spacer()
                    if selectedTypeFilter == nil { Image(systemName: "checkmark") }
                }
            }
            ForEach(MemoItemType.allCases.filter { $0 != .tracker }, id: \.self) { type in
                Button {
                    selectedTypeFilter = type
                } label: {
                    HStack {
                        Text(type.displayName)
                        Spacer()
                        if selectedTypeFilter == type { Image(systemName: "checkmark") }
                    }
                }
            }
        }
    }
    
    private var filterByTagMenu: some View {
        Menu("Filter by tag") {
            Button {
                selectedTagFilter = nil
            } label: {
                HStack {
                    Text("All Tags")
                    Spacer()
                    if selectedTagFilter == nil { Image(systemName: "checkmark") }
                }
            }
            ForEach(Array(Set(memoItems.flatMap { $0.tags })).sorted(), id: \.self) { tag in
                Button {
                    selectedTagFilter = tag
                } label: {
                    HStack {
                        Text(tag)
                        Spacer()
                        if selectedTagFilter == tag { Image(systemName: "checkmark") }
                    }
                }
            }
        }
    }
    
    private var sortMenu: some View {
        Menu("Sort") {
            ForEach(SortOrder.allCases, id: \.self) { order in
                Button {
                    sortOrder = order
                } label: {
                    HStack {
                        Text(order.displayName)
                        Spacer()
                        if sortOrder == order { Image(systemName: "checkmark") }
                    }
                }
            }
        }
    }
    
    private var filtersPanelButton: some View {
        Button {
            hapticManager.selectionChanged()
            showFilters.toggle()
        } label: {
            Label(showFilters ? "Hide Filters Panel" : "Show Filters Panel", systemImage: showFilters ? "eye.slash" : "line.3.horizontal.decrease.circle")
        }
    }
    
    private var calendarFilterMenu: some View {
        Menu("Calendar filter") {
            Button {
                compactCalendarManager.goToToday()
                hapticManager.selectionChanged()
            } label: {
                Label("Today", systemImage: "calendar")
            }
            
            Button {
                hapticManager.selectionChanged()
                compactCalendarManager.selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: compactCalendarManager.selectedDate) ?? .now
            } label: {
                Label("Previous Day", systemImage: "chevron.left")
            }
            
            Button {
                hapticManager.selectionChanged()
                compactCalendarManager.selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: compactCalendarManager.selectedDate) ?? .now
            } label: {
                Label("Next Day", systemImage: "chevron.right")
            }
        }
    }
}


