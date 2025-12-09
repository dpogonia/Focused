import SwiftUI
import SwiftData

// MARK: - ADD/EDIT HABIT VIEW
struct EditHabitView: View {
    var modelContext: ModelContext
    @Binding var habitToEdit: Habit?
    var allHabitsCount: Int = 0
    let ruleEffectiveDate: Date
    
    @Environment(\.dismiss) private var dismiss
    
    @Query private var spheres: [Sphere]
    
    @State private var title: String
    @State private var colorHex: String
    @State private var selectedIconName: String = "star.fill"
    @State private var selectedWeeklyDays: [Int: Bool]
    @State private var selectedMonthlyDays: [Int]
    @State private var selectedSphereID: UUID?
    @State private var isPassive: Bool = false
    @State private var positiveImpact: Double = 0.0
    @State private var negativeImpact: Double = 0.0
    @State private var tags: [String] = []
    @State private var requiredRepetitions: Int = 1
    @State private var repetitionsPreset: Int? = nil
    @State private var showWheelPicker: Bool = false
    
    @State private var colorForPicker: Color = .blue
    @State private var colorUpdateTrigger: Bool = false
    
    private let hapticManager = HapticSoundManager.shared
    private let noneSphereId: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    @State private var spherePickerId: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    
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
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Habit Details")) {
                    TextField("title", text: $title)
                    Picker("Habit Type", selection: $isPassive) {
                        Text("Active").tag(false)
                        Text("Passive").tag(true)
                    }
                    .pickerStyle(.segmented)
                    ColorSelectionView(
                        availableColors: AppConstants.Colors.palette,
                        selectedColorHex: $colorHex,
                        colorForPicker: $colorForPicker
                    )
                    ScrollView {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                            ForEach(availableHabitIcons, id: \.self) { iconName in
                                Button(action: {
                                    print("Icon tapped: \(iconName)")
                                    selectedIconName = iconName
                                    print("Selected icon set to: \(selectedIconName)")
                                    hapticManager.playHaptic(style: .light)
                                }) {
                                    Image(systemName: iconName)
                                        .font(.title2)
                                        .foregroundColor(selectedIconName == iconName ? .white : .primary)
                                        .frame(width: 40, height: 40)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(selectedIconName == iconName ? (colorForPicker == .clear ? Color.accentColor : colorForPicker) : Color.gray.opacity(0.1))
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .id("\(selectedIconName)_\(colorUpdateTrigger)")
                    }.frame(height: 144)
                }
                
                Section(header: Text("Repetition Frequency")) {
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
                
                Section(header: Text("Sphere")) {
                    VStack(alignment: .leading, spacing: 8) {
                        // Picker for sphere selection
                        Picker("Linked Sphere", selection: $spherePickerId) {
                            // None option
                            Text("None").tag(noneSphereId)
                            // Spheres list
                            ForEach(spheres) { sphere in
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(Color(hex: sphere.colorHex))
                                        .frame(width: 10, height: 10)
                                    Text(sphere.title)
                                }
                                .tag(sphere.id)
                            }
                        }
                        .onChange(of: spherePickerId) { old, newValue in
                            if newValue == noneSphereId {
                                selectedSphereID = nil
                            } else {
                                selectedSphereID = newValue
                            }
                        }
                        .pickerStyle(.menu)

                        if let sid = selectedSphereID, let sphere = spheres.first(where: { $0.id == sid }) {
                            // Show impact sliders only when sphere selected
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Impact on \(sphere.title)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                ImpactSliderView(
                                    positiveImpact: $positiveImpact,
                                    negativeImpact: $negativeImpact,
                                    range: 0...100,
                                    step: 0.01,
                                    unit: "%"
                                )
                            }
                        } else {
                            // Hide sliders and reset impacts when no sphere
                            EmptyView()
                        }
                    }
                }
                Section(header: Text("Tags")) {
                    MemoTagsSelectionView(selectedTags: $tags)
                }
                
                if let habit = habitToEdit {
                    StatisticsView(habit: habit, endDate: ruleEffectiveDate)
                }
                
                if habitToEdit != nil {
                    DeleteConfirmationButton(itemName: "Habit") {
                        if let habit = habitToEdit {
                            modelContext.delete(habit)
                            do {
                                try modelContext.save()
                            } catch {
                                print("Failed to save model context: \(error.localizedDescription)")
                            }
                            dismiss()
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
        .onAppear {
            loadHabitData()
            // Sync picker with current selection
            if let sid = selectedSphereID {
                spherePickerId = sid
            } else {
                spherePickerId = noneSphereId
            }
        }
        .onChange(of: habitToEdit) {
            loadHabitData()
            if let sid = selectedSphereID {
                spherePickerId = sid
            } else {
                spherePickerId = noneSphereId
            }
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
            colorHex = habit.colorHex
            selectedIconName = habit.iconName.isEmpty ? "star.fill" : habit.iconName
            selectedSphereID = habit.sphereID
            isPassive = habit.isPassive
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
            colorHex = AppConstants.Colors.palette.first ?? "#3498db"
            selectedIconName = "star.fill"
            selectedWeeklyDays = [:]
            selectedMonthlyDays = []
            selectedFrequencyPicker = .weekly
            selectedSphereID = nil
            repetitionsPreset = 1  // Default to 1 for new habits
            isPassive = false
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
        for tagName in tags {
            let fetchDescriptor = FetchDescriptor<Tag>(predicate: #Predicate<Tag> { $0.name == tagName })
            if let existingTag = try? modelContext.fetch(fetchDescriptor).first {
                habitTags.append(existingTag)
            } else {
                let newTag = Tag(name: tagName)
                modelContext.insert(newTag)
                habitTags.append(newTag)
            }
        }
        
        if let habit = habitToEdit {
            habit.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            habit.colorHex = colorHex
            habit.iconName = selectedIconName.isEmpty ? "star.fill" : selectedIconName
            habit.sphereID = selectedSphereID
            habit.isPassive = isPassive
            habit.positiveImpact = positiveImpact
            habit.negativeImpact = negativeImpact
            habit.tags = habitTags
            habit.requiredRepetitions = requiredRepetitions
            
            let lastRule = habit.repeatingRules.last
            let rulesChanged = lastRule?.weeklyFrequency != currentWeeklyFrequency || lastRule?.monthlySpecificDays != currentMonthlyDays
            
            if rulesChanged {
                let newRepeatingRule = RepeatingRule(
                    startDate: ruleEffectiveDate,
                    weeklyFrequency: currentWeeklyFrequency,
                    monthlySpecificDays: currentMonthlyDays
                )
                habit.repeatingRules.append(newRepeatingRule)
                habit.repeatingRules.sort { $0.startDate < $1.startDate }
            }
        } else {
            let initialRule = RepeatingRule(
                startDate: ruleEffectiveDate,
                weeklyFrequency: currentWeeklyFrequency,
                monthlySpecificDays: currentMonthlyDays
            )
            
            let newHabit = Habit(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                colorHex: colorHex,
                iconName: selectedIconName.isEmpty ? "star.fill" : selectedIconName,
                orderIndex: allHabitsCount,
                creationDate: ruleEffectiveDate,
                initialRule: initialRule,
                sphereID: selectedSphereID,
                isPassive: isPassive,
                positiveImpact: positiveImpact,
                negativeImpact: negativeImpact,
                requiredRepetitions: requiredRepetitions
            )
            newHabit.tags = habitTags
            modelContext.insert(newHabit)
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to save model context: \(error.localizedDescription)")
        }
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
                    TextField("Day", text: $dayInput)
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
