import SwiftUI

// Presentation · Memo — тип «здоровье»: шкалы и история измерений в контенте мемо.
// Аналогично другим типам: сериализация в `MemoItem`, без отдельного репозитория на тип.
// Оглавление: модель → экран → круг/кнопки/прогресс/история/стат → карточка и sheet’ы.

// MARK: Модель данных health-мемо
struct MemoHealthContent: Codable, Hashable {
    var initialValue: Double = 0.0
    var stepValue: Double = 0.1
    var currentValue: Double = 0.0
    var targetValue: Double? = nil
    var unit: String = "units"
    var iconName: String = "heart.fill"
    var customImageData: Data? = nil
    var colorHex: String = "#E6332A"
    var sphereID: UUID? = nil
    var notes: String = ""
    var entries: [HealthEntry] = []
    var positiveImpact: Double = 0.0
    var negativeImpact: Double = 0.0
    var additionalImpacts: [SphereImpact] = []
    
    struct HealthEntry: Codable, Hashable, Identifiable {
        var id: UUID
        var date: Date
        var value: Double
        var note: String = ""
        
        init(id: UUID = UUID(), date: Date = Date(), value: Double = 0, note: String = "") {
            self.id = id
            self.date = date
            self.value = value
            self.note = note
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
            self.date = try container.decode(Date.self, forKey: .date)
            self.value = try container.decode(Double.self, forKey: .value)
            self.note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        }
        
        private enum CodingKeys: String, CodingKey {
            case id, date, value, note
        }
    }
    
    var color: Color { Color(hex: colorHex) }
}

// MARK: Главный экран health-мемо
struct HealthContentView: View {
    let item: MemoItem
    @Binding var showHealthStatistics: Bool
    
    @Environment(\.modelContext) private var modelContext
    @State private var healthContent: MemoHealthContent = MemoHealthContent()
    @State private var showEditSheet = false
    @State private var showValueEditor = false
    @State private var pendingDeltaValue: Double = 0
    @State private var selectedStatsPeriod: MemoStatsPeriod = .month
    @State private var entryToDelete: MemoHealthContent.HealthEntry? = nil
    @State private var entryToEdit: MemoHealthContent.HealthEntry? = nil
    @State private var circlePulseScale: CGFloat = 1.0
    @State private var iconPulseTrigger = UUID()
    @State private var repeatTimer: Timer? = nil
    
    private let hapticManager = HapticSoundManager.shared
    
    private func effectiveStep() -> Double {
        let raw = healthContent.stepValue
        let positive = raw > 0 ? raw : 0.1
        return max(0.01, (positive * 100).rounded() / 100)
    }
    
    private var filteredEntries: [MemoHealthContent.HealthEntry] {
        guard let start = selectedStatsPeriod.startDate() else {
            return healthContent.entries
        }
        return healthContent.entries.filter { $0.date >= start }
    }
    
    private var displayedValue: Double { healthContent.currentValue + pendingDeltaValue }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    healthCircleView
                    
                    controlButtonsView
                    
                    if let target = healthContent.targetValue, target > 0 {
                        progressView(target: target)
                    }
                    
