import SwiftUI
import SwiftData

// Presentation · Memo — тип «счётчик»: модель, UI, история значений.
// Оглавление: модель → impact по сферам → экран → шапка/кнопки/прогресс/история/стат → карточка и sheet’ы.

// MARK: Модель данных счётчика
struct MemoCounterContent: Codable, Hashable {
    var currentValue: Double = 0
    var initialValue: Double = 0
    var stepValue: Double = 1
    var targetValue: Double?
    var unit: String = ""
    var notes: String = ""
    var history: [CounterEntry] = []
    var iconName: String = "number.circle"
    var customImageData: Data? = nil
    var colorHex: String = "#FF9500" // default orange
    var sphereID: UUID? = nil
    var positiveImpact: Double = 0.0
    var negativeImpact: Double = 0.0
    var additionalImpacts: [SphereImpact] = []
    
    struct CounterEntry: Codable, Hashable, Identifiable {
        var id: UUID = UUID()
        var date: Date
        var value: Double
        var note: String = ""
    }
}

// MARK: Запись влияния на несколько сфер
struct SphereImpact: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var sphereID: UUID?
    var positiveImpact: Double
    var negativeImpact: Double
    
    init(sphereID: UUID? = nil, positiveImpact: Double = 0.0, negativeImpact: Double = 0.0) {
        self.sphereID = sphereID
        self.positiveImpact = positiveImpact
        self.negativeImpact = negativeImpact
    }
}

// MARK: Главный экран counter-мемо
struct CounterContentView: View {
    let item: MemoItem
    @Binding var showCounterStatistics: Bool
    
    @Environment(\.modelContext) private var modelContext
    @State private var counterContent: MemoCounterContent = MemoCounterContent()
    @State private var showEditSheet = false
    @State private var alertField: EditingField? = nil
    @State private var fieldEditText: String = ""
    @State private var showValueEditor = false
    @State private var pendingDelta: Double = 0
    @State private var selectedStatsPeriod: MemoStatsPeriod = .month
    @State private var entryToDelete: MemoCounterContent.CounterEntry? = nil
    @State private var entryToEdit: MemoCounterContent.CounterEntry? = nil
    @State private var circlePulseScale: CGFloat = 1.0
    @State private var iconPulseTrigger = UUID()
    @State private var repeatTimer: Timer? = nil
    
    private let hapticManager = HapticSoundManager.shared
    
    private var filteredHistory: [MemoCounterContent.CounterEntry] {
        guard let start = selectedStatsPeriod.startDate() else {
            return counterContent.history
        }
        return counterContent.history.filter { $0.date >= start }
    }
    
    private var displayedValue: Double { counterContent.currentValue + pendingDelta }
    
    enum EditingField {
        case currentValue, targetValue, unit
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    // Main Counter Header
                    counterCircleView
                    
                    // Control Buttons
                    controlButtonsView
                    
                    // Progress to Target
                    if let target = counterContent.targetValue, target > 0 {
                        progressView(target: target)
                    }
                    
