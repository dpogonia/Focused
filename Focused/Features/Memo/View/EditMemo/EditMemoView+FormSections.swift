import SwiftUI
import SwiftData

extension EditMemoView {
    var isEditing: Bool { isEditingMode }

    private var descriptionBinding: Binding<String> {
        Binding(
            get: { viewModel.descript },
            set: { newValue in
                viewModel.descript = String(newValue.prefix(100))
            }
        )
    }
    
    private func memoFormSphere(id: UUID?) -> Sphere? {
        guard let id else { return nil }
        let fd = FetchDescriptor<Sphere>(predicate: #Predicate<Sphere> { $0.id == id })
        return try? modelContext.fetch(fd).first
    }
    
    @ViewBuilder
    private func memoImpactSection(
        sphere: Sphere,
        positiveImpact: Binding<Double>,
        negativeImpact: Binding<Double>
    ) -> some View {
        Section(header: Text(AppEditFormChrome.impactSectionTitle(areaName: sphere.title))) {
            ImpactSliderView(
                positiveImpact: positiveImpact,
                negativeImpact: negativeImpact,
                range: 0...100,
                step: 0.5,
                unit: "%",
                onApplyMissDecrease: { amount in
                    applyMissDecrease(to: sphere, amount: amount)
                }
            )
        }
    }
    
    // MARK: Секции формы в зависимости от `MemoItemType`
    @ViewBuilder
    var titleSection: some View {
        if memoType == .streak {
            Section(AppEditFormChrome.streakSectionTitle) {
                HStack {
                    TextField("title", text: $viewModel.title)
                    iconSelectionView
                }
                VStack(alignment: .leading, spacing: 4) {
                    ZStack(alignment: .topLeading) {
                        if viewModel.descript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("description")
                                .foregroundColor(.placeholderColor)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: descriptionBinding)
                            .frame(height: 90)
                            .scrollContentBackground(.hidden)
                    }
                }
                FormLabeledRow(label: "Target streak") {
                    TextField("None", value: Binding(
                        get: { viewModel.streakContent.targetStreak },
                        set: { newValue in
                            if let v = newValue, v > 0 {
                                viewModel.streakContent.targetStreak = v
                            } else {
                                viewModel.streakContent.targetStreak = nil
                            }
                        }
                    ), format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                }
            }
        } else {
            Section(AppEditFormChrome.titleSectionTitle) {
                HStack {
                    TextField("title", text: $viewModel.title)
                    iconSelectionView
                }
                VStack(alignment: .leading, spacing: 4) {
                    ZStack(alignment: .topLeading) {
                        if viewModel.descript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("description")
                                .foregroundColor(.placeholderColor)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: descriptionBinding)
                            .frame(height: 90)
                            .scrollContentBackground(.hidden)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    var iconSelectionView: some View {
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
        } else if memoType == .calendar {
            IconSelectionView(
                selectedIconName: Binding(
                    get: { viewModel.calendarContent.iconName },
                    set: { viewModel.calendarContent.iconName = $0 }
                ),
                colorForPicker: viewModel.calendarColorForPicker
            )
        }
    }
    
    @ViewBuilder
    var sphereSection: some View {
        switch memoType {
        case .noteAlbum:
            Section(AppEditFormChrome.areaSectionTitle) {
                AreaSphereAndColorFormContent(
                    selectedSphereID: $viewModel.noteAlbumSphereID,
                    selectedColorHex: $viewModel.noteAlbumColorHex,
                    colorForPicker: $viewModel.noteAlbumColorForPicker
                )
            }
        case .list:
            Section(AppEditFormChrome.areaSectionTitle) {
                AreaSphereAndColorFormContent(
                    selectedSphereID: Binding(
                        get: { viewModel.listContent.sphereID },
                        set: { viewModel.listContent.sphereID = $0 }
                    ),
                    selectedColorHex: $viewModel.listColorHex,
                    colorForPicker: $viewModel.listColorForPicker
                )
            }
        case .counter:
            Section(AppEditFormChrome.areaSectionTitle) {
                AreaSphereAndColorFormContent(
                    selectedSphereID: Binding(
                        get: { viewModel.counterContent.sphereID },
                        set: { viewModel.counterContent.sphereID = $0 }
                    ),
                    selectedColorHex: $viewModel.counterColorHex,
                    colorForPicker: $viewModel.counterColorForPicker
                )
            }
        case .streak:
            Section(AppEditFormChrome.areaSectionTitle) {
                AreaSphereAndColorFormContent(
                    selectedSphereID: Binding(
                        get: { viewModel.streakContent.sphereID },
                        set: { viewModel.streakContent.sphereID = $0 }
                    ),
                    selectedColorHex: $viewModel.streakColorHex,
                    colorForPicker: $viewModel.streakColorForPicker
                )
            }
        case .mood:
            Section(AppEditFormChrome.areaSectionTitle) {
                AreaSphereAndColorFormContent(
                    selectedSphereID: Binding(
                        get: { viewModel.moodContent.sphereID },
                        set: { viewModel.moodContent.sphereID = $0 }
                    ),
                    selectedColorHex: $viewModel.moodColorHex,
                    colorForPicker: $viewModel.moodColorForPicker
                )
            }
        case .skill:
            Section(AppEditFormChrome.areaSectionTitle) {
                AreaSphereAndColorFormContent(
                    selectedSphereID: Binding(
                        get: { viewModel.skillContent.sphereID },
                        set: { viewModel.skillContent.sphereID = $0 }
                    ),
                    selectedColorHex: $viewModel.skillColorHex,
                    colorForPicker: $viewModel.skillColorForPicker
                )
            }
        case .time:
            Section(AppEditFormChrome.areaSectionTitle) {
                AreaSphereAndColorFormContent(
                    selectedSphereID: Binding(
                        get: { viewModel.timeContent.sphereID },
                        set: { viewModel.timeContent.sphereID = $0 }
                    ),
                    selectedColorHex: $viewModel.timeColorHex,
                    colorForPicker: $viewModel.timeColorForPicker
                )
            }
        case .health:
            Section(AppEditFormChrome.areaSectionTitle) {
                AreaSphereAndColorFormContent(
                    selectedSphereID: Binding(
                        get: { viewModel.healthContent.sphereID },
                        set: { viewModel.healthContent.sphereID = $0 }
                    ),
                    selectedColorHex: $viewModel.healthColorHex,
                    colorForPicker: $viewModel.healthColorForPicker
                )
            }
        case .budget:
            Section(AppEditFormChrome.areaSectionTitle) {
                AreaSphereAndColorFormContent(
                    selectedSphereID: Binding(
                        get: { viewModel.budgetContent.sphereID },
                        set: { viewModel.budgetContent.sphereID = $0 }
                    ),
                    selectedColorHex: $viewModel.budgetColorHex,
                    colorForPicker: $viewModel.budgetColorForPicker
                )
            }
        case .calendar:
            Section(AppEditFormChrome.areaSectionTitle) {
                AreaSphereAndColorFormContent(
                    selectedSphereID: Binding(
                        get: { viewModel.calendarContent.sphereID },
                        set: { viewModel.calendarContent.sphereID = $0 }
                    ),
                    selectedColorHex: $viewModel.calendarColorHex,
                    colorForPicker: $viewModel.calendarColorForPicker
                )
            }
        }
    }
    
    @ViewBuilder
    var colorSection: some View {
        EmptyView()
    }
    
    @ViewBuilder
    var notesSection: some View {
        EmptyView()
    }
    
    var tagsSection: some View {
        Section(AppEditFormChrome.tagsSectionTitle) {
            MemoTagsSelectionView(selectedTags: $viewModel.selectedTags)
        }
    }
    @ViewBuilder
    var listSection: some View {
        if let sphere = memoFormSphere(id: viewModel.listContent.sphereID) {
            memoImpactSection(
                sphere: sphere,
                positiveImpact: $viewModel.listContent.positiveImpact,
                negativeImpact: $viewModel.listContent.negativeImpact
            )
        }
    }
    
    @ViewBuilder
    var contentSection: some View {
        switch memoType {
        case .noteAlbum:
            EmptyView()
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
        case .calendar:
            calendarImpactSection
        }
    }
    
    @ViewBuilder
    var calendarImpactSection: some View {
        if let sphere = memoFormSphere(id: viewModel.calendarContent.sphereID) {
            memoImpactSection(
                sphere: sphere,
                positiveImpact: $viewModel.calendarContent.positiveImpact,
                negativeImpact: $viewModel.calendarContent.negativeImpact
            )
        }
    }

    var counterSection: some View {
        Group {
            Section(AppEditFormChrome.counterSectionTitle) {
                FormLabeledRow(label: "Step") {
                    TextField("1", value: $viewModel.counterContent.stepValue, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .disabled(isEditing)
                        .opacity(isEditing ? 0.6 : 1.0)
                }

                FormLabeledRow(label: "Target value") {
                    TextField("None", value: $viewModel.counterContent.targetValue, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }

                FormLabeledRow(label: "Unit") {
                    TextField("times, ml, pages...", text: Binding(
                        get: { viewModel.counterContent.unit },
                        set: { viewModel.counterContent.unit = String($0.prefix(10)) }
                    ))
                    .textInputAutocapitalization(.never)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 120)
                }
            }
            
            if let sphere = memoFormSphere(id: viewModel.counterContent.sphereID) {
                memoImpactSection(
                    sphere: sphere,
                    positiveImpact: $viewModel.counterContent.positiveImpact,
                    negativeImpact: $viewModel.counterContent.negativeImpact
                )
            }
        }
    }

    var streakSection: some View {
        Group {
            Section(AppEditFormChrome.notesSectionTitle) {
                TextEditor(text: $viewModel.streakContent.notes)
                    .frame(minHeight: 40)
            }
            
            if let sphere = memoFormSphere(id: viewModel.streakContent.sphereID) {
                memoImpactSection(
                    sphere: sphere,
                    positiveImpact: $viewModel.streakContent.positiveImpact,
                    negativeImpact: $viewModel.streakContent.negativeImpact
                )
            }
        }
    }

    var moodSection: some View {
        Group {
            if let sphere = memoFormSphere(id: viewModel.moodContent.sphereID) {
                memoImpactSection(
                    sphere: sphere,
                    positiveImpact: $viewModel.moodContent.positiveImpact,
                    negativeImpact: $viewModel.moodContent.negativeImpact
                )
            }
        }
    }

    var skillSection: some View {
        return Group {
            Section(AppEditFormChrome.settingsSectionTitle) {
                if !isEditing {
                    FormLabeledRow(label: "Initial level") {
                        TextField("0", value: $viewModel.tempSkillLevel, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }
                
                Picker("Step", selection: $viewModel.skillContent.stepValue) {
                    ForEach([0.01, 0.1, 0.5, 1.0, 5.0, 10.0], id: \.self) { value in
                        Text(formatStepValue(value)).tag(value)
                    }
                }
                
                Picker("Maximum", selection: Binding(
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
            
            if let sphere = memoFormSphere(id: viewModel.skillContent.sphereID) {
                memoImpactSection(
                    sphere: sphere,
                    positiveImpact: $viewModel.skillContent.positiveImpact,
                    negativeImpact: $viewModel.skillContent.negativeImpact
                )
            }
        }
    }

    var budgetSection: some View {
        Group {
            Section(AppEditFormChrome.budgetSectionTitle) {
                if !isEditing {
                    FormLabeledRow(label: "Initial balance") {
                        TextField("0", value: $viewModel.budgetContent.initialBalance, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }
                }
                
                FormLabeledRow(label: "Step") {
                    TextField("100", value: $viewModel.budgetContent.stepValue, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 120)
                }
                
                FormLabeledRow(label: "Target value") {
                    TextField("None", value: Binding(
                        get: { viewModel.budgetContent.targetValue },
                        set: { newValue in
                            if let v = newValue, v > 0 {
                                viewModel.budgetContent.targetValue = v
                            } else {
                                viewModel.budgetContent.targetValue = nil
                            }
                        }
                    ), format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                }
                
                Picker("Currency", selection: Binding(
                    get: { BudgetCurrency(rawValue: viewModel.budgetContent.currency) ?? .none },
                    set: { viewModel.budgetContent.currency = $0.rawValue }
                )) {
                    ForEach(BudgetCurrency.allCases, id: \.rawValue) { currency in
                        Text(currency.displayTitle).tag(currency)
                    }
                }
            }
            
            if let sphere = memoFormSphere(id: viewModel.budgetContent.sphereID) {
                memoImpactSection(
                    sphere: sphere,
                    positiveImpact: $viewModel.budgetContent.positiveImpact,
                    negativeImpact: $viewModel.budgetContent.negativeImpact
                )
            }
        }
    }

    var timeSection: some View {
        Group {
            Section(AppEditFormChrome.timeSectionTitle) {
                if !isEditing {
                    FormLabeledRow(label: "Initial time") {
                        HStack(spacing: 8) {
                            TextField("0", value: $viewModel.timeContent.initialMinutes, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 120)
                            Text("min")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Picker("Time step", selection: Binding(
                    get: { Int(viewModel.timeContent.stepMinutes) },
                    set: { viewModel.timeContent.stepMinutes = Double($0) }
                )) {
                    ForEach([1, 5, 10, 15, 30, 60], id: \.self) { value in
                        Text("\(value) min").tag(value)
                    }
                }
                
                FormLabeledRow(label: "Target value") {
                    HStack(spacing: 8) {
                        Group {
                            if viewModel.timeContent.targetDisplayUnit == .min {
                                TextField("None", value: Binding(
                                    get: { viewModel.timeContent.targetMinutes },
                                    set: { newValue in
                                        if let v = newValue, v > 0 {
                                            viewModel.timeContent.targetMinutes = v
                                        } else {
                                            viewModel.timeContent.targetMinutes = nil
                                        }
                                    }
                                ), format: .number)
                            } else {
                                TextField("None", value: Binding(
                                    get: {
                                        guard let m = viewModel.timeContent.targetMinutes, m > 0 else { return nil }
                                        let hrs = m / 60.0
                                        return (hrs * 10).rounded() / 10
                                    },
                                    set: { newValue in
                                        if let v = newValue, v > 0 {
                                            viewModel.timeContent.targetMinutes = (v * 60 * 10).rounded() / 10
                                        } else {
                                            viewModel.timeContent.targetMinutes = nil
                                        }
                                    }
                                ), format: .number.precision(.fractionLength(1)))
                            }
                        }
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        
                        Picker("", selection: $viewModel.timeContent.targetDisplayUnit) {
                            Text("min").tag(TimeTargetUnit.min)
                            Text("hrs").tag(TimeTargetUnit.hrs)
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 70)
                    }
                }
            }
            
            if let sphere = memoFormSphere(id: viewModel.timeContent.sphereID) {
                memoImpactSection(
                    sphere: sphere,
                    positiveImpact: $viewModel.timeContent.positiveImpact,
                    negativeImpact: $viewModel.timeContent.negativeImpact
                )
            }
        }
    }
    
    var healthSection: some View {
        Group {
            Section(AppEditFormChrome.healthSectionTitle) {
                if !isEditing {
                    FormLabeledRow(label: "Initial value") {
                        TextField("0", value: $viewModel.healthContent.initialValue, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }
                }
                
                Picker("Step", selection: $viewModel.healthContent.stepValue) {
                    ForEach([0.01, 0.1, 0.5, 1.0, 5.0, 10.0], id: \.self) { value in
                        Text(formatStepValue(value)).tag(value)
                    }
                }
                
                FormLabeledRow(label: "Target value") {
                    TextField("None", value: Binding(
                        get: { viewModel.healthContent.targetValue },
                        set: { newValue in
                            if let v = newValue, v > 0 {
                                viewModel.healthContent.targetValue = v
                            } else {
                                viewModel.healthContent.targetValue = nil
                            }
                        }
                    ), format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                }
                
                Picker("Unit", selection: Binding(
                    get: { viewModel.healthContent.unit.isEmpty ? "unit" : viewModel.healthContent.unit },
                    set: { viewModel.healthContent.unit = $0 }
                )) {
                    let commonUnits = ["kg", "cm", "bpm", "mmHg", "°C", "mmol/L", "unit"]
                    ForEach(commonUnits, id: \.self) { unit in
                        Text(unit).tag(unit)
                    }
                }
            }
            
            if let sphere = memoFormSphere(id: viewModel.healthContent.sphereID) {
                memoImpactSection(
                    sphere: sphere,
                    positiveImpact: $viewModel.healthContent.positiveImpact,
                    negativeImpact: $viewModel.healthContent.negativeImpact
                )
            }
        }
    }
    
    func formatStepValue(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        } else {
            let stepString = String(value)
            let decimalPlaces = stepString.contains(".") ? stepString.split(separator: ".").last?.count ?? 1 : 0
            return String(format: "%.\(min(decimalPlaces, 2))f", value)
        }
    }
    
    func applyMissDecrease(to sphere: Sphere, amount: Double) {
        let clamped = max(0.0, min(100.0, amount))
        sphere.satisfaction = max(0.0, min(100.0, sphere.satisfaction - clamped))
        try? modelContext.save()
    }

    func saveMemo() {
        do {
            let memoItem = try viewModel.createMemoItem()
            if !isEditing {
                // Создание нового мемо
                modelContext.insert(memoItem)
            }
            try modelContext.save()
            TagMaintenanceService.pruneUnusedTags(modelContext: modelContext)
            dismiss()
        } catch {
            print("Error saving memo: \(error)")
        }
    }

}
