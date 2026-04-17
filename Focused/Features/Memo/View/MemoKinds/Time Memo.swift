import SwiftUI

// Presentation · Memo — тип «время»: таймеры, сессии, статистика по периодам.
// Оглавление: шаги/единицы → модель `MemoTimeContent` → экран → круг/кнопки/прогресс/история/статистика → карточка и sheet’ы.

// MARK: Шаг приращения времени (мин / ч)
enum TimeStepOption: Double, CaseIterable, Identifiable {
    case min1 = 1
    case min3 = 3
    case min5 = 5
    case min10 = 10
    case min15 = 15
    case hour1 = 60
    case hour24 = 1440
    
    var id: Double { rawValue }
    
    var displayName: String {
        switch self {
        case .min1: return "1 min"
        case .min3: return "3 min"
        case .min5: return "5 min"
        case .min10: return "10 min"
        case .min15: return "15 min"
        case .hour1: return "1 hour"
        case .hour24: return "24 hours"
        }
    }
}

/// Display unit for target value: "min" (minutes) or "hrs" (hours, 1 decimal)
enum TimeTargetUnit: String, Codable, CaseIterable {
    case min = "min"
    case hrs = "hrs"
}

struct MemoTimeContent: Codable, Hashable {
    var initialMinutes: Double = 0.0
    var stepMinutes: Double = 1.0
    var currentMinutes: Double = 0.0
    var targetMinutes: Double? = nil
    var targetDisplayUnit: TimeTargetUnit = .min
    var iconName: String = "clock.fill"
    var customImageData: Data? = nil
    var colorHex: String = "#32ADE6"
    var sphereID: UUID? = nil
    var notes: String = ""
    var entries: [TimeEntry] = []
    var positiveImpact: Double = 0.0
    var negativeImpact: Double = 0.0
    var additionalImpacts: [SphereImpact] = []
    
    struct TimeEntry: Codable, Hashable, Identifiable {
        var id: UUID
        var date: Date
        var minutes: Double
        var note: String = ""
        
        init(id: UUID = UUID(), date: Date = Date(), minutes: Double = 0, note: String = "") {
            self.id = id
            self.date = date
            self.minutes = minutes
            self.note = note
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
            self.date = try container.decode(Date.self, forKey: .date)
            self.minutes = try container.decode(Double.self, forKey: .minutes)
            self.note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        }
        
        private enum CodingKeys: String, CodingKey {
            case id, date, minutes, note
        }
    }
    
    var color: Color { Color(hex: colorHex) }
}

// MARK: Главный экран time-мемо
struct TimeContentView: View {
    let item: MemoItem
    @Binding var showTimeStatistics: Bool
    
    @Environment(\.modelContext) private var modelContext
    @State private var timeContent: MemoTimeContent = MemoTimeContent()
    @State private var showEditSheet = false
    @State private var showValueEditor = false
    @State private var pendingDeltaMinutes: Double = 0
    @State private var selectedStatsPeriod: MemoStatsPeriod = .month
    @State private var entryToDelete: MemoTimeContent.TimeEntry? = nil
    @State private var entryToEdit: MemoTimeContent.TimeEntry? = nil
    @State private var repeatTimer: Timer? = nil
    @State private var circlePulseScale: CGFloat = 1.0
    @State private var iconPulseTrigger = UUID()
    
    private let hapticManager = HapticSoundManager.shared
    
    private func effectiveStep() -> Double {
        let raw = timeContent.stepMinutes
        return raw > 0 ? raw : 1.0
    }
    
    private var filteredEntries: [MemoTimeContent.TimeEntry] {
        guard let start = selectedStatsPeriod.startDate() else {
            return timeContent.entries
        }
        return timeContent.entries.filter { $0.date >= start }
    }
    
    private var displayedMinutes: Double { timeContent.currentMinutes + pendingDeltaMinutes }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    timeCircleView
                    
                    controlButtonsView
                    
                    if let target = timeContent.targetMinutes, target > 0 {
                        progressView(target: target)
                    }
                    
