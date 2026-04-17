import SwiftUI
import SwiftData

// Presentation · Habits — форма создания/редактирования привычки и правил повторения.
// Сложная логика расписания — в `HabitLogicService` / модели; список по дате — `FilterHabitsUseCase` на `AllHabitsView`.

// MARK: - ADD/EDIT HABIT VIEW
struct EditHabitView: View {
    var modelContext: ModelContext
    @Binding var habitToEdit: Habit?
    var allHabitsCount: Int = 0
    let ruleEffectiveDate: Date
    
    @Environment(\.dismiss) private var dismiss
    
    @Query private var spheres: [Sphere]
    
    @State private var title: String
    @State private var descript: String
    @State private var colorHex: String
    @State private var selectedIconName: String = "star.fill"
    @State private var selectedWeeklyDays: [Int: Bool]
    @State private var selectedMonthlyDays: [Int]
    @State private var selectedSphereID: UUID?
    @State private var positiveImpact: Double = 0.0
    @State private var negativeImpact: Double = 0.0
    @State private var tags: [String] = []
    @State private var requiredRepetitions: Int = 1
    @State private var repetitionsPreset: Int? = nil
    @State private var showWheelPicker: Bool = false
    @State private var showDeleteHabitConfirmation: Bool = false
    @State private var showArchiveHabitConfirmation: Bool = false
    
    @State private var colorForPicker: Color = .blue
    @State private var colorUpdateTrigger: Bool = false
    @State private var showIconPicker: Bool = false
    
    private let hapticManager = HapticSoundManager.shared
    
    enum FrequencyPickerType: String, CaseIterable, Identifiable {
        case weekly = "Weekly"
        case monthly = "Monthly"
        var id: String { self.rawValue }
    }
    @State private var selectedFrequencyPicker: FrequencyPickerType
    
    init(modelContext: ModelContext, habitToEdit: Binding<Habit?> = .constant(nil), allHabitsCount: Int = 0, ruleEffectiveDate: Date) {
        self.modelContext = modelContext
        self._habitToEdit = habitToEdit
        self.allHabitsCount = allHabitsCount
        self.ruleEffectiveDate = ruleEffectiveDate
        
        _title = State(initialValue: "")
        _descript = State(initialValue: "")
        _colorHex = State(initialValue: "#3498db")
        _selectedIconName = State(initialValue: "star.fill")
        _selectedWeeklyDays = State(initialValue: [:])
        _selectedMonthlyDays = State(initialValue: [])
        _selectedFrequencyPicker = State(initialValue: .weekly)
        _requiredRepetitions = State(initialValue: 1)
    }
    
    private var isFormValid: Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty { return false }
        
        let hasWeeklySelection = !selectedWeeklyDays.filter({ $0.value }).isEmpty
        let hasMonthlySelection = !selectedMonthlyDays.isEmpty
        
