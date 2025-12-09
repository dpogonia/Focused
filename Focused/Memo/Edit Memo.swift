import SwiftUI
import SwiftData

// MARK: - Edit Memo View
struct EditMemoView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Binding var memoToEdit: MemoItem?
    let memoType: MemoItemType

    @StateObject private var viewModel: EditMemoViewModel
    @State private var showMoodScalePicker = false

    init(memoToEdit: Binding<MemoItem?>, memoType: MemoItemType) {
        self._memoToEdit = memoToEdit
        self.memoType = memoType
        self._viewModel = StateObject(wrappedValue: EditMemoViewModel(memoToEdit: memoToEdit.wrappedValue, memoType: memoType))
    }

    private var isEditing: Bool { memoToEdit != nil }
    
    // MARK: - Form Sections
    private var titleSection: some View {
        Section("Title") {
            HStack {
                TextField("insert title", text: $viewModel.title)
                iconSelectionView
            }
        }
    }
    
    @ViewBuilder
    private var iconSelectionView: some View {
        if memoType == .list {
            IconSelectionView(
                selectedIconName: Binding(
                    get: { viewModel.listContent.iconName },
                    set: { viewModel.listContent.iconName = $0 }
                ),
                colorForPicker: viewModel.listColorForPicker
            )
        } else if memoType == .noteAlbum {
            IconSelectionView(
                selectedIconName: Binding(
                    get: { viewModel.noteAlbumContent.iconName },
                    set: { viewModel.noteAlbumContent.iconName = $0 }
                ),
                colorForPicker: viewModel.noteAlbumColorForPicker
            )
        } else if memoType == .counter {
            IconSelectionView(
                selectedIconName: Binding(
                    get: { viewModel.counterContent.iconName },
                    set: { viewModel.counterContent.iconName = $0 }
                ),
                colorForPicker: viewModel.counterColorForPicker
            )
        } else if memoType == .streak {
            IconSelectionView(
                selectedIconName: Binding(
                    get: { viewModel.streakContent.iconName },
                    set: { viewModel.streakContent.iconName = $0 }
                ),
                colorForPicker: viewModel.streakColorForPicker
            )
        } else if memoType == .mood {
            IconSelectionView(
                selectedIconName: Binding(
                    get: { viewModel.moodContent.iconName },
                    set: { viewModel.moodContent.iconName = $0 }
                ),
                colorForPicker: viewModel.moodColorForPicker
            )
        } else if memoType == .skill {
            IconSelectionView(
                selectedIconName: Binding(
                    get: { viewModel.skillContent.iconName },
                    set: { viewModel.skillContent.iconName = $0 }
                ),
                colorForPicker: viewModel.skillColorForPicker
            )
        } else if memoType == .time {
            IconSelectionView(
                selectedIconName: Binding(
                    get: { viewModel.timeContent.iconName },
                    set: { viewModel.timeContent.iconName = $0 }
                ),
                colorForPicker: viewModel.timeColorForPicker
            )
        } else if memoType == .health {
            IconSelectionView(
                selectedIconName: Binding(
                    get: { viewModel.healthContent.iconName },
                    set: { viewModel.healthContent.iconName = $0 }
                ),
                colorForPicker: viewModel.healthColorForPicker
            )
        } else if memoType == .budget {
            IconSelectionView(
                selectedIconName: Binding(
                    get: { viewModel.budgetContent.iconName },
                    set: { viewModel.budgetContent.iconName = $0 }
                ),
                colorForPicker: viewModel.budgetColorForPicker
            )
        }
    }
    
    @ViewBuilder
    private var sphereSection: some View {
        if memoType == .noteAlbum {
            Section("Sphere") {
                SpherePickerView(selectedSphereID: $viewModel.noteAlbumSphereID)
            }
        } else if memoType == .list {
            Section("Sphere") {
                SpherePickerView(selectedSphereID: Binding(
                    get: { viewModel.listContent.sphereID },
                    set: { viewModel.listContent.sphereID = $0 }
                ))
            }
        } else if memoType == .counter {
            Section("Sphere") {
                SpherePickerView(selectedSphereID: Binding(
                    get: { viewModel.counterContent.sphereID },
                    set: { viewModel.counterContent.sphereID = $0 }
                ))
            }
        } else if memoType == .streak {
            Section("Sphere") {
                SpherePickerView(selectedSphereID: Binding(
                    get: { viewModel.streakContent.sphereID },
                    set: { viewModel.streakContent.sphereID = $0 }
                ))
            }
        } else if memoType == .mood {
            Section("Sphere") {
                SpherePickerView(selectedSphereID: Binding(
                    get: { viewModel.moodContent.sphereID },
                    set: { viewModel.moodContent.sphereID = $0 }
                ))
            }
        } else if memoType == .skill {
            Section("Sphere") {
                SpherePickerView(selectedSphereID: Binding(
                    get: { viewModel.skillContent.sphereID },
                    set: { viewModel.skillContent.sphereID = $0 }
                ))
            }
        } else if memoType == .time {
            Section("Sphere") {
                SpherePickerView(selectedSphereID: Binding(
                    get: { viewModel.timeContent.sphereID },
                    set: { viewModel.timeContent.sphereID = $0 }
                ))
            }
        } else if memoType == .health {
            Section("Sphere") {
                SpherePickerView(selectedSphereID: Binding(
                    get: { viewModel.healthContent.sphereID },
                    set: { viewModel.healthContent.sphereID = $0 }
                ))
            }
        } else if memoType == .budget {
            Section("Sphere") {
                SpherePickerView(selectedSphereID: Binding(
                    get: { viewModel.budgetContent.sphereID },
                    set: { viewModel.budgetContent.sphereID = $0 }
                ))
            }
        }
    }
    
    @ViewBuilder
    private var colorSection: some View {
        if memoType == .mood {
            Section("Color") {
                VStack(alignment: .leading, spacing: 8) {
                    ColorSelectionView(
                        availableColors: AppConstants.Colors.palette,
                        selectedColorHex: $viewModel.moodColorHex,
                        colorForPicker: $viewModel.moodColorForPicker,
                        sphereColorHex: getMoodSphereColorHex()
                    )
                }
                .padding(.vertical, 5)
            }
        } else if memoType == .skill {
            Section("Color") {
                VStack(alignment: .leading, spacing: 8) {
                    ColorSelectionView(
                        availableColors: AppConstants.Colors.palette,
                        selectedColorHex: $viewModel.skillColorHex,
                        colorForPicker: $viewModel.skillColorForPicker,
                        sphereColorHex: getSkillSphereColorHex()
                    )
                }
                .padding(.vertical, 5)
            }
        } else if memoType == .time {
            Section("Color") {
                VStack(alignment: .leading, spacing: 8) {
                    ColorSelectionView(
                        availableColors: AppConstants.Colors.palette,
                        selectedColorHex: $viewModel.timeColorHex,
                        colorForPicker: $viewModel.timeColorForPicker,
                        sphereColorHex: getTimeSphereColorHex()
                    )
                }
                .padding(.vertical, 5)
            }
        } else if memoType == .health {
            Section("Color") {
                VStack(alignment: .leading, spacing: 8) {
                    ColorSelectionView(
                        availableColors: AppConstants.Colors.palette,
                        selectedColorHex: $viewModel.healthColorHex,
                        colorForPicker: $viewModel.healthColorForPicker,
                        sphereColorHex: getHealthSphereColorHex()
                    )
                }
                .padding(.vertical, 5)
            }
        } else if memoType == .budget {
            Section("Color") {
                VStack(alignment: .leading, spacing: 8) {
                    ColorSelectionView(
                        availableColors: AppConstants.Colors.palette,
                        selectedColorHex: $viewModel.budgetColorHex,
                        colorForPicker: $viewModel.budgetColorForPicker,
                        sphereColorHex: getBudgetSphereColorHex()
                    )
                }
                .padding(.vertical, 5)
            }
        }
    }
    
    @ViewBuilder
    private var notesSection: some View {
        if memoType == .mood {
            Section("Notes") {
                TextEditor(text: $viewModel.moodContent.notes)
                    .frame(minHeight: 80)
            }
        } else if memoType == .skill {
            Section("Notes") {
                TextEditor(text: $viewModel.skillContent.notes)
                    .frame(minHeight: 80)
            }
        } else if memoType == .time {
            Section("Notes") {
                TextEditor(text: $viewModel.timeContent.notes)
                    .frame(minHeight: 80)
            }
        } else if memoType == .health {
            Section("Notes") {
                TextEditor(text: $viewModel.healthContent.notes)
                    .frame(minHeight: 80)
            }
        } else if memoType == .budget {
            Section("Notes") {
                TextEditor(text: $viewModel.budgetContent.notes)
                    .frame(minHeight: 80)
            }
        }
    }
    
    private var tagsSection: some View {
        Section("Tags") {
            MemoTagsSelectionView(selectedTags: $viewModel.selectedTags)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                titleSection
                sphereSection
                colorSection
                contentSection
                notesSection
                tagsSection
            }
            .navigationTitle(isEditing ? "Edit" : "Create")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Create") {
                        saveMemo()
                    }
                    .disabled(viewModel.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .modifier(NoteAlbumColorModifiers(viewModel: viewModel, modelContext: modelContext))
    }
    
    // MARK: - Helper Modifiers
    private struct NoteAlbumColorModifiers: ViewModifier {
        @ObservedObject var viewModel: EditMemoViewModel
        let modelContext: ModelContext
        
        func body(content: Content) -> some View {
            content
                .modifier(NoteAlbumColorHandlers(viewModel: viewModel, modelContext: modelContext))
                .modifier(ListColorHandlers(viewModel: viewModel, modelContext: modelContext))
                .modifier(CounterColorHandlers(viewModel: viewModel, modelContext: modelContext))
                .modifier(StreakColorHandlers(viewModel: viewModel, modelContext: modelContext))
                .modifier(MoodColorHandlers(viewModel: viewModel, modelContext: modelContext))
                .modifier(SkillColorHandlers(viewModel: viewModel, modelContext: modelContext))
                .modifier(TimeColorHandlers(viewModel: viewModel, modelContext: modelContext))
                .modifier(HealthColorHandlers(viewModel: viewModel, modelContext: modelContext))
                .modifier(BudgetColorHandlers(viewModel: viewModel, modelContext: modelContext))
        }
    }
    
    private struct NoteAlbumColorHandlers: ViewModifier {
        @ObservedObject var viewModel: EditMemoViewModel
        let modelContext: ModelContext
        
        func body(content: Content) -> some View {
            content
                .onChange(of: viewModel.noteAlbumColorForPicker) { old, newColor in
                    if let newHex = newColor.toHex() {
                        if !viewModel.isUpdatingColorFromSphere {
                            viewModel.noteAlbumColorManuallyChanged = true
                        }
                        viewModel.noteAlbumColorHex = newHex
                    }
                }
                .onChange(of: viewModel.noteAlbumColorHex) { old, newHex in
                    if !viewModel.isUpdatingColorFromSphere {
                        viewModel.noteAlbumColorManuallyChanged = true
                    }
                    viewModel.noteAlbumColorForPicker = Color(hex: newHex)
                }
                .onChange(of: viewModel.noteAlbumSphereID) { oldSphereID, newSphereID in
                    if let newSphereID = newSphereID {
                        let fetchDescriptor = FetchDescriptor<Sphere>(predicate: #Predicate<Sphere> { $0.id == newSphereID })
                        if let sphere = try? modelContext.fetch(fetchDescriptor).first {
                            if !viewModel.noteAlbumColorManuallyChanged {
                                viewModel.isUpdatingColorFromSphere = true
                                viewModel.noteAlbumColorHex = sphere.colorHex
                                viewModel.noteAlbumColorForPicker = Color(hex: sphere.colorHex)
                                DispatchQueue.main.async {
                                    viewModel.isUpdatingColorFromSphere = false
                                }
                            }
                        }
                    }
                }
        }
    }
    
    private struct ListColorHandlers: ViewModifier {
        @ObservedObject var viewModel: EditMemoViewModel
        let modelContext: ModelContext
        
        func body(content: Content) -> some View {
            content
                .onChange(of: viewModel.listColorForPicker) { old, newColor in
                    if let newHex = newColor.toHex() {
                        if !viewModel.isUpdatingListColorFromSphere {
                            viewModel.listColorManuallyChanged = true
                        }
                        viewModel.listColorHex = newHex
                    }
                }
                .onChange(of: viewModel.listColorHex) { old, newHex in
                    if !viewModel.isUpdatingListColorFromSphere {
                        viewModel.listColorManuallyChanged = true
                    }
                    viewModel.listColorForPicker = Color(hex: newHex)
                }
                .onChange(of: viewModel.listContent.sphereID) { oldSphereID, newSphereID in
                    if let newSphereID = newSphereID {
                        let fetchDescriptor = FetchDescriptor<Sphere>(predicate: #Predicate<Sphere> { $0.id == newSphereID })
                        if let sphere = try? modelContext.fetch(fetchDescriptor).first {
                            if !viewModel.listColorManuallyChanged {
                                viewModel.isUpdatingListColorFromSphere = true
                                viewModel.listColorHex = sphere.colorHex
                                viewModel.listColorForPicker = Color(hex: sphere.colorHex)
                                DispatchQueue.main.async {
                                    viewModel.isUpdatingListColorFromSphere = false
                                }
                            }
                        }
                    }
                }
        }
    }
    
    private struct CounterColorHandlers: ViewModifier {
        @ObservedObject var viewModel: EditMemoViewModel
        let modelContext: ModelContext
        
        func body(content: Content) -> some View {
            content
                .onChange(of: viewModel.counterColorForPicker) { old, newColor in
                    if let newHex = newColor.toHex() {
                        if !viewModel.isUpdatingCounterColorFromSphere {
                            viewModel.counterColorManuallyChanged = true
                        }
                        viewModel.counterColorHex = newHex
                    }
                }
                .onChange(of: viewModel.counterColorHex) { old, newHex in
                    if !viewModel.isUpdatingCounterColorFromSphere {
                        viewModel.counterColorManuallyChanged = true
                    }
                    viewModel.counterColorForPicker = Color(hex: newHex)
                }
                .onChange(of: viewModel.counterContent.sphereID) { oldSphereID, newSphereID in
                    if let newSphereID = newSphereID {
                        let fetchDescriptor = FetchDescriptor<Sphere>(predicate: #Predicate<Sphere> { $0.id == newSphereID })
                        if let sphere = try? modelContext.fetch(fetchDescriptor).first {
                            if !viewModel.counterColorManuallyChanged {
                                viewModel.isUpdatingCounterColorFromSphere = true
                                viewModel.counterColorHex = sphere.colorHex
                                viewModel.counterColorForPicker = Color(hex: sphere.colorHex)
                                DispatchQueue.main.async {
                                    viewModel.isUpdatingCounterColorFromSphere = false
                                }
                            }
                        }
                    } else {
                        viewModel.counterContent.positiveImpact = 0.0
                        viewModel.counterContent.negativeImpact = 0.0
                    }
                }
        }
    }
    
    private struct StreakColorHandlers: ViewModifier {
        @ObservedObject var viewModel: EditMemoViewModel
        let modelContext: ModelContext
        
        func body(content: Content) -> some View {
            content
                .onChange(of: viewModel.streakColorForPicker) { old, newColor in
                    if let newHex = newColor.toHex() {
                        if !viewModel.isUpdatingStreakColorFromSphere {
                            viewModel.streakColorManuallyChanged = true
                        }
                        viewModel.streakColorHex = newHex
                    }
                }
                .onChange(of: viewModel.streakColorHex) { old, newHex in
                    if !viewModel.isUpdatingStreakColorFromSphere {
                        viewModel.streakColorManuallyChanged = true
                    }
                    viewModel.streakColorForPicker = Color(hex: newHex)
                }
                .onChange(of: viewModel.streakContent.sphereID) { oldSphereID, newSphereID in
                    if let newSphereID = newSphereID {
                        let fetchDescriptor = FetchDescriptor<Sphere>(predicate: #Predicate<Sphere> { $0.id == newSphereID })
                        if let sphere = try? modelContext.fetch(fetchDescriptor).first {
                            if !viewModel.streakColorManuallyChanged {
                                viewModel.isUpdatingStreakColorFromSphere = true
                                viewModel.streakColorHex = sphere.colorHex
                                viewModel.streakColorForPicker = Color(hex: sphere.colorHex)
                                DispatchQueue.main.async {
                                    viewModel.isUpdatingStreakColorFromSphere = false
                                }
                            }
                        }
                    } else {
                        viewModel.streakContent.positiveImpact = 0.0
                        viewModel.streakContent.negativeImpact = 0.0
                    }
                }
        }
    }
    
    private struct MoodColorHandlers: ViewModifier {
        @ObservedObject var viewModel: EditMemoViewModel
        let modelContext: ModelContext
        
        func body(content: Content) -> some View {
            content
                .onChange(of: viewModel.moodColorForPicker) { old, newColor in
                    if let newHex = newColor.toHex() {
                        if !viewModel.isUpdatingMoodColorFromSphere {
                            viewModel.moodColorManuallyChanged = true
                        }
                        viewModel.moodColorHex = newHex
                    }
                }
                .onChange(of: viewModel.moodColorHex) { old, newHex in
                    if !viewModel.isUpdatingMoodColorFromSphere {
                        viewModel.moodColorManuallyChanged = true
                    }
                    viewModel.moodColorForPicker = Color(hex: newHex)
                }
                .onChange(of: viewModel.moodContent.sphereID) { oldSphereID, newSphereID in
                    if let newSphereID = newSphereID {
                        let fetchDescriptor = FetchDescriptor<Sphere>(predicate: #Predicate<Sphere> { $0.id == newSphereID })
                        if let sphere = try? modelContext.fetch(fetchDescriptor).first {
                            if !viewModel.moodColorManuallyChanged {
                                viewModel.isUpdatingMoodColorFromSphere = true
                                viewModel.moodColorHex = sphere.colorHex
                                viewModel.moodColorForPicker = Color(hex: sphere.colorHex)
                                DispatchQueue.main.async {
                                    viewModel.isUpdatingMoodColorFromSphere = false
                                }
                            }
                        }
                    }
                }
        }
    }
    
    private struct SkillColorHandlers: ViewModifier {
        @ObservedObject var viewModel: EditMemoViewModel
        let modelContext: ModelContext
        
        func body(content: Content) -> some View {
            content
                .onChange(of: viewModel.skillColorForPicker) { old, newColor in
                    if let newHex = newColor.toHex() {
                        if !viewModel.isUpdatingSkillColorFromSphere {
                            viewModel.skillColorManuallyChanged = true
                        }
                        viewModel.skillColorHex = newHex
                    }
                }
                .onChange(of: viewModel.skillColorHex) { old, newHex in
                    if !viewModel.isUpdatingSkillColorFromSphere {
                        viewModel.skillColorManuallyChanged = true
                    }
                    viewModel.skillColorForPicker = Color(hex: newHex)
                }
                .onChange(of: viewModel.skillContent.sphereID) { oldSphereID, newSphereID in
                    if let newSphereID = newSphereID {
                        let fetchDescriptor = FetchDescriptor<Sphere>(predicate: #Predicate<Sphere> { $0.id == newSphereID })
                        if let sphere = try? modelContext.fetch(fetchDescriptor).first {
                            if !viewModel.skillColorManuallyChanged {
                                viewModel.isUpdatingSkillColorFromSphere = true
                                viewModel.skillColorHex = sphere.colorHex
                                viewModel.skillColorForPicker = Color(hex: sphere.colorHex)
                                DispatchQueue.main.async {
                                    viewModel.isUpdatingSkillColorFromSphere = false
                                }
                            }
                        }
                    }
                }
        }
    }
    
    private struct TimeColorHandlers: ViewModifier {
        @ObservedObject var viewModel: EditMemoViewModel
        let modelContext: ModelContext
        
        func body(content: Content) -> some View {
            content
                .onChange(of: viewModel.timeColorForPicker) { old, newColor in
                    if let newHex = newColor.toHex() {
                        if !viewModel.isUpdatingTimeColorFromSphere {
                            viewModel.timeColorManuallyChanged = true
                        }
                        viewModel.timeColorHex = newHex
                    }
                }
                .onChange(of: viewModel.timeColorHex) { old, newHex in
                    if !viewModel.isUpdatingTimeColorFromSphere {
                        viewModel.timeColorManuallyChanged = true
                    }
                    viewModel.timeColorForPicker = Color(hex: newHex)
                }
                .onChange(of: viewModel.timeContent.sphereID) { oldSphereID, newSphereID in
                    if let newSphereID = newSphereID {
                        let fetchDescriptor = FetchDescriptor<Sphere>(predicate: #Predicate<Sphere> { $0.id == newSphereID })
                        if let sphere = try? modelContext.fetch(fetchDescriptor).first {
                            if !viewModel.timeColorManuallyChanged {
                                viewModel.isUpdatingTimeColorFromSphere = true
                                viewModel.timeColorHex = sphere.colorHex
                                viewModel.timeColorForPicker = Color(hex: sphere.colorHex)
                                DispatchQueue.main.async {
                                    viewModel.isUpdatingTimeColorFromSphere = false
                                }
                            }
                        }
                    }
                }
        }
    }
    
    private struct HealthColorHandlers: ViewModifier {
        @ObservedObject var viewModel: EditMemoViewModel
        let modelContext: ModelContext
        
        func body(content: Content) -> some View {
            content
                .onChange(of: viewModel.healthColorForPicker) { old, newColor in
                    if let newHex = newColor.toHex() {
                        if !viewModel.isUpdatingHealthColorFromSphere {
                            viewModel.healthColorManuallyChanged = true
                        }
                        viewModel.healthColorHex = newHex
                    }
                }
                .onChange(of: viewModel.healthColorHex) { old, newHex in
                    if !viewModel.isUpdatingHealthColorFromSphere {
                        viewModel.healthColorManuallyChanged = true
                    }
                    viewModel.healthColorForPicker = Color(hex: newHex)
                }
                .onChange(of: viewModel.healthContent.sphereID) { oldSphereID, newSphereID in
                    if let newSphereID = newSphereID {
                        let fetchDescriptor = FetchDescriptor<Sphere>(predicate: #Predicate<Sphere> { $0.id == newSphereID })
                        if let sphere = try? modelContext.fetch(fetchDescriptor).first {
                            if !viewModel.healthColorManuallyChanged {
                                viewModel.isUpdatingHealthColorFromSphere = true
                                viewModel.healthColorHex = sphere.colorHex
                                viewModel.healthColorForPicker = Color(hex: sphere.colorHex)
                                DispatchQueue.main.async {
                                    viewModel.isUpdatingHealthColorFromSphere = false
                                }
                            }
                        }
                    }
                }
        }
    }
    
    private struct BudgetColorHandlers: ViewModifier {
        @ObservedObject var viewModel: EditMemoViewModel
        let modelContext: ModelContext
        
        func body(content: Content) -> some View {
            content
                .onChange(of: viewModel.budgetColorForPicker) { old, newColor in
                    if let newHex = newColor.toHex() {
                        if !viewModel.isUpdatingBudgetColorFromSphere {
                            viewModel.budgetColorManuallyChanged = true
                        }
                        viewModel.budgetColorHex = newHex
                    }
                }
                .onChange(of: viewModel.budgetColorHex) { old, newHex in
                    if !viewModel.isUpdatingBudgetColorFromSphere {
                        viewModel.budgetColorManuallyChanged = true
                    }
                    viewModel.budgetColorForPicker = Color(hex: newHex)
                }
                .onChange(of: viewModel.budgetContent.sphereID) { oldSphereID, newSphereID in
                    if let newSphereID = newSphereID {
                        let fetchDescriptor = FetchDescriptor<Sphere>(predicate: #Predicate<Sphere> { $0.id == newSphereID })
                        if let sphere = try? modelContext.fetch(fetchDescriptor).first {
                            if !viewModel.budgetColorManuallyChanged {
                                viewModel.isUpdatingBudgetColorFromSphere = true
                                viewModel.budgetColorHex = sphere.colorHex
                                viewModel.budgetColorForPicker = Color(hex: sphere.colorHex)
                                DispatchQueue.main.async {
                                    viewModel.isUpdatingBudgetColorFromSphere = false
                                }
                            }
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private var contentSection: some View {
        switch memoType {
        case .noteAlbum:
            noteAlbumSection
        case .list:
            listSection
        case .counter:
            counterSection
        case .streak:
            streakSection
        case .mood:
            moodSection
        case .skill:
            skillSection
        case .budget:
            budgetSection
        case .time:
            timeSection
        case .health:
            healthSection
        case .tracker:
            trackerSection
        }
    }

    private var noteAlbumSection: some View {
        Section("Color") {
            // Color Selection
            VStack(alignment: .leading, spacing: 8) {
                ColorSelectionView(
                    availableColors: AppConstants.Colors.palette,
                    selectedColorHex: $viewModel.noteAlbumColorHex,
                    colorForPicker: $viewModel.noteAlbumColorForPicker,
                    sphereColorHex: getSphereColorHex()
                )
            }
            .padding(.vertical, 5)
        }
    }
    
    // Получаем цвет сферы для отображения в ColorSelectionView
    private func getSphereColorHex() -> String? {
        guard let sphereID = viewModel.noteAlbumSphereID else { return nil }
        let fetchDescriptor = FetchDescriptor<Sphere>(predicate: #Predicate<Sphere> { $0.id == sphereID })
        if let sphere = try? modelContext.fetch(fetchDescriptor).first {
            return sphere.colorHex
        }
        return nil
    }

    private var listSection: some View {
        Group {
            Section("Color") {
                // Color Selection
                VStack(alignment: .leading, spacing: 8) {
                    ColorSelectionView(
                        availableColors: AppConstants.Colors.palette,
                        selectedColorHex: $viewModel.listColorHex,
                        colorForPicker: $viewModel.listColorForPicker,
                        sphereColorHex: getListSphereColorHex()
                    )
                }
                .padding(.vertical, 5)
            }
        }
    }
    
    // Получаем цвет сферы для отображения в ColorSelectionView для List
    private func getListSphereColorHex() -> String? {
        guard let sphereID = viewModel.listContent.sphereID else { return nil }
        let fetchDescriptor = FetchDescriptor<Sphere>(predicate: #Predicate<Sphere> { $0.id == sphereID })
        if let sphere = try? modelContext.fetch(fetchDescriptor).first {
            return sphere.colorHex
        }
        return nil
    }

    private var counterSection: some View {
        Group {
            Section("Color") {
                // Color Selection
                VStack(alignment: .leading, spacing: 8) {
                    ColorSelectionView(
                        availableColors: AppConstants.Colors.palette,
                        selectedColorHex: $viewModel.counterColorHex,
                        colorForPicker: $viewModel.counterColorForPicker,
                        sphereColorHex: getCounterSphereColorHex()
                    )
                }
                .padding(.vertical, 5)
            }
            
            Section("Counter") {
                HStack {
                    Text("Текущее значение")
                    Spacer()
                    TextField("0", value: $viewModel.counterContent.currentValue, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }

                HStack {
                    Text("Целевое значение")
                    Spacer()
                    TextField("Нет", value: $viewModel.counterContent.targetValue, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }

                HStack {
                    Text("Единица измерения")
                    Spacer()
                    TextField("раз, мл, стр...", text: $viewModel.counterContent.unit)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 120)
                }
            }
            
            Section("Notes") {
                TextEditor(text: $viewModel.counterContent.notes)
                    .frame(minHeight: 80)
            }
            
            // Sphere impact section
            if let sid = viewModel.counterContent.sphereID,
               let sphere = (try? modelContext.fetch(FetchDescriptor<Sphere>()))?.first(where: { $0.id == sid }) {
                Section("Влияние на \(sphere.title)") {
                    ImpactSliderView(
                        positiveImpact: $viewModel.counterContent.positiveImpact,
                        negativeImpact: $viewModel.counterContent.negativeImpact,
                        range: 0...100,
                        step: 0.1,
                        unit: "%"
                    )
                }
            }
        }
    }
    
    // Получаем цвет сферы для отображения в ColorSelectionView для Counter
    private func getCounterSphereColorHex() -> String? {
        guard let sphereID = viewModel.counterContent.sphereID else { return nil }
        let fetchDescriptor = FetchDescriptor<Sphere>(predicate: #Predicate<Sphere> { $0.id == sphereID })
        if let sphere = try? modelContext.fetch(fetchDescriptor).first {
            return sphere.colorHex
        }
        return nil
    }

    private var streakSection: some View {
        Group {
            Section("Color") {
                // Color Selection
                VStack(alignment: .leading, spacing: 8) {
                    ColorSelectionView(
                        availableColors: AppConstants.Colors.palette,
                        selectedColorHex: $viewModel.streakColorHex,
                        colorForPicker: $viewModel.streakColorForPicker,
                        sphereColorHex: getStreakSphereColorHex()
                    )
                }
                .padding(.vertical, 5)
            }
            
            Section("Streak") {
                HStack {
                    Text("Текущий стрик")
                    Spacer()
                    Text("\(viewModel.streakContent.currentStreak) дней")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Лучший стрик")
                    Spacer()
                    Text("\(viewModel.streakContent.bestStreak) дней")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Целевой стрик")
                    Spacer()
                    TextField("Какая ваша цель?", text: $viewModel.streakContent.goal)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 200)
                }
            }
            
            Section("Notes") {
                TextEditor(text: $viewModel.streakContent.notes)
                    .frame(minHeight: 80)
            }
            
            // Sphere impact section
            if let sid = viewModel.streakContent.sphereID,
               let sphere = (try? modelContext.fetch(FetchDescriptor<Sphere>()))?.first(where: { $0.id == sid }) {
                Section("Влияние на \(sphere.title)") {
                    ImpactSliderView(
                        positiveImpact: $viewModel.streakContent.positiveImpact,
                        negativeImpact: $viewModel.streakContent.negativeImpact,
                        range: 0...100,
                        step: 0.1,
                        unit: "%"
                    )
                }
            }
        }
    }
    
    // Получаем цвет сферы для отображения в ColorSelectionView для Streak
    private func getStreakSphereColorHex() -> String? {
        guard let sphereID = viewModel.streakContent.sphereID else { return nil }
        let fetchDescriptor = FetchDescriptor<Sphere>(predicate: #Predicate<Sphere> { $0.id == sphereID })
        if let sphere = try? modelContext.fetch(fetchDescriptor).first {
            return sphere.colorHex
        }
        return nil
    }

    private var moodSection: some View {
        let validMoodScale = max(1, viewModel.moodContent.scale)
        let moodMaxValue = Double(validMoodScale)
        let moodMinValue = 1.0
        
        return Section("Mood") {
            VStack(spacing: 16) {
                // Mood slider with step 0.5
                VStack(spacing: 12) {
                    HStack {
                        Text("Настроение")
                        Spacer()
                        Text(String(format: "%.1f", viewModel.tempMoodValue))
                            .foregroundColor(.secondary)
                    }
                    
                    moodSliderView(maxValue: moodMaxValue, minValue: moodMinValue)
                        .onChange(of: viewModel.moodContent.scale) { oldValue, newValue in
                            let newValidScale = max(1, newValue)
                            if viewModel.tempMoodValue > Double(newValidScale) {
                                viewModel.tempMoodValue = Double(newValidScale)
                            }
                        }
                        .onAppear {
                            if viewModel.tempMoodValue > moodMaxValue {
                                viewModel.tempMoodValue = moodMaxValue
                            }
                            if viewModel.tempMoodValue < moodMinValue {
                                viewModel.tempMoodValue = moodMinValue
                            }
                        }
                    
                    // Confirm/Cancel buttons and scale in HStack
                    moodButtonsView(validScale: validMoodScale)
                }
            }
        }
        .sheet(isPresented: $showMoodScalePicker) {
            moodScalePickerView
        }
    }
    
    private func moodSliderView(maxValue: Double, minValue: Double) -> some View {
        Slider(
            value: Binding(
                get: { viewModel.tempMoodValue },
                set: { newValue in
                    let clampedValue = min(max(minValue, newValue), maxValue)
                    viewModel.tempMoodValue = clampedValue
                }
            ),
            in: minValue...maxValue,
            step: 0.5
        )
    }
    
    private func moodButtonsView(validScale: Int) -> some View {
        HStack {
            Button("Отменить") {
                viewModel.cancelMoodChange()
            }
            .foregroundColor(.red)
            
            Spacer()
            
            Button {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    showMoodScalePicker = true
                }
            } label: {
                Text("Макс: \(validScale)")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Button("Подтвердить") {
                viewModel.confirmMoodChange()
            }
            .foregroundColor(.blue)
        }
    }
    
    private var moodScalePickerView: some View {
        MoodScalePickerView(
            selectedScale: Binding(
                get: { max(1, viewModel.moodContent.scale) },
                set: { newValue in
                    let validValue = max(1, min(100, newValue))
                    viewModel.moodContent.scale = validValue
                    if viewModel.tempMoodValue > Double(validValue) {
                        viewModel.tempMoodValue = Double(validValue)
                    }
                }
            ),
            tempMoodValue: $viewModel.tempMoodValue,
            isPresented: $showMoodScalePicker
        )
    }
    
    // Получаем цвет сферы для отображения в ColorSelectionView для Mood
    private func getMoodSphereColorHex() -> String? {
        guard let sphereID = viewModel.moodContent.sphereID else { return nil }
        let fetchDescriptor = FetchDescriptor<Sphere>(predicate: #Predicate<Sphere> { $0.id == sphereID })
        if let sphere = try? modelContext.fetch(fetchDescriptor).first {
            return sphere.colorHex
        }
        return nil
    }

    private var skillSection: some View {
        let validSkillScale = max(1, viewModel.skillContent.scale)
        let skillMaxValue = Double(validSkillScale)
        let skillMinValue = 0.0
        
        return Group {
            Section("Skill") {
                VStack(spacing: 16) {
                    // Skill level slider with step 0.5
                    VStack(spacing: 12) {
                        HStack {
                            Text("Уровень навыка")
                            Spacer()
                            Text(String(format: "%.1f", viewModel.tempSkillLevel))
                                .foregroundColor(.secondary)
                        }
                        
                        skillSliderView(maxValue: skillMaxValue)
                            .onChange(of: viewModel.skillContent.scale) { oldValue, newValue in
                                let newValidScale = max(1, newValue)
                                if viewModel.tempSkillLevel > Double(newValidScale) {
                                    viewModel.tempSkillLevel = Double(newValidScale)
                                }
                            }
                            .onAppear {
                                if viewModel.tempSkillLevel > skillMaxValue {
                                    viewModel.tempSkillLevel = skillMaxValue
                                }
                                if viewModel.tempSkillLevel < skillMinValue {
                                    viewModel.tempSkillLevel = skillMinValue
                                }
                            }
                        
                        // Confirm/Cancel buttons
                        skillButtonsView()
                    }
                }
            }
            
            Section("Настройки") {
                Picker("Максимум", selection: Binding(
                    get: { max(1, viewModel.skillContent.scale) },
                    set: { newValue in
                        let validValue = max(1, min(100, newValue))
                        viewModel.skillContent.scale = validValue
                        if viewModel.tempSkillLevel > Double(validValue) {
                            viewModel.tempSkillLevel = Double(validValue)
                        }
                    }
                )) {
                    ForEach(1...100, id: \.self) { value in
                        Text("\(value)").tag(value)
                    }
                }
            }
        }
    }
    
    private func skillSliderView(maxValue: Double) -> some View {
        Slider(
            value: Binding(
                get: { viewModel.tempSkillLevel },
                set: { newValue in
                    let clampedValue = min(max(0.0, newValue), maxValue)
                    viewModel.tempSkillLevel = clampedValue
                }
            ),
            in: 0.0...maxValue,
            step: 0.5
        )
    }
    
    private func skillButtonsView() -> some View {
        HStack {
            Button("Отменить") {
                viewModel.cancelSkillChange()
            }
            .foregroundColor(.red)
            
            Spacer()
            
            Button("Подтвердить") {
                viewModel.confirmSkillChange()
            }
            .foregroundColor(.blue)
        }
    }
    
    // Получаем цвет сферы для отображения в ColorSelectionView для Skill
    private func getSkillSphereColorHex() -> String? {
        guard let sphereID = viewModel.skillContent.sphereID else { return nil }
        let fetchDescriptor = FetchDescriptor<Sphere>(predicate: #Predicate<Sphere> { $0.id == sphereID })
        if let sphere = try? modelContext.fetch(fetchDescriptor).first {
            return sphere.colorHex
        }
        return nil
    }
    
    // Получаем цвет сферы для отображения в ColorSelectionView для Time
    private func getTimeSphereColorHex() -> String? {
        guard let sphereID = viewModel.timeContent.sphereID else { return nil }
        let fetchDescriptor = FetchDescriptor<Sphere>(predicate: #Predicate<Sphere> { $0.id == sphereID })
        if let sphere = try? modelContext.fetch(fetchDescriptor).first {
            return sphere.colorHex
        }
        return nil
    }
    
    // Получаем цвет сферы для отображения в ColorSelectionView для Health
    private func getHealthSphereColorHex() -> String? {
        guard let sphereID = viewModel.healthContent.sphereID else { return nil }
        let fetchDescriptor = FetchDescriptor<Sphere>(predicate: #Predicate<Sphere> { $0.id == sphereID })
        if let sphere = try? modelContext.fetch(fetchDescriptor).first {
            return sphere.colorHex
        }
        return nil
    }

    private var budgetSection: some View {
        Section("Бюджет") {
            HStack {
                Text("Начальный баланс")
                Spacer()
                TextField("0", value: $viewModel.budgetContent.initialBalance, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 120)
            }
            
            Text("Бюджет редактируется в основном представлении")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // Получаем цвет сферы для отображения в ColorSelectionView для Budget
    private func getBudgetSphereColorHex() -> String? {
        guard let sphereID = viewModel.budgetContent.sphereID else { return nil }
        let fetchDescriptor = FetchDescriptor<Sphere>(predicate: #Predicate<Sphere> { $0.id == sphereID })
        if let sphere = try? modelContext.fetch(fetchDescriptor).first {
            return sphere.colorHex
        }
        return nil
    }

    private var timeSection: some View {
        Section("Время") {
            HStack {
                Text("Изначальное время")
                Spacer()
                TextField("0", value: $viewModel.timeContent.initialMinutes, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
                Text("мин")
                    .foregroundColor(.secondary)
            }
            
            Picker("Шаг времени", selection: Binding(
                get: { Int(viewModel.timeContent.stepMinutes) },
                set: { viewModel.timeContent.stepMinutes = Double($0) }
            )) {
                ForEach([1, 5, 10, 15, 30, 60], id: \.self) { value in
                    Text("\(value) мин").tag(value)
                }
            }
        }
    }
    
    private var healthSection: some View {
        Section("Здоровье") {
            HStack {
                Text("Изначальное значение")
                Spacer()
                TextField("0", value: $viewModel.healthContent.initialValue, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
            }
            
            Picker("Шаг значения", selection: $viewModel.healthContent.stepValue) {
                ForEach([0.01, 0.1, 0.5, 1.0, 5.0, 10.0], id: \.self) { value in
                    Text(formatStepValue(value)).tag(value)
                }
            }
            
            Picker("Единица измерения", selection: Binding(
                get: { viewModel.healthContent.unit.isEmpty ? "ед." : viewModel.healthContent.unit },
                set: { viewModel.healthContent.unit = $0 }
            )) {
                let commonUnits = ["кг", "см", "уд/мин", "мм рт.ст.", "°C", "ммоль/л", "ед."]
                ForEach(commonUnits, id: \.self) { unit in
                    Text(unit).tag(unit)
                }
            }
        }
    }
    
    private func formatStepValue(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        } else {
            let stepString = String(value)
            let decimalPlaces = stepString.contains(".") ? stepString.split(separator: ".").last?.count ?? 1 : 0
            return String(format: "%.\(min(decimalPlaces, 2))f", value)
        }
    }

    private var trackerSection: some View {
        Section("Трекер") {
            TextField("Название трекера", text: $viewModel.trackerContent.trackerName)

            HStack {
                Text("Текущее значение")
                Spacer()
                TextField("0", value: $viewModel.trackerContent.currentValue, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }

            HStack {
                Text("Дневной лимит")
                Spacer()
                TextField("Лимит", value: $viewModel.trackerContent.dailyLimit, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }

            HStack {
                Text("Цель")
            Spacer()
                TextField("Цель", value: $viewModel.trackerContent.targetValue, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }

            HStack {
                Text("Единица")
                Spacer()
                TextField("шт.", text: $viewModel.trackerContent.unit)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }
        }
    }



    private func saveMemo() {
        do {
            let memoItem = try viewModel.createMemoItem()
            if !isEditing {
                // Создание нового мемо
                modelContext.insert(memoItem)
            }
            try modelContext.save()
            dismiss()
        } catch {
            print("Error saving memo: \(error)")
        }
    }
}

// MARK: - Edit Memo View Model
class EditMemoViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var selectedTags: [String] = []

    // Content states
    @Published var noteAlbumContent: MemoNoteAlbumContent = MemoNoteAlbumContent()
    @Published var noteAlbumColorHex: String = "#007AFF" // Default iOS blue
    @Published var noteAlbumColorForPicker: Color = .blue
    @Published var noteAlbumSphereID: UUID? = nil
    @Published var noteAlbumColorManuallyChanged: Bool = false
    var isUpdatingColorFromSphere: Bool = false
    
    // List content
    @Published var listContent: MemoListContent = MemoListContent()
    @Published var listColorHex: String = "#34C759" // Default green
    @Published var listColorForPicker: Color = .green
    @Published var listColorManuallyChanged: Bool = false
    var isUpdatingListColorFromSphere: Bool = false

    // Counter content
    @Published var counterContent: MemoCounterContent = MemoCounterContent()
    @Published var counterColorHex: String = "#FF9500" // Default orange
    @Published var counterColorForPicker: Color = .orange
    @Published var counterColorManuallyChanged: Bool = false
    var isUpdatingCounterColorFromSphere: Bool = false

    // Streak content
    @Published var streakContent: MemoStreakContent = MemoStreakContent()
    @Published var streakColorHex: String = "#FF3B30" // Default red
    @Published var streakColorForPicker: Color = .red
    @Published var streakColorManuallyChanged: Bool = false
    var isUpdatingStreakColorFromSphere: Bool = false
    
    // Mood content
    @Published var moodContent: MemoMoodContent = MemoMoodContent()
    @Published var moodColorHex: String = "#FF2D55" // Default iOS pink
    @Published var moodColorForPicker: Color = .pink
    @Published var moodColorManuallyChanged: Bool = false
    var isUpdatingMoodColorFromSphere: Bool = false
    @Published var tempMoodValue: Double = 5.0
    @Published var savedMoodValue: Double = 5.0
    @Published var skillContent: MemoSkillContent = MemoSkillContent()
    @Published var skillColorHex: String = "#5E5CE6" // Default indigo
    @Published var skillColorForPicker: Color = .indigo
    @Published var skillColorManuallyChanged: Bool = false
    var isUpdatingSkillColorFromSphere: Bool = false
    @Published var tempSkillLevel: Double = 0.0
    @Published var savedSkillLevel: Double = 0.0
    @Published var budgetContent: MemoBudgetContent = MemoBudgetContent()
    @Published var budgetColorHex: String = "#00C7BE" // Default mint
    @Published var budgetColorForPicker: Color = Color(hex: "#00C7BE")
    @Published var budgetColorManuallyChanged: Bool = false
    var isUpdatingBudgetColorFromSphere: Bool = false
    
    // Time content
    @Published var timeContent: MemoTimeContent = MemoTimeContent()
    @Published var timeColorHex: String = "#0A84FF" // Default blue
    @Published var timeColorForPicker: Color = .blue
    @Published var timeColorManuallyChanged: Bool = false
    var isUpdatingTimeColorFromSphere: Bool = false
    
    // Health content
    @Published var healthContent: MemoHealthContent = MemoHealthContent()
    @Published var healthColorHex: String = "#E6332A" // Default red
    @Published var healthColorForPicker: Color = .red
    @Published var healthColorManuallyChanged: Bool = false
    var isUpdatingHealthColorFromSphere: Bool = false
    
    @Published var trackerContent: MemoTrackerContent = MemoTrackerContent()
    
    // UI states (removed showStreakIconPicker as we use IconSelectionView now)

    private let memoToEdit: MemoItem?
    private let memoType: MemoItemType

    init(memoToEdit: MemoItem?, memoType: MemoItemType) {
        self.memoToEdit = memoToEdit
        self.memoType = memoType

        if let existingMemo = memoToEdit {
            loadExistingMemoData(existingMemo)
        } else {
            initializeNewMemoData()
        }
    }

    private func loadExistingMemoData(_ memo: MemoItem) {
        title = memo.title
        selectedTags = memo.tags

        switch memo.itemType {
        case .noteAlbum:
            if let data = memo.contentData {
                // Сначала попробуем загрузить новую структуру
                if let content = try? JSONDecoder().decode(MemoNoteAlbumContent.self, from: data) {
                noteAlbumContent = content
                noteAlbumColorHex = content.colorHex
                noteAlbumColorForPicker = Color(hex: content.colorHex)
                noteAlbumSphereID = content.sphereID
                } else if let text = try? JSONDecoder().decode(String.self, from: data) {
                    // Для обратной совместимости - конвертируем старую строку в новую структуру
                    noteAlbumContent = MemoNoteAlbumContent(notes: [MemoNoteAlbumContent.NoteItem(title: "", content: text)])
                    noteAlbumColorHex = noteAlbumContent.colorHex
                    noteAlbumColorForPicker = Color(hex: noteAlbumContent.colorHex)
                    noteAlbumSphereID = nil
                }
            }
        case .list:
            if let data = memo.contentData {
                // Сначала попробуем загрузить новую структуру
                if let content = try? JSONDecoder().decode(MemoListContent.self, from: data) {
                    listContent = content
                    listColorHex = content.colorHex
                    listColorForPicker = Color(hex: content.colorHex)
                } else if let items = try? JSONDecoder().decode([MemoListItem].self, from: data) {
                    // Для обратной совместимости - конвертируем старый массив в новую структуру
                    listContent = MemoListContent(items: items, colorHex: listColorHex)
                    listColorForPicker = Color(hex: listColorHex)
                }
            }
        case .counter:
            if let data = memo.contentData, let content = try? JSONDecoder().decode(MemoCounterContent.self, from: data) {
                counterContent = content
                counterColorHex = content.colorHex
                counterColorForPicker = Color(hex: content.colorHex)
            }
        case .streak:
            if let data = memo.contentData, let content = try? JSONDecoder().decode(MemoStreakContent.self, from: data) {
                streakContent = content
                streakColorHex = content.colorHex
                streakColorForPicker = Color(hex: content.colorHex)
            }
        case .mood:
            if let data = memo.contentData, let content = try? JSONDecoder().decode(MemoMoodContent.self, from: data) {
                moodContent = content
                // Ensure scale is valid
                if moodContent.scale < 1 {
                    moodContent.scale = 10
                }
                moodColorHex = content.colorHex
                moodColorForPicker = Color(hex: content.colorHex)
                let validScale = max(1, moodContent.scale)
                tempMoodValue = min(Double(validScale), max(1.0, Double(validScale) / 2.0))
                savedMoodValue = tempMoodValue
            }
        case .skill:
            if let data = memo.contentData, let content = try? JSONDecoder().decode(MemoSkillContent.self, from: data) {
                skillContent = content
                // Ensure scale is valid
                if skillContent.scale < 1 {
                    skillContent.scale = 10
                }
                skillColorHex = content.colorHex
                skillColorForPicker = Color(hex: content.colorHex)
                let validScale = max(1, skillContent.scale)
                
                // If no skills exist, create one with card title
                if skillContent.skills.isEmpty {
                    let newSkill = MemoSkillContent.SkillItem(
                        name: memo.title,
                        currentLevel: skillContent.currentLevel,
                        targetLevel: nil,
                        iconName: skillContent.iconName,
                        customImageData: skillContent.customImageData,
                        colorHex: skillColorHex,
                        notes: skillContent.notes,
                        history: []
                    )
                    skillContent.skills = [newSkill]
                    tempSkillLevel = min(Double(validScale), max(0.0, skillContent.currentLevel))
                } else {
                    // Use first skill's level
                    tempSkillLevel = min(Double(validScale), max(0.0, skillContent.skills[0].currentLevel))
                }
                savedSkillLevel = tempSkillLevel
            }
        case .budget:
            if let data = memo.contentData, let content = try? JSONDecoder().decode(MemoBudgetContent.self, from: data) {
                budgetContent = content
                budgetColorHex = content.colorHex
                budgetColorForPicker = Color(hex: content.colorHex)
                
                // If no budgets exist, create one with card title
                if budgetContent.budgets.isEmpty {
                    let newBudget = MemoBudgetContent.BudgetItem(
                        name: memo.title,
                        currentBalance: budgetContent.initialBalance,
                        iconName: budgetContent.iconName,
                        customImageData: budgetContent.customImageData,
                        colorHex: budgetColorHex,
                        notes: budgetContent.notes,
                        transactions: []
                    )
                    budgetContent.budgets = [newBudget]
                }
            }
        case .time:
            if let data = memo.contentData, let content = try? JSONDecoder().decode(MemoTimeContent.self, from: data) {
                timeContent = content
                // Если currentMinutes не установлено, устанавливаем из initialMinutes
                if timeContent.currentMinutes == 0.0 && timeContent.initialMinutes > 0.0 {
                    timeContent.currentMinutes = timeContent.initialMinutes
                }
                timeColorHex = content.colorHex
                timeColorForPicker = Color(hex: content.colorHex)
            }
        case .health:
            if let data = memo.contentData, let content = try? JSONDecoder().decode(MemoHealthContent.self, from: data) {
                healthContent = content
                // Если currentValue не установлено, устанавливаем из initialValue
                if healthContent.currentValue == 0.0 && healthContent.initialValue != 0.0 {
                    healthContent.currentValue = healthContent.initialValue
                }
                healthColorHex = content.colorHex
                healthColorForPicker = Color(hex: content.colorHex)
            }
        case .tracker:
            if let data = memo.contentData, let content = try? JSONDecoder().decode(MemoTrackerContent.self, from: data) {
                trackerContent = content
            }
        }
    }

    private func initializeNewMemoData() {
        // Для noteAlbum title остается пустым, для остальных типов устанавливается дефолтное значение
        if memoType != .noteAlbum {
            title = title.isEmpty ? "Новый \(memoType.displayName)" : title
        }
        switch memoType {
        case .noteAlbum:
            noteAlbumContent = MemoNoteAlbumContent()
            noteAlbumColorHex = noteAlbumContent.colorHex
            noteAlbumColorForPicker = Color(hex: noteAlbumContent.colorHex)
        case .list:
            listContent = MemoListContent(items: [])
            listColorHex = listContent.colorHex
            listColorForPicker = Color(hex: listContent.colorHex)
        case .counter:
            counterContent = MemoCounterContent()
            counterColorHex = counterContent.colorHex
            counterColorForPicker = Color(hex: counterContent.colorHex)
        case .streak:
            streakContent = MemoStreakContent()
            streakColorHex = streakContent.colorHex
            streakColorForPicker = Color(hex: streakContent.colorHex)
        case .mood:
            moodContent = MemoMoodContent()
            // Ensure scale is valid
            if moodContent.scale < 1 {
                moodContent.scale = 10
            }
            moodColorHex = moodContent.colorHex
            moodColorForPicker = Color(hex: moodContent.colorHex)
            let validScale = max(1, moodContent.scale)
            tempMoodValue = min(Double(validScale), max(1.0, Double(validScale) / 2.0))
            savedMoodValue = tempMoodValue
        case .skill:
            skillContent = MemoSkillContent()
            // Ensure scale is valid
            if skillContent.scale < 1 {
                skillContent.scale = 10
            }
            skillColorHex = skillContent.colorHex
            skillColorForPicker = Color(hex: skillContent.colorHex)
            let validScale = max(1, skillContent.scale)
            tempSkillLevel = min(Double(validScale), max(0.0, Double(validScale) / 2.0))
            savedSkillLevel = tempSkillLevel
            
            // Create initial skill with card title
            let initialSkill = MemoSkillContent.SkillItem(
                name: title.isEmpty ? "Новый навык" : title,
                currentLevel: tempSkillLevel,
                targetLevel: nil,
                iconName: skillContent.iconName,
                customImageData: skillContent.customImageData,
                colorHex: skillColorHex,
                notes: skillContent.notes,
                history: []
            )
            skillContent.skills = [initialSkill]
        case .budget:
            budgetContent = MemoBudgetContent()
            budgetColorHex = budgetContent.colorHex
            budgetColorForPicker = Color(hex: budgetContent.colorHex)
            
            // Create initial budget with card title
            let initialBudget = MemoBudgetContent.BudgetItem(
                name: title.isEmpty ? "Новый бюджет" : title,
                currentBalance: budgetContent.initialBalance,
                iconName: budgetContent.iconName,
                customImageData: budgetContent.customImageData,
                colorHex: budgetColorHex,
                notes: budgetContent.notes,
                transactions: []
            )
            budgetContent.budgets = [initialBudget]
        case .time:
            timeContent = MemoTimeContent()
            // При создании нового мемо currentMinutes = initialMinutes (оба 0)
            timeContent.currentMinutes = timeContent.initialMinutes
            timeColorHex = timeContent.colorHex
            timeColorForPicker = Color(hex: timeContent.colorHex)
        case .health:
            healthContent = MemoHealthContent()
            healthColorHex = healthContent.colorHex
            healthColorForPicker = Color(hex: healthContent.colorHex)
        case .tracker:
            trackerContent = MemoTrackerContent()
        }
    }

    func createMemoItem() throws -> MemoItem {
        let data = try getData()
        let orderIndex = Int(Date().timeIntervalSince1970)

        if let existingMemo = memoToEdit {
            // Обновляем существующий объект
            existingMemo.title = title
            existingMemo.tags = selectedTags
            existingMemo.contentData = data
            return existingMemo
        } else {
            // Создаем новый объект
            let newMemo = MemoItem(
                title: title,
                orderIndex: orderIndex,
                type: memoType,
                tags: selectedTags
            )
            newMemo.contentData = data
            return newMemo
        }
    }

    private func getData() throws -> Data {
        switch memoType {
        case .noteAlbum:
            // Обновляем цвет и sphereID перед сохранением
            noteAlbumContent.colorHex = noteAlbumColorHex
            noteAlbumContent.sphereID = noteAlbumSphereID
            return try JSONEncoder().encode(noteAlbumContent)
        case .list:
            // Обновляем цвет перед сохранением
            listContent.colorHex = listColorHex
            return try JSONEncoder().encode(listContent)
        case .counter:
            // Обновляем цвет перед сохранением
            counterContent.colorHex = counterColorHex
            return try JSONEncoder().encode(counterContent)
        case .streak:
            // Обновляем цвет перед сохранением
            streakContent.colorHex = streakColorHex
            return try JSONEncoder().encode(streakContent)
        case .mood:
            // Обновляем цвет перед сохранением
            moodContent.colorHex = moodColorHex
            return try JSONEncoder().encode(moodContent)
        case .skill:
            // Обновляем цвет и текущий уровень перед сохранением
            skillContent.colorHex = skillColorHex
            skillContent.currentLevel = tempSkillLevel
            
            // Ensure there's exactly one skill with the card's title
            if skillContent.skills.isEmpty {
                let newSkill = MemoSkillContent.SkillItem(
                    name: title.isEmpty ? "Новый навык" : title,
                    currentLevel: tempSkillLevel,
                    targetLevel: nil,
                    iconName: skillContent.iconName,
                    customImageData: skillContent.customImageData,
                    colorHex: skillColorHex,
                    notes: skillContent.notes,
                    history: []
                )
                // Add initial history entry
                var skillWithHistory = newSkill
                skillWithHistory.history.append(
                    MemoSkillContent.SkillItem.SkillEntry(
                        date: Date(),
                        level: tempSkillLevel,
                        note: "Начальный уровень"
                    )
                )
                skillContent.skills = [skillWithHistory]
            } else {
                // Update the first skill's name to match the card title
                skillContent.skills[0].name = title.isEmpty ? skillContent.skills[0].name : title
                skillContent.skills[0].currentLevel = tempSkillLevel
                skillContent.skills[0].colorHex = skillColorHex
            }
            
            return try JSONEncoder().encode(skillContent)
        case .budget:
            // Обновляем цвет перед сохранением
            budgetContent.colorHex = budgetColorHex
            
            // Ensure there's exactly one budget with the card's title
            if budgetContent.budgets.isEmpty {
                let newBudget = MemoBudgetContent.BudgetItem(
                    name: title.isEmpty ? "Новый бюджет" : title,
                    currentBalance: budgetContent.initialBalance,
                    iconName: budgetContent.iconName,
                    customImageData: budgetContent.customImageData,
                    colorHex: budgetColorHex,
                    notes: budgetContent.notes,
                    transactions: []
                )
                budgetContent.budgets = [newBudget]
            } else {
                // Update the first budget's name to match the card title
                budgetContent.budgets[0].name = title.isEmpty ? budgetContent.budgets[0].name : title
                budgetContent.budgets[0].currentBalance = budgetContent.initialBalance
                budgetContent.budgets[0].colorHex = budgetColorHex
            }
            
            return try JSONEncoder().encode(budgetContent)
        case .time:
            // Обновляем цвет перед сохранением
            timeContent.colorHex = timeColorHex
            // Если currentMinutes не был установлен, устанавливаем из initialMinutes
            if timeContent.currentMinutes == 0.0 && timeContent.initialMinutes > 0.0 {
                timeContent.currentMinutes = timeContent.initialMinutes
            }
            return try JSONEncoder().encode(timeContent)
        case .health:
            // Обновляем цвет перед сохранением
            healthContent.colorHex = healthColorHex
            // Если currentValue не был установлен, устанавливаем из initialValue
            if healthContent.currentValue == 0.0 && healthContent.initialValue != 0.0 {
                healthContent.currentValue = healthContent.initialValue
            }
            return try JSONEncoder().encode(healthContent)
        case .tracker:
            return try JSONEncoder().encode(trackerContent)
        }
    }
    
    // MARK: - List Icon Management
    func applyIconToAllListItems(iconName: String) {
        for i in 0..<listContent.items.count {
            listContent.items[i].iconName = iconName
            listContent.items[i].useCustomImage = false
            listContent.items[i].customImageData = nil
        }
    }
    
    func applyImageToAllListItems(imageData: Data) {
        for i in 0..<listContent.items.count {
            listContent.items[i].customImageData = imageData
            listContent.items[i].useCustomImage = true
            listContent.items[i].iconName = nil
        }
    }
    
    func resetAllListItemsToNumbers() {
        for i in 0..<listContent.items.count {
            listContent.items[i].iconName = nil
            listContent.items[i].useCustomImage = false
            listContent.items[i].customImageData = nil
        }
    }
    
    // MARK: - Mood Management
    func confirmMoodChange() {
        savedMoodValue = tempMoodValue
    }
    
    func cancelMoodChange() {
        tempMoodValue = savedMoodValue
    }
    
    // MARK: - Skill Management
    func confirmSkillChange() {
        savedSkillLevel = tempSkillLevel
    }
    
    func cancelSkillChange() {
        tempSkillLevel = savedSkillLevel
    }
}

// MARK: - Picker Views with Local State

struct MoodScalePickerView: View {
    @Binding var selectedScale: Int
    @Binding var tempMoodValue: Double
    @Binding var isPresented: Bool
    @State private var tempScale: Int
    
    init(selectedScale: Binding<Int>, tempMoodValue: Binding<Double>, isPresented: Binding<Bool>) {
        self._selectedScale = selectedScale
        self._tempMoodValue = tempMoodValue
        self._isPresented = isPresented
        self._tempScale = State(initialValue: selectedScale.wrappedValue)
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                Picker("Максимум", selection: $tempScale) {
                    ForEach(1...100, id: \.self) { value in
                        Text("\(value)").tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 200)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Выберите максимум")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        let validValue = max(1, min(100, tempScale))
                        selectedScale = validValue
                        if tempMoodValue > Double(validValue) {
                            tempMoodValue = Double(validValue)
                        }
                        isPresented = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}




