import SwiftUI
import SwiftData

// Presentation · Memo — главный экран модуля: навигация по типам мемо, список, статистика.
// Фильтрация: `MemoListViewModel` → `FilterMemoItemsUseCase`.
//
// Папка **AllMemo**: корневой экран + расширения (список, детали по подтипам, меню, действия, сортировка).

// MARK: Корневой layout — календарь, меню, список
struct AllMemoView: View {
    @Environment(\.modelContext) var modelContext
    @Query(sort: [SortDescriptor(\MemoItem.orderIndex, order: .forward)]) var memoItems: [MemoItem]
    @Query var spheres: [Sphere]
    @Query var appCalendarSettings: [AppCalendarSettings]
    @Query var memoSettings: [MemoSettings]
    @Query var appDesignSettings: [AppDesignSettings]

    @State var showAddEditSheet = false
    @State var memoToEdit: MemoItem?
    @State var newMemoType: MemoItemType = .noteAlbum
    @State var pendingMemoType: MemoItemType? = nil
    @State var showViewer = false
    @State var viewerItem: MemoItem?
    @State var showStatistics = false
    @State var currentSheetId = UUID()

    @State var searchText = ""
    @State var selectedTypeFilter: MemoItemType?
    @State var selectedTagFilter: String?
    @State var showFilters = false
    @State var showTagFilter = false
    @State var showSearchBar = false
    @EnvironmentObject var calendarManager: CalendarManager
    @State var localShowArchivedMemos: Bool = true
    @State var memoDesign: AppDesign = .basic
    @State var selectedMemoItem: MemoItem?
    @State var isReorderMode = false
    @State var showCompleted = true
    @State var showListStatistics = true
    @State var isNoteAlbumReorderMode = false
    @State var showNoteAlbumStatistics = true
    @State var showArchivedNotes = false
    @State var triggerAddNoteForAlbum = false
    @State var triggerAddListItemForList = false
    @State var showCounterStatistics = false
    @State var showStreakStatistics = false
    @State var showSkillStatistics = false
    @State var showBudgetStatistics = false
    @State var showTimeStatistics = false
    @State var showHealthStatistics = false
    @State var showMoodStatistics = false
    @State var showCalendarStatistics = false
    @State var showQuickTimeEditor = false
    @State var showQuickSkillEditor = false
    @State var showDeleteMemoConfirmation: Bool = false
    @State var memoPendingDeletion: MemoItem?
    @State var showArchiveMemoConfirmation: Bool = false
    @State var memoPendingArchive: MemoItem?
    @State var memosOrderKey: UUID = UUID()
    @State var showSettingsSheet = false
    @StateObject var viewModel: MemoListViewModel

    let hapticManager = HapticSoundManager.shared

    init() {
        _viewModel = StateObject(wrappedValue: MemoListViewModel())
    }

    var globalCalendarVisibility: Bool {
        appCalendarSettings.first?.isVisible ?? true
    }

    var globalCalendarVisibilityBinding: Binding<Bool> {
        Binding(
            get: { globalCalendarVisibility },
            set: { _ in
                // Calendar visibility is controlled globally from Vision
            }
        )
    }

    var filteredAndSortedItems: [MemoItem] {
        viewModel.filteredItems(
            memoItems: memoItems,
            selectedDate: calendarManager.selectedDate,
            calendarVisible: globalCalendarVisibility,
            searchText: searchText,
            selectedTypeFilter: selectedTypeFilter,
            selectedTagFilter: selectedTagFilter,
            showArchivedMemos: localShowArchivedMemos
        )
    }

    /// Пустой список из‑за поиска или фильтров типа/тега — показываем «Nothing found». Иначе (только календарь и т.п.) — `noMemos`.
    private var hasActiveMemoQueryFilters: Bool {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty || selectedTypeFilter != nil || selectedTagFilter != nil
    }

    func noteAlbumDisplayTitle(_ title: String) -> String {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty || t == "Мои заметки" || t == "Альбом заметок" { return "My notes" }
        return title
    }