        return hasWeeklySelection || hasMonthlySelection
    }

    private let descriptionMaxLength = 100

    private var descriptionHeight: CGFloat {
        let lineCount = max(1, (descript.count + 44) / 45)
        return max(44, min(84, CGFloat(lineCount) * 20))
    }

    private var descriptBinding: Binding<String> {
        Binding(
            get: { descript },
            set: { newValue in
                descript = String(newValue.prefix(descriptionMaxLength))
            }
        )
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(AppEditFormChrome.habitDetailsSectionTitle)) {
                    HStack(spacing: 12) {
                        Button {
                            hapticManager.selectionChanged()
                            showIconPicker = true
                        } label: {
                            HabitTitleIconPickerButton(iconName: selectedIconName, tintHex: colorHex)
                        }
                        .buttonStyle(.plain)
                        
                        TextField("title", text: $title)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        ZStack(alignment: .topLeading) {
                            if descript.isEmpty {
                                Text("description")
                                    .foregroundColor(.placeholderColor)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                                    .allowsHitTesting(false)
                            }
                            TextEditor(text: descriptBinding)
                                .frame(height: descriptionHeight)
                                .scrollContentBackground(.hidden)
                        }
                    }
                }
                
                Section(header: Text(AppEditFormChrome.repetitionFrequencySectionTitle)) {
                    Picker("Frequency", selection: $selectedFrequencyPicker) {
                        ForEach(FrequencyPickerType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.bottom, 5)
                    .onChange(of: selectedFrequencyPicker) {
                        hapticManager.selectionChanged()
                    }
                    
                    Group {
                        if selectedFrequencyPicker == .weekly {
                            WeeklySelectionView(selectedWeekdays: $selectedWeeklyDays)
                        } else {
                            MonthlySelectionView(selectedDays: $selectedMonthlyDays)
                        }
                    }
                    VStack(alignment: .leading, spacing: 16) {
                        // 1) Presets (chips) + Custom
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Daily repetitions")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            HStack(spacing: 8) {
                                let baseValues = [1, 2, 3, 4, 5]
                                ForEach(baseValues, id: \.self) { v in
                                    Button(action: {
                                        hapticManager.selectionChanged()
                                        repetitionsPreset = v
                                        requiredRepetitions = v
                                    }) {
                                        Text("\(v)")
                                            .fontWeight(.semibold)
                                            .frame(minWidth: 44, minHeight: 32)
                                            .background((repetitionsPreset == v && requiredRepetitions == v) ? Color.accentColor.opacity(0.2) : Color(UIColor.secondarySystemBackground))
                                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                }
                                Button(action: {
                                    hapticManager.selectionChanged()
                                    repetitionsPreset = nil
                                    if requiredRepetitions < 6 { requiredRepetitions = 6 }
                                    showWheelPicker = true
                                }) {
                                    Text(baseValues.contains(requiredRepetitions) ? "custom" : "\(requiredRepetitions)")
                                        .fontWeight(.semibold)
                                        .frame(minWidth: 80, minHeight: 32)
                                        .background(repetitionsPreset == nil ? Color.accentColor.opacity(0.2) : Color(UIColor.secondarySystemBackground))
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                            .onChange(of: requiredRepetitions) { oldValue, newValue in
                                let baseValues = [1, 2, 3, 4, 5]
                                repetitionsPreset = baseValues.contains(newValue) ? newValue : nil
                            }
                        }
                        
                    }
                }
                
                AreaImpactSection(
                    selectedSphereID: $selectedSphereID,
                    positiveImpact: $positiveImpact,
                    negativeImpact: $negativeImpact,
                    colorHex: $colorHex,
                    colorForPicker: $colorForPicker
                ) { sphere, amount in
                    applyMissDecrease(to: sphere, amount: amount)
                }
                Section(header: Text(AppEditFormChrome.tagsSectionTitle)) {
                    MemoTagsSelectionView(selectedTags: $tags)
                }
                
                if let habit = habitToEdit {
                    StatisticsView(habit: habit, endDate: ruleEffectiveDate)
                }
                
                if habitToEdit != nil {
                    Section {
                        Button {
                            showArchiveHabitConfirmation = true
                        } label: {
                            Label(
                                (habitToEdit?.isArchived == true) ? "Unarchive" : "Archive",
                                systemImage: (habitToEdit?.isArchived == true) ? "tray.and.arrow.up" : "archivebox"
                            )
                        }
                        .tint(.gray)
                        
                        Button(role: .destructive) {
                            showDeleteHabitConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(habitToEdit == nil ? "New Habit" : "Edit Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(habitToEdit == nil ? "Create" : "Save") {
                        hapticManager.playNotificationHaptic(type: .success)
                        saveHabit()
                        dismiss()
                    }
                    .disabled(!isFormValid)
                }
            }
        }
        // Важно: sheet должен быть привязан к корню экрана, иначе при перерисовке `Form/Section`
        // он может мгновенно закрываться.
        .sheet(isPresented: $showIconPicker) {
            HabitIconPickerSheet(
                title: "Choose icon",
                tintHex: colorHex,
                selectedIconName: $selectedIconName
            )
        }
        .overlay {
            if showArchiveHabitConfirmation, let habit = habitToEdit {
                let allowSecondary = !habit.isArchived
                ImpactActionPresenter.dialog(
                    isPresented: $showArchiveHabitConfirmation,
                    spheres: spheres,
                    sphereID: habit.sphereID,
                    negativeImpact: habit.negativeImpact,
                    allowSecondaryAction: allowSecondary,
                    title: habit.isArchived ? "Unarchive habit?" : "Archive habit?",
                    message: habit.isArchived ? "This habit will return to the active list." : "This habit will be archived.",
                    messageWithImpact: "Archive this habit. You can also apply its miss decrease to the area.",
                    primaryTitle: habit.isArchived ? "Unarchive" : "Archive",
                    primaryTint: .gray,
                    secondaryTitleFormat: "Archive and apply negative impact (-%@%%) on area",
                    secondaryTint: .gray,
                    onPrimary: {
                        archiveHabit(habit, applyNegativeImpact: false)
                        dismiss()
                    },
                    onSecondary: {
                        archiveHabit(habit, applyNegativeImpact: true)
                        dismiss()
                    },
                    onCancel: { }
                )
            }
        }
        .overlay {
            if showDeleteHabitConfirmation, let habit = habitToEdit {
                let sphereForImpact = habit.sphereID.flatMap { sid in
                    spheres.first(where: { $0.id == sid })
                }
                ImpactActionPresenter.dialog(
                    isPresented: $showDeleteHabitConfirmation,
                    spheres: spheres,
                    sphereID: habit.sphereID,
                    negativeImpact: habit.negativeImpact,
                    title: "Delete habit?",
                    message: "This habit will be permanently deleted.",
                    messageWithImpact: "Delete this habit. You can also apply its miss decrease to the area.",
                    primaryTitle: "Delete",
                    primaryTint: .red,
                    secondaryTitleFormat: "Delete and apply negative impact (-%@%%) on area",
                    secondaryTint: .red,
                    onPrimary: {
                        modelContext.delete(habit)
                        try? modelContext.save()
                        NotificationCenter.default.postAppEvent(.habitStatusDidChange)
                        dismiss()
                    },
                    onSecondary: {
                        if let sphereForImpact {
                            applyMissDecrease(to: sphereForImpact, amount: habit.negativeImpact)
                        }
                        modelContext.delete(habit)
                        try? modelContext.save()
                        NotificationCenter.default.postAppEvent(.habitStatusDidChange)
                        NotificationCenter.default.postAppEvent(.sphereSatisfactionDidChange)
                        dismiss()
                    },
                    onCancel: { }
                )
            }
        }
        .onAppear {
            loadHabitData()
        }
        .onChange(of: habitToEdit) {
            loadHabitData()
        }
        .onChange(of: colorForPicker) {
            if let newHex = colorForPicker.toHex() {
                self.colorHex = newHex
            }
        }
        .onChange(of: colorHex) {
            self.colorForPicker = Color(hex: colorHex)
            self.colorUpdateTrigger.toggle()
        }
        .onChange(of: selectedSphereID) { oldValue, newValue in
            // If user selects "None", zero out impacts and ignore them in calculations
            if newValue == nil {
                positiveImpact = 0.0
                negativeImpact = 0.0
            }
        }
        .sheet(isPresented: $showWheelPicker) {
            VStack(spacing: 16) {
                Text("Select repetitions")
                    .font(.headline)
                Picker("", selection: $requiredRepetitions) {
                    ForEach(6...100, id: \.self) { v in
                        Text("\(v)").tag(v)
                    }
                }
                .pickerStyle(.wheel)
                Button("Done") {
                    hapticManager.selectionChanged()
                    showWheelPicker = false
                }
                .padding(.top, 8)
            }
            .presentationDetents([.height(300)])
        }
    }
    
    private func loadHabitData() {
        if let habit = habitToEdit {
            title = habit.title
            let rawDescript = habit.descript ?? ""
            descript = String(rawDescript.prefix(descriptionMaxLength))
            colorHex = habit.colorHex
            selectedIconName = habit.iconName.isEmpty ? "star.fill" : habit.iconName
            selectedSphereID = habit.sphereID
            positiveImpact = habit.positiveImpact
            negativeImpact = habit.negativeImpact
            tags = habit.tags.map { $0.name }
            requiredRepetitions = habit.requiredRepetitions
            
            // Set repetitionsPreset based on requiredRepetitions
            let baseValues = [1, 2, 3, 4, 5]
            repetitionsPreset = baseValues.contains(requiredRepetitions) ? requiredRepetitions : nil
            
            if let latestRule = habit.repeatingRules.last {
                selectedWeeklyDays = Dictionary(uniqueKeysWithValues: latestRule.weeklyFrequency.map { ($0, true) })
                selectedMonthlyDays = latestRule.monthlySpecificDays
                
                if !latestRule.monthlySpecificDays.isEmpty {
                    selectedFrequencyPicker = .monthly
                } else {
                    selectedFrequencyPicker = .weekly
                }
            }
        } else {
            title = ""
            descript = ""
            colorHex = AppConstants.Colors.palette.first ?? "#3498db"
            selectedIconName = "star.fill"
            selectedWeeklyDays = [:]
            selectedMonthlyDays = []
            selectedFrequencyPicker = .weekly
            selectedSphereID = nil
            repetitionsPreset = 1  // Default to 1 for new habits
            positiveImpact = 0.0
            negativeImpact = 0.0
            tags = []
            requiredRepetitions = 1
        }
        colorForPicker = Color(hex: colorHex)
    }
    
    private func saveHabit() {
        guard isFormValid else { return }
        
        let currentWeeklyFrequency = selectedWeeklyDays.filter { $0.value }.map { $0.key }.sorted()
        let currentMonthlyDays = selectedMonthlyDays.sorted()
        
        var habitTags: [Tag] = []
        var seenTagKeys = Set<String>()
        for rawTagName in tags {
            let tagName = rawTagName
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "#", with: "")
            let normalized = TagNameNormalizer.storageName(from: tagName)
            let key = TagNameNormalizer.key(from: normalized)
            guard !normalized.isEmpty else { continue }
            guard !seenTagKeys.contains(key) else { continue }
            seenTagKeys.insert(key)
            
            let fetchDescriptor = FetchDescriptor<Tag>(predicate: #Predicate<Tag> { $0.name == normalized })
            if let existingTag = try? modelContext.fetch(fetchDescriptor).first {
                habitTags.append(existingTag)
            } else {
                let newTag = Tag(name: normalized)
                modelContext.insert(newTag)
                habitTags.append(newTag)
            }
        }
        
        if let habit = habitToEdit {
            habit.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            habit.descript = descript.isEmpty ? nil : descript
            habit.colorHex = colorHex
            habit.iconName = selectedIconName.isEmpty ? "star.fill" : selectedIconName
            habit.sphereID = selectedSphereID
            habit.positiveImpact = positiveImpact
            habit.negativeImpact = negativeImpact
            habit.tags = habitTags
            habit.requiredRepetitions = requiredRepetitions
            
            let lastRule = habit.repeatingRules.last
            let rulesChanged = lastRule?.weeklyFrequency != currentWeeklyFrequency || lastRule?.monthlySpecificDays != currentMonthlyDays
            
            if rulesChanged {
                // Important: habit schedule changes should apply starting from the factual habit creation date,
                // not from the date when the edit screen was opened (ruleEffectiveDate).
                let calendar = Calendar.current
                let effectiveStartDay = calendar.startOfDay(for: habit.creationDate)
                
                if let idx = habit.repeatingRules.lastIndex(where: { calendar.startOfDay(for: $0.startDate) == effectiveStartDay }) {
                    habit.repeatingRules[idx].weeklyFrequency = currentWeeklyFrequency
                    habit.repeatingRules[idx].monthlySpecificDays = currentMonthlyDays
                } else {
                    let newRepeatingRule = RepeatingRule(
                        startDate: effectiveStartDay,
                        weeklyFrequency: currentWeeklyFrequency,
                        monthlySpecificDays: currentMonthlyDays
                    )
                    habit.repeatingRules.append(newRepeatingRule)
                }
                
                // De-duplicate rules that accidentally share the same start day.
                var lastRuleByStartDay: [Date: RepeatingRule] = [:]
                for rule in habit.repeatingRules.sorted(by: { $0.startDate < $1.startDate }) {
                    lastRuleByStartDay[calendar.startOfDay(for: rule.startDate)] = rule
                }
                habit.repeatingRules = lastRuleByStartDay
                    .values
                    .sorted(by: { $0.startDate < $1.startDate })
            }
        } else {
            shiftExistingHabitsDownForInsertAtTop()
            let initialRule = RepeatingRule(
                startDate: ruleEffectiveDate,
                weeklyFrequency: currentWeeklyFrequency,
                monthlySpecificDays: currentMonthlyDays
            )
            
            let newHabit = Habit(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                description: descript.isEmpty ? nil : descript,
                colorHex: colorHex,
                iconName: selectedIconName.isEmpty ? "star.fill" : selectedIconName,
                orderIndex: 0,
                creationDate: ruleEffectiveDate,
                initialRule: initialRule,
                sphereID: selectedSphereID,
                positiveImpact: positiveImpact,
                negativeImpact: negativeImpact,
                requiredRepetitions: requiredRepetitions
            )
            newHabit.tags = habitTags
            modelContext.insert(newHabit)
        }
        
        do {
            try modelContext.save()
            TagMaintenanceService.pruneUnusedTags(modelContext: modelContext)
        } catch {
            print("Failed to save model context: \(error.localizedDescription)")
        }
    }

    private func shiftExistingHabitsDownForInsertAtTop() {
        let descriptor = FetchDescriptor<Habit>(
            sortBy: [SortDescriptor(\Habit.orderIndex, order: .forward)]
        )
        guard let existing = try? modelContext.fetch(descriptor), !existing.isEmpty else { return }
        for habit in existing {
            habit.orderIndex += 1
        }
        try? modelContext.save()
    }

    private func applyMissDecrease(to sphere: Sphere, amount: Double) {
        let clamped = max(0.0, min(100.0, amount))
        sphere.satisfaction = max(0.0, min(100.0, sphere.satisfaction - clamped))
        do {
            try modelContext.save()
        } catch {
            print("Failed to save model context: \(error.localizedDescription)")
        }
    }
    
    private func archiveHabit(_ habit: Habit, applyNegativeImpact: Bool) {
        let willArchive = !habit.isArchived
        if willArchive && applyNegativeImpact {
            if let sid = habit.sphereID, let sphere = spheres.first(where: { $0.id == sid }) {
                applyMissDecrease(to: sphere, amount: habit.negativeImpact)
            }
            NotificationCenter.default.postAppEvent(.sphereSatisfactionDidChange)
        }
        habit.isArchived.toggle()
        try? modelContext.save()
        NotificationCenter.default.postAppEvent(.habitStatusDidChange)
    }
    
    struct WeeklySelectionView: View {
        @Binding var selectedWeekdays: [Int: Bool]
        private let weekdays = Calendar.current.shortWeekdaySymbols
        private let hapticManager = HapticSoundManager.shared
        
        private var allDaysAreSelected: Bool {
            (1...7).allSatisfy { selectedWeekdays[$0, default: false] }
        }
        
        var body: some View {
            VStack(spacing: 10) {
                HStack {
                    ForEach(0..<7) { index in
                        let weekdayIndex = (index + Calendar.current.firstWeekday - 1) % 7 + 1
                        Text(String(weekdays[weekdayIndex - 1].prefix(1)))
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(selectedWeekdays[weekdayIndex, default: false] ? Color.accentColor.opacity(0.3) : Color.secondary.opacity(0.1))
                            .clipShape(Circle())
                            .onTapGesture {
                                selectedWeekdays[weekdayIndex, default: false].toggle()
                                hapticManager.selectionChanged()
                            }
                    }
                }
                
                Button(action: {
                    toggleAllWeekdays()
                    hapticManager.playHaptic(style: .light)
                }) {
                    Text("Daily")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(allDaysAreSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.2))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        
        private func toggleAllWeekdays() {
            let currentlyAllDaysSelected = (1...7).allSatisfy { selectedWeekdays[$0, default: false] }
            
            withAnimation {
                if currentlyAllDaysSelected {
                    for i in 1...7 {
                        selectedWeekdays[i] = false
                    }
                } else {
                    for i in 1...7 {
                        selectedWeekdays[i] = true
                    }
                }
            }
        }
    }
    
    struct MonthlySelectionView: View {
        @Binding var selectedDays: [Int]
        @State private var dayInput: String = ""
        @State private var showError: Bool = false
        private let hapticManager = HapticSoundManager.shared
        
        private let columns: [GridItem] = [GridItem(.adaptive(minimum: 70))]
        
        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                Text("Select Specific Days of Month (1-31)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    TextField("day", text: $dayInput)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .onChange(of: dayInput) {
                            let filtered = dayInput.filter { "0123456789".contains($0) }
                            dayInput = String(filtered.prefix(2))
                        }
                    
                    Button(action: addDay) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                    .disabled(dayInput.isEmpty)
                }
                
                if showError {
                    Text("Enter a valid day (1-31) that hasn't been added yet.")
                        .foregroundColor(.red)
                        .font(.caption)
                        .transition(.opacity.animation(.easeIn))
                }
                
                if !selectedDays.isEmpty {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 5) {
                            ForEach(selectedDays.sorted(), id: \.self) { day in
                                dayTagView(day)
                            }
                        }
                    }
                } else {
                    Text("No specific days selected.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                }
            }
            .padding(.vertical)
        }
        
        @ViewBuilder
        private func dayTagView(_ day: Int) -> some View {
            HStack(spacing: 4) {
                Text("\(day)")
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
                Button(action: { removeDay(day) }) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(UIColor.systemGray5))
            .clipShape(Capsule())
            .frame(minWidth: 60)
        }
        
        private func addDay() {
            showError = false
            if let dayInt = Int(dayInput), (1...31).contains(dayInt), !selectedDays.contains(dayInt) {
                hapticManager.playHaptic(style: .light)
                withAnimation {
                    selectedDays.append(dayInt)
                    selectedDays.sort()
                }
                dayInput = ""
            } else {
                hapticManager.playNotificationHaptic(type: .error)
                withAnimation { showError = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { showError = false }
                }
            }
        }
        
        private func removeDay(_ dayToRemove: Int) {
            hapticManager.playHaptic(style: .light)
            withAnimation {
                selectedDays.removeAll { $0 == dayToRemove }
            }
        }
    }
}

private struct HabitTitleIconPickerButton: View {
    let iconName: String
    let tintHex: String
    
    var body: some View {
        let tint = Color(hex: tintHex)
        ZStack {
            Circle()
                .stroke(tint.opacity(0.95), lineWidth: 4)
                .frame(width: 46, height: 46)
            Circle()
                .fill(tint.opacity(0.15))
                .frame(width: 36, height: 36)
            Image(systemName: iconName.isEmpty ? "star.fill" : iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(tint)
        }
        .accessibilityLabel("Choose icon")
    }
}

private struct HabitIconPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let tintHex: String
    @Binding var selectedIconName: String
    
    private let columns = [GridItem(.adaptive(minimum: 60), spacing: 10)]
    private let hapticManager = HapticSoundManager.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(availableHabitIcons, id: \.self) { name in
                        Button {
                            hapticManager.playHaptic(style: .light)
                            selectedIconName = name
                            dismiss()
                        } label: {
                            Image(systemName: name)
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 52, height: 52)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color(hex: tintHex))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(
                                            (selectedIconName == name) ? Color.white.opacity(0.9) : Color.black.opacity(0.08),
                                            lineWidth: (selectedIconName == name) ? 2 : 1
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