                    if !healthContent.entries.isEmpty {
                        historyHistorySection
                    }
                }
                .padding(.horizontal)
                .padding(.top, 4)
                .padding(.bottom, 16)
            }
        }
        .onAppear {
            loadContent()
            iconPulseTrigger = UUID()
        }
        .onDisappear {
            stopRepeatTimer()
        }
        .sheet(isPresented: $showEditSheet) {
            HealthEditorSheet(healthContent: $healthContent, onSave: {
                saveContent()
            })
        }
        .fullScreenCover(isPresented: $showHealthStatistics) {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 16) {
                        statisticsView
                        if !filteredEntries.isEmpty {
                            ChartView(
                                data: createFilteredChartData(),
                                title: "Value changes",
                                color: Color(hex: healthContent.colorHex),
                                unit: healthContent.unit
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
                            showHealthStatistics = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .frostedDeleteConfirmation(
            isPresented: Binding(
                get: { entryToDelete != nil },
                set: { if !$0 { entryToDelete = nil } }
            ),
            title: "Delete history entry?",
            message: "This action cannot be undone.",
            onConfirm: {
                if let entry = entryToDelete {
                    deleteEntry(entry)
                    entryToDelete = nil
                }
            }
        )
        .sheet(item: $entryToEdit) { entry in
            HealthEntryEditSheet(
                entry: entry,
                unit: healthContent.unit,
                stepValue: effectiveStep(),
                colorHex: healthContent.colorHex,
                onSave: { updated in
                    if let idx = healthContent.entries.firstIndex(where: { $0.id == updated.id }) {
                        let oldValue = healthContent.entries[idx].value
                        healthContent.entries[idx] = updated
                        healthContent.currentValue += (updated.value - oldValue)
                        saveContent()
                    }
                    entryToEdit = nil
                },
                onCancel: {
                    entryToEdit = nil
                }
            )
        }
        .fullScreenCover(isPresented: $showValueEditor) {
                HealthValueEditorSheet(
                    currentValue: healthContent.currentValue,
                    stepValue: effectiveStep(),
                    unit: healthContent.unit,
                color: Color(hex: healthContent.colorHex),
                onSave: { deltaValue, note in
                    healthContent.currentValue += deltaValue
                    addEntry(value: deltaValue, note: note)
                    saveContent()
                    showValueEditor = false
                },
                onCancel: {
                    showValueEditor = false
                }
            )
        }
    }
    
    // MARK: Верхний круг — текущее значение и контекстное меню
    private var healthCircleView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                if let imageData = healthContent.customImageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .clipShape(Circle())
                        .iconPulseOnceOnAppear()
                } else {
                    Image(systemName: healthContent.iconName)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(Color(hex: healthContent.colorHex))
                        .symbolEffect(.pulse, options: .nonRepeating, value: iconPulseTrigger)
                }
                
                Text("\(formatValue(displayedValue)) \(healthContent.unit)")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color(hex: healthContent.colorHex))
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
                .fill(Color(hex: healthContent.colorHex).opacity(0.16))
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .scaleEffect(circlePulseScale)
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contextMenu {
            Button {
                showEditSheet = true
            } label: {
                Label("Edit", systemImage: "pencil")
            }
        }
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
                        .foregroundColor(Color(hex: healthContent.colorHex))
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
                        .foregroundColor(Color(hex: healthContent.colorHex))
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
            
            if pendingDeltaValue != 0 {
                HStack(spacing: 20) {
                    Button("Cancel") {
                        pendingDeltaValue = 0
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
                    .background(Color(hex: healthContent.colorHex))
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
                        .foregroundColor(Color(hex: healthContent.colorHex))
                        .font(.subheadline)
                    Text("Progress to target")
                        .font(.headline)
                }
                Spacer()
                Text("\(formatValueShort(displayedValue)) / \(formatValueShort(target))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 12)
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: healthContent.colorHex))
                        .frame(
                            width: geometry.size.width * min(max(CGFloat(displayedValue) / CGFloat(max(target, 0.0001)), 0), 1.0),
                            height: 12
                        )
                }
            }
            .frame(height: 12)
            
            Text("\(target > 0 ? Int(displayedValue / max(target, 0.0001) * 100) : 0)%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: История измерений
    private var historyHistorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(Color(hex: healthContent.colorHex))
                    Text("History")
                        .font(.headline)
                    Spacer()
                    Text("\(healthContent.entries.count)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 12) {
                    ForEach(healthContent.entries.sorted(by: { $0.date > $1.date }).prefix(10)) { entry in
                        HStack(spacing: 12) {
                            Button {
                                hapticManager.selectionChanged()
                                entryToEdit = entry
                            } label: {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text((entry.value >= 0 ? "+" : "") + formatValue(entry.value) + " " + healthContent.unit)
                                            .font(.subheadline.bold())
                                            .foregroundColor(entry.value >= 0 ? .blue : .red)
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
    
    // MARK: Сводка изменений
    private var valueChangesSection: some View {
        ChartView(
            data: createChartData(),
            title: "Value changes",
            color: Color(hex: healthContent.colorHex),
            unit: healthContent.unit
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
                    valueScalesDown: true,
                    title: "Current",
                    value: formatValueShort(healthContent.currentValue),
                    icon: "heart.fill",
                    color: Color(hex: healthContent.colorHex)
                )
                
                if let target = healthContent.targetValue {
                    MemoStatisticMetricCard(
                        valueScalesDown: true,
                        title: "Target",
                        value: formatValueShort(target),
                        icon: "target",
                        color: .green
                    )
                }
            }
            
            if !filteredEntries.isEmpty {
                HStack(spacing: 16) {
                    let values = filteredEntries.map { $0.value }
                    let minVal = values.min() ?? 0
                    MemoStatisticMetricCard(
                        valueScalesDown: true,
                        title: "Min change",
                        value: formatValueShort(minVal),
                        icon: "arrow.down.circle",
                        color: .blue
                    )
                    
                    let maxVal = values.max() ?? 0
                    MemoStatisticMetricCard(
                        valueScalesDown: true,
                        title: "Max change",
                        value: formatValueShort(maxVal),
                        icon: "arrow.up.circle",
                        color: .orange
                    )
                }
                
                HStack(spacing: 16) {
                    let totalAdded = filteredEntries.filter { $0.value > 0 }.reduce(0.0) { $0 + $1.value }
                    MemoStatisticMetricCard(
                        valueScalesDown: true,
                        title: "Total added",
                        value: formatValueShort(totalAdded),
                        icon: "plus.circle",
                        color: .green
                    )
                    
                    let totalRemoved = abs(filteredEntries.filter { $0.value < 0 }.reduce(0.0) { $0 + $1.value })
                    MemoStatisticMetricCard(
                        valueScalesDown: true,
                        title: "Total removed",
                        value: formatValueShort(totalRemoved),
                        icon: "minus.circle",
                        color: .red
                    )
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: Сохранение и форматирование
    private func loadContent() {
        if let data = item.contentData,
           let content = try? JSONDecoder().decode(MemoHealthContent.self, from: data) {
            healthContent = content
            if healthContent.currentValue == 0.0 && healthContent.initialValue != 0.0 {
                healthContent.currentValue = healthContent.initialValue
            }
        }
    }
    
    private func saveContent() {
        if let data = try? JSONEncoder().encode(healthContent) {
            item.contentData = data
            try? modelContext.save()
        }
    }
    
    private func addPendingDelta(_ delta: Double) {
        withAnimation {
            pendingDeltaValue += delta
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
        guard pendingDeltaValue != 0 else { return }
        withAnimation {
            healthContent.currentValue += pendingDeltaValue
            addEntry(value: pendingDeltaValue)
            pendingDeltaValue = 0
        }
        hapticManager.playHaptic(style: .light)
        saveContent()
    }
    
    private func addEntry(value: Double, note: String = "") {
        let entry = MemoHealthContent.HealthEntry(
            date: Date(),
            value: value,
            note: note
        )
        healthContent.entries.append(entry)
    }
    
    private func deleteEntry(_ entry: MemoHealthContent.HealthEntry) {
        withAnimation {
            healthContent.entries.removeAll { $0.id == entry.id }
        }
        hapticManager.playHaptic(style: .medium)
        saveContent()
    }
    
    private func createChartData() -> [ChartDataPoint] {
        var cumulativeValue: Double = healthContent.initialValue
        let sortedEntries = healthContent.entries.sorted(by: { $0.date < $1.date })
        
        return sortedEntries.map { entry in
            cumulativeValue += entry.value
            return ChartDataPoint(date: entry.date, value: cumulativeValue)
        }
    }
    
    private func createFilteredChartData() -> [ChartDataPoint] {
        var cumulativeValue: Double = 0
        let sortedEntries = filteredEntries.sorted(by: { $0.date < $1.date })
        
        return sortedEntries.map { entry in
            cumulativeValue += entry.value
            return ChartDataPoint(date: entry.date, value: cumulativeValue)
        }
    }
    
    private func formatValue(_ value: Double) -> String {
        let absValue = abs(value)
        if absValue.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        } else {
            let stepString = String(healthContent.stepValue)
            let decimalPlaces = stepString.contains(".") ? stepString.split(separator: ".").last?.count ?? 1 : 0
            return String(format: "%.\(min(decimalPlaces, 2))f", value)
        }
    }
    
    private func formatValueShort(_ value: Double) -> String {
        if abs(value).truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }
}

// MARK: Sheet — правка записи истории
struct HealthEntryEditSheet: View {
    let entry: MemoHealthContent.HealthEntry
    let unit: String
    let stepValue: Double
    let colorHex: String
    let onSave: (MemoHealthContent.HealthEntry) -> Void
    let onCancel: () -> Void
    
    @State private var editableValue: Double
    @State private var editableNote: String
    
    init(entry: MemoHealthContent.HealthEntry, unit: String, stepValue: Double, colorHex: String, onSave: @escaping (MemoHealthContent.HealthEntry) -> Void, onCancel: @escaping () -> Void) {
        self.entry = entry
        self.unit = unit
        self.stepValue = stepValue
        self.colorHex = colorHex
        self.onSave = onSave
        self.onCancel = onCancel
        _editableValue = State(initialValue: entry.value)
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
                        let updated = MemoHealthContent.HealthEntry(
                            id: entry.id,
                            date: entry.date,
                            value: editableValue,
                            note: editableNote
                        )
                        onSave(updated)
                    }
                }
            }
        }
    }
}

// MARK: Sheet — настройки health-мемо
struct HealthEditorSheet: View {
    @Binding var healthContent: MemoHealthContent
    let onSave: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    private func formatStepValue(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        } else {
            let stepString = String(value)
            let decimalPlaces = stepString.contains(".") ? stepString.split(separator: ".").last?.count ?? 1 : 0
            return String(format: "%.\(min(decimalPlaces, 2))f", value)
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(AppEditFormChrome.healthSectionTitle) {
                    HStack {
                        Text("Initial value")
                        Spacer()
                        TextField("0", value: $healthContent.initialValue, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }
                    
                    Picker("Step", selection: $healthContent.stepValue) {
                        ForEach([0.01, 0.1, 0.5, 1.0, 5.0, 10.0], id: \.self) { value in
                            Text(formatStepValue(value)).tag(value)
                        }
                    }
                    
                    HStack {
                        Text("Target value")
                        Spacer()
                        TextField("None", value: Binding(
                            get: { healthContent.targetValue },
                            set: { newValue in
                                if let v = newValue, v > 0 {
                                    healthContent.targetValue = v
                                } else {
                                    healthContent.targetValue = nil
                                }
                            }
                        ), format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    }
                    
                    Picker("Unit", selection: Binding(
                        get: { healthContent.unit.isEmpty ? "unit" : healthContent.unit },
                        set: { healthContent.unit = $0 }
                    )) {
                        let commonUnits = ["kg", "cm", "bpm", "mmHg", "°C", "mmol/L", "unit"]
                        ForEach(commonUnits, id: \.self) { unit in
                            Text(unit).tag(unit)
                        }
                    }
                }
                
                Section(AppEditFormChrome.notesSectionTitle) {
                    TextEditor(text: $healthContent.notes)
                        .frame(minHeight: 40)
                }
                
                Section(AppEditFormChrome.appearanceSectionTitle) {
                    MediaCirclePicker(
                        config: MediaCirclePickerConfiguration(
                            dialogTitle: "Health media",
                            tintHex: healthContent.colorHex,
                            size: 72,
                            fallbackIconName: "heart.fill"
                        ),
                        imageData: $healthContent.customImageData,
                        iconName: Binding(
                            get: { Optional(healthContent.iconName) },
                            set: { newValue in
                                if let newValue { healthContent.iconName = newValue }
                            }
                        )
                    )
                    
                    ColorPicker("Color", selection: Binding(
                        get: { Color(hex: healthContent.colorHex) },
                        set: { healthContent.colorHex = $0.toHex() ?? "#E6332A" }
                    ))
                }
            }
            .navigationTitle("Edit health tracker")
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
struct HealthValueEditorSheet: View {
    let currentValue: Double
    let stepValue: Double
    let unit: String
    let color: Color
    let onSave: (Double, String) -> Void
    let onCancel: () -> Void
    
    @State private var deltaValue: Double = 0.0
    @State private var valueText: String = "0"
    @State private var note: String = ""
    @FocusState private var isTextFieldFocused: Bool
    
    private let hapticManager = HapticSoundManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .foregroundColor(.red)
                
                Spacer()
                
                Text("Adjust Value")
                    .font(.headline)
                
                Spacer()
                
                Button("Save") {
                    onSave(deltaValue, note)
                }
                .foregroundColor(color)
                .disabled(deltaValue == 0.0)
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            
            ScrollView {
                VStack(spacing: 24) {
                    HStack(spacing: 20) {
                        Button {
                            deltaValue -= stepValue
                            updateValueText()
                            hapticManager.playHaptic(style: .light)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.red)
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 4) {
                            TextField("0", text: $valueText)
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(color)
                                .multilineTextAlignment(.center)
                                .keyboardType(.decimalPad)
                                .focused($isTextFieldFocused)
                                .onChange(of: valueText) { oldValue, newValue in
                                    deltaValue = parseValueInput(newValue)
                                }
                                .frame(width: 120)
                            
                            Text(unit)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button {
                            deltaValue += stepValue
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
                }
            }
        }
        .onAppear {
            deltaValue = 0.0
            valueText = "0"
            note = ""
        }
    }
    
    private func updateValueText() {
        if deltaValue == 0.0 {
            valueText = "0"
        } else {
            let absValue = abs(deltaValue)
            if absValue.truncatingRemainder(dividingBy: 1) == 0 {
                valueText = String(format: "%.0f", deltaValue)
            } else {
                valueText = String(format: "%.2f", deltaValue)
            }
        }
    }
    
    private func parseValueInput(_ input: String) -> Double {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return 0.0 }
        
        if let value = Double(trimmed) {
            return value
        }
        
        return 0.0
    }
}