    @ViewBuilder
    private var deleteMemoConfirmationOverlay: some View {
        if showDeleteMemoConfirmation, let memo = memoPendingDeletion {
            let info = memoImpactInfo(memo)
            ImpactActionPresenter.dialog(
                isPresented: $showDeleteMemoConfirmation,
                spheres: spheres,
                sphereID: info.sphereID,
                negativeImpact: info.negativeImpact,
                title: "Delete memo?",
                message: "This memo and its data will be permanently deleted.",
                messageWithImpact: "Delete this memo. You can also apply its miss decrease to the area.",
                primaryTitle: "Delete",
                primaryTint: .red,
                secondaryTitleFormat: "Delete and apply negative impact (-%@%%) on area",
                secondaryTint: .red,
                onPrimary: {
                    hapticManager.itemDeleted()
                    memoPendingDeletion = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        deleteMemo(memo, applyNegativeImpact: false)
                    }
                },
                onSecondary: {
                    hapticManager.itemDeleted()
                    memoPendingDeletion = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        deleteMemo(memo, applyNegativeImpact: true)
                    }
                },
                onCancel: { memoPendingDeletion = nil }
            )
        }
    }

    @ViewBuilder
    private var archiveMemoConfirmationOverlay: some View {
        if showArchiveMemoConfirmation, let memo = memoPendingArchive {
            let info = memoImpactInfo(memo)
            let allowSecondary = memo.status != .archived
            ImpactActionPresenter.dialog(
                isPresented: $showArchiveMemoConfirmation,
                spheres: spheres,
                sphereID: info.sphereID,
                negativeImpact: info.negativeImpact,
                allowSecondaryAction: allowSecondary,
                title: memo.status == .archived ? "Unarchive memo?" : "Archive memo?",
                message: "This memo will be archived.",
                messageWithImpact: "Archive this memo. You can also apply its miss decrease to the area.",
                primaryTitle: memo.status == .archived ? "Unarchive" : "Archive",
                primaryTint: .gray,
                secondaryTitleFormat: "Archive and apply negative impact (-%@%%) on area",
                secondaryTint: .gray,
                onPrimary: {
                    hapticManager.selectionChanged()
                    memoPendingArchive = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation(.smooth(duration: 0.4)) {
                            archiveMemo(memo, applyNegativeImpact: false)
                        }
                    }
                },
                onSecondary: {
                    hapticManager.selectionChanged()
                    memoPendingArchive = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation(.smooth(duration: 0.4)) {
                            archiveMemo(memo, applyNegativeImpact: true)
                        }
                    }
                },
                onCancel: { memoPendingArchive = nil }
            )
        }
    }

    /// Как `mainContent` + `goalsList` в `AllGoalsView` / список в `AllTasksView`.
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
                        placeholder: "search memos..."
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
                    memoMenuContent
                }
            )

            if showFilters {
                // Filter panel UI removed in favor of menu-based filters
            }

            if filteredAndSortedItems.isEmpty {
                if hasActiveMemoQueryFilters {
                    EmptyStateView.noResults(searchText: searchText)
                        .tabEmptyStateLayout()
                } else {
                    EmptyStateView.noMemos()
                        .tabEmptyStateLayout()
                }
            } else {
                memoList
            }
        }
    }

    var body: some View {
        NavigationStack {
            mainContent
                .background {
                    Color(UIColor.systemGroupedBackground)
                        .ignoresSafeArea(edges: .top)
                }
                .onAppear {
                localShowArchivedMemos = currentMemoSettings.showArchivedMemos
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
                    memoToEdit = nil
                    pendingMemoType = nil
                    selectedMemoItem = nil
                }
            }
            .onChange(of: showViewer) { oldValue, newValue in
                if !newValue {
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
                    case .calendar:
                        EditMemoView(memoToEdit: $memoToEdit, memoType: .calendar)
                            .id("calendar-\(currentSheetId)")
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
            .sheet(isPresented: $showSettingsSheet) {
                SettingsView()
            }
            .sheet(isPresented: $showTagFilter) {
                TagFilterView(selectedTag: $selectedTagFilter, allTags: Array(Set(memoItems.flatMap { $0.tags })).sorted())
            }
            .fullScreenCover(item: $selectedMemoItem) { item in
                NavigationStack {
                    memoDetailView(for: item)
                }
            }
            .overlay { deleteMemoConfirmationOverlay }
            .overlay { archiveMemoConfirmationOverlay }
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
}