                    if !timeContent.entries.isEmpty {
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
            TimeEditorSheet(timeContent: $timeContent, onSave: {
                saveContent()
            })
        }
        .fullScreenCover(isPresented: $showTimeStatistics) {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 16) {
                        statisticsView
                        if !filteredEntries.isEmpty {
                            ChartView(
                                data: createFilteredChartData(),
                                title: "Time changes",
                                color: Color(hex: timeContent.colorHex),
                                unit: "min"
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
                            showTimeStatistics = false
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
            TimeEntryEditSheet(
                entry: entry,
                stepMinutes: effectiveStep(),
                colorHex: timeContent.colorHex,
                onSave: { updated in
                    if let idx = timeContent.entries.firstIndex(where: { $0.id == updated.id }) {
                        let oldMinutes = timeContent.entries[idx].minutes
                        timeContent.entries[idx] = updated
                        timeContent.currentMinutes = max(0, timeContent.currentMinutes - oldMinutes + updated.minutes)
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
            TimeValueEditorSheet(
                currentMinutes: timeContent.currentMinutes,
                stepMinutes: effectiveStep(),
                color: Color(hex: timeContent.colorHex),
                onSave: { deltaMinutes, note in
                    timeContent.currentMinutes += deltaMinutes
                    addEntry(minutes: deltaMinutes, note: note)
                    saveContent()
                    showValueEditor = false
                },
                onCancel: {
                    showValueEditor = false
                }
            )
        }
    }
    
    // MARK: Верхний «круг» — сумма времени, long-press шаг
    private var timeCircleView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                if let imageData = timeContent.customImageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .clipShape(Circle())
                        .iconPulseOnceOnAppear()
                } else {
                    Image(systemName: timeContent.iconName)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(Color(hex: timeContent.colorHex))
                        .symbolEffect(.pulse, options: .nonRepeating, value: iconPulseTrigger)
                }
                
                Text("\(formatMinutes(displayedMinutes)) total")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color(hex: timeContent.colorHex))
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
                .fill(Color(hex: timeContent.colorHex).opacity(0.16))
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
    
    // MARK: Кнопки +/− и удержание (повтор шага)
    private var controlButtonsView: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                Button {
                    addPendingDelta(-effectiveStep())
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(Color(hex: timeContent.colorHex))
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
                        .foregroundColor(Color(hex: timeContent.colorHex))
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
            
            if pendingDeltaMinutes != 0 {
                HStack(spacing: 20) {
                    Button("Cancel") {
                        pendingDeltaMinutes = 0
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
                    .background(Color(hex: timeContent.colorHex))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 40)
                .transition(.opacity)
            }
        }
    }
    
    // MARK: Прогресс к цели (target)
    private func progressView(target: Double) -> some View {
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(Color(hex: timeContent.colorHex))
                        .font(.subheadline)
                    Text("Progress to target")
                        .font(.headline)
                }
                Spacer()
                Text("\(formatMinutesShort(displayedMinutes)) / \(formatMinutesShort(target))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 12)
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: timeContent.colorHex))
                        .frame(
                            width: geometry.size.width * min(max(CGFloat(displayedMinutes) / CGFloat(max(target, 0.0001)), 0), 1.0),
                            height: 12
                        )
                }
            }
            .frame(height: 12)
            
            Text("\(target > 0 ? Int(displayedMinutes / max(target, 0.0001) * 100) : 0)%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: История сессий
    private var historyHistorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(Color(hex: timeContent.colorHex))
                    Text("History")
                        .font(.headline)
                    Spacer()
                    Text("\(timeContent.entries.count)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 12) {
                    ForEach(timeContent.entries.sorted(by: { $0.date > $1.date }).prefix(10)) { entry in
                        HStack(spacing: 12) {
                            Button {
                                hapticManager.selectionChanged()
                                entryToEdit = entry
                            } label: {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text((entry.minutes >= 0 ? "+" : "") + formatMinutes(entry.minutes))
                                            .font(.subheadline.bold())
                                            .foregroundColor(entry.minutes >= 0 ? .blue : .red)
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
            data: createChartData(),
            title: "Time changes",
            color: Color(hex: timeContent.colorHex),
            unit: "min"
        )
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .frame(height: 200)
        .padding(.top, 8)
    }
    
    // MARK: Мини-статистика по периоду
    private var statisticsView: some View {
        VStack(spacing: 16) {
            MemoStatsPeriodSegmentedPicker(selection: $selectedStatsPeriod)
            
            Text("Statistics")
                .font(.headline)
            
            HStack(spacing: 16) {
                MemoStatisticMetricCard(
                    valueScalesDown: true,
                    title: "Total",
                    value: formatMinutesShort(timeContent.currentMinutes),
                    icon: "clock.fill",
                    color: Color(hex: timeContent.colorHex)
                )
                
                if let target = timeContent.targetMinutes {
                    MemoStatisticMetricCard(
                        valueScalesDown: true,
                        title: "Target",
                        value: formatMinutesShort(target),
                        icon: "target",
                        color: .green
                    )
                }
            }
            
            HStack(spacing: 16) {
                let totalAdded = filteredEntries.filter { $0.minutes > 0 }.reduce(0.0) { $0 + $1.minutes }
                MemoStatisticMetricCard(
                    valueScalesDown: true,
                    title: "Added",
                    value: formatMinutesShort(totalAdded),
                    icon: "plus.circle",
                    color: .blue
                )
                
                let totalRemoved = abs(filteredEntries.filter { $0.minutes < 0 }.reduce(0.0) { $0 + $1.minutes })
                MemoStatisticMetricCard(
                    valueScalesDown: true,
                    title: "Removed",
                    value: formatMinutesShort(totalRemoved),
                    icon: "minus.circle",
                    color: .orange
                )
            }
            
            HStack(spacing: 16) {
                let entriesCount = filteredEntries.count
                MemoStatisticMetricCard(
                    valueScalesDown: true,
                    title: "Entries",
                    value: "\(entriesCount)",
                    icon: "list.bullet",
                    color: .purple
                )
                
                if !filteredEntries.isEmpty {
                    let avgPerEntry = filteredEntries.map { abs($0.minutes) }.reduce(0, +) / Double(filteredEntries.count)
                    MemoStatisticMetricCard(
                        valueScalesDown: true,
                        title: "Avg/entry",
                        value: formatMinutesShort(avgPerEntry),
                        icon: "chart.bar",
                        color: .teal
                    )
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: Сохранение контента и форматирование
    private func loadContent() {
        if let data = item.contentData,
           let content = try? JSONDecoder().decode(MemoTimeContent.self, from: data) {
            timeContent = content
            if timeContent.currentMinutes == 0.0 && timeContent.initialMinutes > 0.0 {
                timeContent.currentMinutes = timeContent.initialMinutes
            }
        }
    }
    
    private func saveContent() {
        if let data = try? JSONEncoder().encode(timeContent) {
            item.contentData = data
            try? modelContext.save()
        }
    }
    
    private func addPendingDelta(_ minutes: Double) {
        withAnimation {
            if displayedMinutes + minutes >= 0 {
                pendingDeltaMinutes += minutes
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
        guard pendingDeltaMinutes != 0 else { return }
        withAnimation {
            timeContent.currentMinutes = max(0, timeContent.currentMinutes + pendingDeltaMinutes)
            addEntry(minutes: pendingDeltaMinutes)
            pendingDeltaMinutes = 0
        }
        hapticManager.playHaptic(style: .light)
        saveContent()
    }
    
    private func addEntry(minutes: Double, note: String = "") {
        let entry = MemoTimeContent.TimeEntry(
            date: Date(),
            minutes: minutes,
            note: note
        )
        timeContent.entries.append(entry)
    }
    
    private func deleteEntry(_ entry: MemoTimeContent.TimeEntry) {
        withAnimation {
            timeContent.entries.removeAll { $0.id == entry.id }
        }
        hapticManager.playHaptic(style: .medium)
        saveContent()
    }
    
    private func createChartData() -> [ChartDataPoint] {
        var cumulativeMinutes: Double = timeContent.initialMinutes
        let sortedEntries = timeContent.entries.sorted(by: { $0.date < $1.date })
        
        return sortedEntries.map { entry in
            cumulativeMinutes += entry.minutes
            return ChartDataPoint(date: entry.date, value: cumulativeMinutes)
        }
    }
    
    private func createFilteredChartData() -> [ChartDataPoint] {
        var cumulativeMinutes: Double = 0
        let sortedEntries = filteredEntries.sorted(by: { $0.date < $1.date })
        
        return sortedEntries.map { entry in
            cumulativeMinutes += entry.minutes
            return ChartDataPoint(date: entry.date, value: cumulativeMinutes)
        }
    }
    
    private func formatMinutes(_ minutes: Double) -> String {
        let totalMinutes = Int(abs(minutes))
        let hrs = totalMinutes / 60
        let mins = totalMinutes % 60
        let sign = minutes < 0 ? "-" : ""
        if hrs > 0 {
            return sign + String(format: "%dh %02dm", hrs, mins)
        } else {
            return sign + String(format: "%dm", mins)
        }
    }
    
    private func formatMinutesShort(_ minutes: Double) -> String {
        let totalMinutes = Int(abs(minutes))
        let hrs = totalMinutes / 60
        let mins = totalMinutes % 60
        if hrs > 0 {
            return String(format: "%dh %dm", hrs, mins)
        } else {
            return String(format: "%dm", mins)
        }
    }
}

// MARK: Sheet — правка одной записи истории
struct TimeEntryEditSheet: View {
    let entry: MemoTimeContent.TimeEntry
    let stepMinutes: Double
    let colorHex: String
    let onSave: (MemoTimeContent.TimeEntry) -> Void
    let onCancel: () -> Void
    
    @State private var editableMinutes: Double
    @State private var editableNote: String
    
    init(entry: MemoTimeContent.TimeEntry, stepMinutes: Double, colorHex: String, onSave: @escaping (MemoTimeContent.TimeEntry) -> Void, onCancel: @escaping () -> Void) {
        self.entry = entry
        self.stepMinutes = stepMinutes
        self.colorHex = colorHex
        self.onSave = onSave
        self.onCancel = onCancel
        _editableMinutes = State(initialValue: entry.minutes)
        _editableNote = State(initialValue: entry.note)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(AppEditFormChrome.minutesSectionTitle) {
                    TextField("Minutes", value: $editableMinutes, format: .number)
                        .keyboardType(.decimalPad)
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
                        let updated = MemoTimeContent.TimeEntry(
                            id: entry.id,
                            date: entry.date,
                            minutes: editableMinutes,
                            note: editableNote
                        )
                        onSave(updated)
                    }
                }
            }
        }
    }
}

// MARK: Sheet — настройки time-мемо (шаг, цвет, сфера)
struct TimeEditorSheet: View {
    @Binding var timeContent: MemoTimeContent
    let onSave: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section(AppEditFormChrome.timeSectionTitle) {
                    Picker("Step", selection: Binding(
                        get: {
                            TimeStepOption.allCases.first { $0.rawValue == timeContent.stepMinutes }
                                ?? .min1
                        },
                        set: { timeContent.stepMinutes = $0.rawValue }
                    )) {
                        ForEach(TimeStepOption.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    
                    HStack {
                        Text("Target value")
                        Spacer()
                        Group {
                            if timeContent.targetDisplayUnit == .min {
                                TextField("None", value: Binding(
                                    get: { timeContent.targetMinutes },
                                    set: { newValue in
                                        if let v = newValue, v > 0 {
                                            timeContent.targetMinutes = v
                                        } else {
                                            timeContent.targetMinutes = nil
                                        }
                                    }
                                ), format: .number)
                            } else {
                                TextField("None", value: Binding(
                                    get: {
                                        guard let m = timeContent.targetMinutes, m > 0 else { return nil }
                                        let hrs = m / 60.0
                                        return (hrs * 10).rounded() / 10
                                    },
                                    set: { newValue in
                                        if let v = newValue, v > 0 {
                                            timeContent.targetMinutes = (v * 60 * 10).rounded() / 10
                                        } else {
                                            timeContent.targetMinutes = nil
                                        }
                                    }
                                ), format: .number.precision(.fractionLength(1)))
                            }
                        }
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        
                        Picker("", selection: $timeContent.targetDisplayUnit) {
                            Text("min").tag(TimeTargetUnit.min)
                            Text("hrs").tag(TimeTargetUnit.hrs)
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 70)
                    }
                }
                
                Section(AppEditFormChrome.notesSectionTitle) {
                    TextEditor(text: $timeContent.notes)
                        .frame(minHeight: 40)
                }
                
                Section(AppEditFormChrome.appearanceSectionTitle) {
                    MediaCirclePicker(
                        config: MediaCirclePickerConfiguration(
                            dialogTitle: "Time media",
                            tintHex: timeContent.colorHex,
                            size: 72,
                            fallbackIconName: "clock"
                        ),
                        imageData: $timeContent.customImageData,
                        iconName: Binding(
                            get: { Optional(timeContent.iconName) },
                            set: { newValue in
                                if let newValue { timeContent.iconName = newValue }
                            }
                        )
                    )
                    
                    ColorPicker("Color", selection: Binding(
                        get: { Color(hex: timeContent.colorHex) },
                        set: { timeContent.colorHex = $0.toHex() ?? "#32ADE6" }
                    ))
                }
            }
            .navigationTitle("Edit time tracker")
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

// MARK: Sheet — быстрый ввод минут
struct TimeValueEditorSheet: View {
    let currentMinutes: Double
    let stepMinutes: Double
    let color: Color
    let onSave: (Double, String) -> Void
    let onCancel: () -> Void
    
    @State private var deltaMinutes: Double = 0.0
    @State private var minutesText: String = "0"
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
                
                Text("Adjust Time")
                    .font(.headline)
                
                Spacer()
                
                Button("Save") {
                    onSave(deltaMinutes, note)
                }
                .foregroundColor(color)
                .disabled(deltaMinutes == 0.0)
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            
            ScrollView {
                VStack(spacing: 24) {
                    HStack(spacing: 20) {
                        Button {
                            deltaMinutes -= stepMinutes
                            updateMinutesText()
                            hapticManager.playHaptic(style: .light)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.red)
                        }
                        
                        Spacer()
                        
                        TextField("0", text: $minutesText)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(color)
                            .multilineTextAlignment(.center)
                            .keyboardType(.numbersAndPunctuation)
                            .focused($isTextFieldFocused)
                            .onChange(of: minutesText) { oldValue, newValue in
                                deltaMinutes = parseTimeInput(newValue)
                            }
                            .frame(width: 120)
                        
                        Spacer()
                        
                        Button {
                            deltaMinutes += stepMinutes
                            updateMinutesText()
                            hapticManager.playHaptic(style: .light)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    Text("minutes (or use hh:mm format)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
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
            deltaMinutes = 0.0
            minutesText = "0"
            note = ""
        }
    }
    
    private func updateMinutesText() {
        let totalMinutes = Int(abs(deltaMinutes))
        if deltaMinutes == 0.0 {
            minutesText = "0"
        } else if deltaMinutes < 0 {
            minutesText = "-\(totalMinutes)"
        } else {
            minutesText = "\(totalMinutes)"
        }
    }
    
    private func parseTimeInput(_ input: String) -> Double {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return 0.0 }
        
        let isNegative = trimmed.hasPrefix("-")
        let cleanInput = isNegative ? String(trimmed.dropFirst()) : trimmed
        
        if let minutes = Double(cleanInput) {
            return isNegative ? -minutes : minutes
        }
        
        if let colonIndex = cleanInput.firstIndex(of: ":") {
            let hoursPart = String(cleanInput[..<colonIndex])
            let minutesPart = String(cleanInput[cleanInput.index(after: colonIndex)...])
            
            if let hours = Double(hoursPart), let minutes = Double(minutesPart) {
                let totalMinutes = hours * 60 + minutes
                return isNegative ? -totalMinutes : totalMinutes
            }
        }
        
        return 0.0
    }
}