                    if !counterContent.history.isEmpty {
                        historyHistorySection
                    }
                }
                .padding(.horizontal)
                .padding(.top, 4)
                .padding(.bottom, 16)
            }
        }
        .onAppear {
            loadCounter()
            iconPulseTrigger = UUID()
        }
        .onDisappear {
            stopRepeatTimer()
        }
        .sheet(isPresented: $showEditSheet) {
            CounterEditorSheet(counterContent: $counterContent, onSave: {
                saveCounter()
            })
        }
        .fullScreenCover(isPresented: $showCounterStatistics) {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 16) {
                        statisticsView
                        if !filteredHistory.isEmpty {
                            ChartView(
                                data: filteredHistory.sorted(by: { $0.date < $1.date }).map { ChartDataPoint(date: $0.date, value: Double($0.value)) },
                                title: "Value changes",
                                color: Color(hex: counterContent.colorHex),
                                unit: counterContent.unit
                            )
                            .frame(height: 200)
                        }
                    }
                    .padding()
                }
                .background(Color(UIColor.systemGroupedBackground))
                .navigationTitle("Statistics")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showCounterStatistics = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .alert(
            alertField.map { fieldTitle(for: $0) } ?? "",
            isPresented: Binding(
                get: { alertField != nil },
                set: { if !$0 { alertField = nil } }
            ),
            actions: {
                TextField(
                    alertField.map { fieldPlaceholder(for: $0) } ?? "",
                    text: $fieldEditText
                )
                .keyboardType(alertField == .targetValue ? .numberPad : .default)
                Button("Save") {
                    if let field = alertField {
                        saveEditedField(field, text: fieldEditText)
                        alertField = nil
                    }
                }
                Button("Cancel", role: .cancel) {
                    alertField = nil
                }
            }
        )
        .frostedDeleteConfirmation(
            isPresented: Binding(
                get: { entryToDelete != nil },
                set: { if !$0 { entryToDelete = nil } }
            ),
            title: "Delete history entry?",
            message: "This action cannot be undone.",
            onConfirm: {
                if let entry = entryToDelete {
                    deleteHistoryEntry(entry)
                    entryToDelete = nil
                }
            }
        )
        .sheet(item: $entryToEdit) { entry in
            CounterEntryEditSheet(
                entry: entry,
                unit: counterContent.unit,
                colorHex: counterContent.colorHex,
                onSave: { updated in
                    if let idx = counterContent.history.firstIndex(where: { $0.id == updated.id }) {
                        counterContent.history[idx] = updated
                        saveCounter()
                    }
                    entryToEdit = nil
                },
                onCancel: {
                    entryToEdit = nil
                }
            )
        }
        .fullScreenCover(isPresented: $showValueEditor) {
            CounterValueEditorSheet(
                currentValue: counterContent.currentValue,
                color: Color(hex: counterContent.colorHex),
                onSave: { newValue, note in
                    counterContent.currentValue = newValue
                    addHistoryEntry(value: newValue, note: note)
                    saveCounter()
                    showValueEditor = false
                },
                onCancel: {
                    showValueEditor = false
                }
            )
        }
    }
    
    // MARK: Шапка — иконка, текущее значение, цель
    private var counterCircleView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                if let imageData = counterContent.customImageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .clipShape(Circle())
                        .iconPulseOnceOnAppear()
                } else {
                    Image(systemName: counterContent.iconName)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(Color(hex: counterContent.colorHex))
                        .symbolEffect(.pulse, options: .nonRepeating, value: iconPulseTrigger)
                }
                
                let valueText = formattedHeaderValue()
                Text(valueText)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color(hex: counterContent.colorHex))
                    .onTapGesture(count: 2) {
                        showValueEditor = true
                    }
                
                Spacer()
            }
            .padding()
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(hex: counterContent.colorHex).opacity(0.16))
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .scaleEffect(circlePulseScale)
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onLongPressGesture(minimumDuration: 1.5, maximumDistance: 50) {
            addPendingDelta(effectiveStep())
        } onPressingChanged: { isPressing in
            if isPressing {
                withAnimation(.easeInOut(duration: 1.5)) {
                    circlePulseScale = 1.05
                }
            } else {
                withAnimation(.easeOut(duration: 0.25)) {
                    circlePulseScale = 1.0
                }
            }
        }
    }
    
    // MARK: Кнопки +/− и удержание
    private var controlButtonsView: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                Button {
                    addPendingDelta(-effectiveStep())
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(Color(hex: counterContent.colorHex))
                }
                .onLongPressGesture(minimumDuration: 0.4, pressing: { pressing in
                    if pressing {
                        startRepeatTimer(delta: -effectiveStep())
                    } else {
                        stopRepeatTimer()
                    }
                }, perform: {})
                
                Spacer()
                
                Button {
                    addPendingDelta(effectiveStep())
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(Color(hex: counterContent.colorHex))
                }
                .onLongPressGesture(minimumDuration: 0.4, pressing: { pressing in
                    if pressing {
                        startRepeatTimer(delta: effectiveStep())
                    } else {
                        stopRepeatTimer()
                    }
                }, perform: {})
            }
            .padding(.horizontal, 40)
            
            if pendingDelta != 0 {
                HStack(spacing: 20) {
                    Button("Cancel") {
                        pendingDelta = 0
                        hapticManager.playHaptic(style: .light)
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    Button("Accept") {
                        acceptPendingDelta()
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(hex: counterContent.colorHex))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 40)
                .transition(.opacity)
            }
        }
    }
    
    // MARK: Прогресс к цели
    private func progressView(target: Double) -> some View {
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(Color(hex: counterContent.colorHex))
                        .font(.subheadline)
                    Text("Progress to target")
                        .font(.headline)
                }
                Spacer()
                Text("\(formatNumber(displayedValue)) / \(formatNumber(target))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 12)
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: counterContent.colorHex))
                        .frame(
                            width: geometry.size.width * min(
                                CGFloat(displayedValue / max(target, 0.0001)),
                                1.0
                            ),
                            height: 12
                        )
                }
            }
            .frame(height: 12)
            
            // Percentage
            Text("\(Int(displayedValue / max(target, 0.0001) * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
                .onTapGesture(count: 2) {
                    startEditing(.targetValue)
                }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: История изменений
    private var historyHistorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(Color(hex: counterContent.colorHex))
                    Text("History")
                        .font(.headline)
                    Spacer()
                    Text("\(counterContent.history.count)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 12) {
                    ForEach(counterContent.history.sorted(by: { $0.date > $1.date }).prefix(10)) { entry in
                        HStack(spacing: 12) {
                            Button {
                                hapticManager.selectionChanged()
                                entryToEdit = entry
                            } label: {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(formatNumber(entry.value)) \(counterContent.unit)")
                                            .font(.subheadline.bold())
                                        Text(entry.date, style: .date)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if !entry.note.isEmpty {
                                        Text(entry.note)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                    }
                                    
                                    Image(systemName: "pencil")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            
                            Button {
                                hapticManager.playNotificationHaptic(type: .warning)
                                entryToDelete = entry
                            } label: {
                                Image(systemName: "trash")
                                    .font(.body)
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding()
                        .background(Color(UIColor.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .contextMenu {
                            Button {
                                entryToEdit = entry
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                entryToDelete = entry
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: Сводка изменений значения
    private var valueChangesSection: some View {
        ChartView(
            data: counterContent.history.sorted(by: { $0.date < $1.date }).map {
                ChartDataPoint(date: $0.date, value: $0.value)
            },
            title: "Value changes",
            color: Color(hex: counterContent.colorHex),
            unit: counterContent.unit
        )
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .frame(height: 200)
        .padding(.top, 8)
    }
    
    // MARK: Мини-статистика
    private var statisticsView: some View {
        VStack(spacing: 16) {
            MemoStatsPeriodSegmentedPicker(selection: $selectedStatsPeriod)
            
            Text("Statistics")
                .font(.headline)
            
            HStack(spacing: 16) {
                MemoStatisticMetricCard(
                    title: "Current",
                    value: formatNumber(counterContent.currentValue),
                    icon: "number.circle",
                    color: Color(hex: counterContent.colorHex)
                )
                
                if let target = counterContent.targetValue {
                    MemoStatisticMetricCard(
                        title: "Target",
                        value: formatNumber(target),
                        icon: "flag.fill",
                        color: .green
                    )
                }
            }
            
            HStack(spacing: 16) {
                if let min = filteredHistory.map({ $0.value }).min() {
                    MemoStatisticMetricCard(
                        title: "Minimum",
                        value: formatNumber(min),
                        icon: "arrow.down.circle",
                        color: .blue
                    )
                }
                
                if let max = filteredHistory.map({ $0.value }).max() {
                    MemoStatisticMetricCard(
                        title: "Maximum",
                        value: formatNumber(max),
                        icon: "arrow.up.circle",
                        color: .orange
                    )
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: Сохранение и форматирование
    private func effectiveStep() -> Double {
        let raw = counterContent.stepValue
        let positive = raw > 0 ? raw : 1
        let clamped = max(0.01, positive)
        // округляем до сотых
        return (clamped * 100).rounded() / 100
    }

    private func formatNumber(_ value: Double) -> String {
        value.formatted()
    }
    private func loadCounter() {
        if let data = item.contentData,
           let content = try? JSONDecoder().decode(MemoCounterContent.self, from: data) {
            counterContent = content
        }
    }
    
    private func saveCounter() {
        if let data = try? JSONEncoder().encode(counterContent) {
            item.contentData = data
            try? modelContext.save()
        }
    }
    
    private func addPendingDelta(_ delta: Double) {
        withAnimation {
            if displayedValue + delta >= 0 {
                pendingDelta += delta
            }
        }
        hapticManager.playHaptic(style: .light)
    }
    
    private func startRepeatTimer(delta: Double) {
        stopRepeatTimer()
        repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            addPendingDelta(delta)
        }
        RunLoop.main.add(repeatTimer!, forMode: .common)
    }
    
    private func stopRepeatTimer() {
        repeatTimer?.invalidate()
        repeatTimer = nil
    }
    
    private func acceptPendingDelta() {
        guard pendingDelta != 0 else { return }
        let newValue = max(0, counterContent.currentValue + pendingDelta)
        withAnimation {
            counterContent.currentValue = newValue
            addHistoryEntry(value: newValue)
            pendingDelta = 0
        }
        hapticManager.playHaptic(style: .light)
        saveCounter()
    }
    
    private func addHistoryEntry(value: Double, note: String = "") {
        let entry = MemoCounterContent.CounterEntry(
            date: Date(),
            value: value,
            note: note
        )
        counterContent.history.append(entry)
    }
    
    private func deleteHistoryEntry(_ entry: MemoCounterContent.CounterEntry) {
        withAnimation {
            counterContent.history.removeAll { $0.id == entry.id }
        }
        hapticManager.playHaptic(style: .medium)
        saveCounter()
    }
    
    private func startEditing(_ field: EditingField) {
        switch field {
        case .currentValue:
            showValueEditor = true
        case .targetValue:
            fieldEditText = counterContent.targetValue != nil ? "\(counterContent.targetValue!)" : ""
            alertField = .targetValue
        case .unit:
            fieldEditText = counterContent.unit
            alertField = .unit
        }
    }
    
    private func saveEditedField(_ field: EditingField, text: String) {
        switch field {
        case .currentValue:
            // Handled by CounterValueEditorSheet
            break
        case .targetValue:
            counterContent.targetValue = Double(text.replacingOccurrences(of: ",", with: "."))
        case .unit:
            counterContent.unit = normalizeUnit(text)
        }
        hapticManager.playHaptic(style: .light)
        saveCounter()
    }
    
    private func fieldTitle(for field: EditingField) -> String {
        switch field {
        case .currentValue: return "Current value"
        case .targetValue: return "Target value"
        case .unit: return "Unit"
        }
    }
    
    private func fieldPlaceholder(for field: EditingField) -> String {
        switch field {
        case .currentValue: return "0"
        case .targetValue: return "100"
        case .unit: return "times, ml, pages..."
        }
    }
    
    private func normalizeUnit(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let limited = String(trimmed.prefix(10))
        // Keep all‑caps units (e.g. "USD", "KM") as is
        if limited == limited.uppercased() {
            return limited
        }
        let first = limited.prefix(1).lowercased()
        let rest = limited.dropFirst()
        return String(first + rest)
    }
    
    private func formattedHeaderValue() -> String {
        let number = formatNumber(displayedValue)
        let unit = counterContent.unit.trimmingCharacters(in: .whitespacesAndNewlines)
        if unit.isEmpty {
            return number
        }
        return "\(number) \(unit)"
    }
}

// MARK: Sheet — правка записи истории
struct CounterEntryEditSheet: View {
    let entry: MemoCounterContent.CounterEntry
    let unit: String
    let colorHex: String
    let onSave: (MemoCounterContent.CounterEntry) -> Void
    let onCancel: () -> Void
    
    @State private var editableValue: Double
    @State private var editableNote: String
    
    init(entry: MemoCounterContent.CounterEntry, unit: String, colorHex: String, onSave: @escaping (MemoCounterContent.CounterEntry) -> Void, onCancel: @escaping () -> Void) {
        self.entry = entry
        self.unit = unit
        self.colorHex = colorHex
        self.onSave = onSave
        self.onCancel = onCancel
        _editableValue = State(initialValue: max(0, entry.value))
        _editableNote = State(initialValue: entry.note)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(AppEditFormChrome.valueSectionTitle) {
                    TextField("Value", value: $editableValue, format: .number)
                        .keyboardType(.decimalPad)
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(AppEditFormChrome.noteSectionTitle) {
                    TextEditor(text: $editableNote)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("Edit entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let updated = MemoCounterContent.CounterEntry(
                            id: entry.id,
                            date: entry.date,
                            value: max(0, editableValue),
                            note: editableNote
                        )
                        onSave(updated)
                    }
                }
            }
        }
    }
}

// MARK: Sheet — настройки счётчика
struct CounterEditorSheet: View {
    @Binding var counterContent: MemoCounterContent
    let onSave: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section(AppEditFormChrome.mainSectionTitle) {
                    HStack {
                        Text("Step")
                        Spacer()
            TextField("1", value: $counterContent.stepValue, format: .number)
                .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .disabled(true)
                            .opacity(0.6)
                    }
                    
                    HStack {
                        Text("Target value")
                        Spacer()
                        TextField("None", value: $counterContent.targetValue, format: .number)
                .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Unit")
                        Spacer()
                        TextField("times, ml, pages...", text: Binding(
                            get: { counterContent.unit },
                            set: { counterContent.unit = String($0.prefix(10)) }
                        ))
                        .textInputAutocapitalization(.never)
                        .multilineTextAlignment(.trailing)
                    }
                }
                
                Section(AppEditFormChrome.appearanceSectionTitle) {
                    MediaCirclePicker(
                        config: MediaCirclePickerConfiguration(
                            dialogTitle: "Counter media",
                            tintHex: counterContent.colorHex,
                            size: 72,
                            fallbackIconName: "number.circle"
                        ),
                        imageData: $counterContent.customImageData,
                        iconName: Binding(
                            get: { Optional(counterContent.iconName) },
                            set: { newValue in
                                if let newValue { counterContent.iconName = newValue }
                            }
                        )
                    )
                    
                    ColorPicker("Color", selection: Binding(
                        get: { Color(hex: counterContent.colorHex) },
                        set: { counterContent.colorHex = $0.toHex() ?? "#FF9500" }
                    ))
                }
            }
            .navigationTitle("Edit counter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSave()
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: Sheet — быстрый ввод значения
struct CounterValueEditorSheet: View {
    let currentValue: Double
    let color: Color
    let onSave: (Double, String) -> Void
    let onCancel: () -> Void
    
    @State private var deltaValue: Double = 0
    @State private var valueText: String = "0"
    @State private var note: String = ""
    @FocusState private var isTextFieldFocused: Bool
    
    private let hapticManager = HapticSoundManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    HStack(spacing: 20) {
                        Button {
                            deltaValue -= 1
                            updateValueText()
                            hapticManager.playHaptic(style: .light)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.red)
                        }
                        
                        Spacer()
                        
                        TextField("0", text: $valueText)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(color)
                            .multilineTextAlignment(.center)
                            .keyboardType(.numbersAndPunctuation)
                            .focused($isTextFieldFocused)
                            .onChange(of: valueText) { oldValue, newValue in
                                deltaValue = parseValueInput(newValue)
                            }
                            .frame(width: 120)
                        
                        Spacer()
                        
                        Button {
                            deltaValue += 1
                            updateValueText()
                            hapticManager.playHaptic(style: .light)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Note (optional)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                        
                        TextField("enter note", text: $note)
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal, 20)
                    }
                    
                    HStack(spacing: 20) {
                        Button("Cancel") {
                            resetDelta()
                            onCancel()
                        }
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        Button("Save") {
                            let newValue = currentValue + deltaValue
                            onSave(newValue, note)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(color)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .disabled(deltaValue == 0 && note.isEmpty)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .onAppear {
            resetDelta()
        }
    }
    
    private func resetDelta() {
        deltaValue = 0
        valueText = "0"
        note = ""
        isTextFieldFocused = false
    }
    
    private func updateValueText() {
        if deltaValue == 0 {
            valueText = "0"
        } else {
            valueText = String(abs(deltaValue))
        }
    }
    
    private func parseValueInput(_ input: String) -> Double {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            return 0
        }
        
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        if let value = Double(normalized) {
            return value
        }
        
        return 0
    }
}

