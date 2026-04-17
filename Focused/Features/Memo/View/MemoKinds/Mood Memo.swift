import SwiftUI

// Presentation · Memo — тип «настроение»: шкала, записи, визуализация трендов.
// Оглавление: модель `MemoMoodContent` → экран → шапка-круг → быстрый ввод → история → статистика → свойства и сохранение → карточка метрики → sheet'ы → `getMoodColor` / `getMoodSymbol`.

// MARK: Модель данных mood-мемо
struct MemoMoodContent: Codable, Hashable {
    var entries: [MoodEntry] = []
    var scale: Int = 10
    var iconName: String = "face.smiling"
    var customImageData: Data? = nil
    var colorHex: String = "#FF2D55"
    var sphereID: UUID? = nil
    var notes: String = ""
    var positiveImpact: Double = 0.0
    var negativeImpact: Double = 0.0
    var additionalImpacts: [SphereImpact] = []
    
    struct MoodEntry: Codable, Hashable, Identifiable {
        var id: UUID
        var date: Date
        var value: Int
        var tags: [String] = []
        var notes: String = ""
        
        init(id: UUID = UUID(), date: Date = Date(), value: Int = 5, tags: [String] = [], notes: String = "") {
            self.id = id
            self.date = date
            self.value = value
            self.tags = tags
            self.notes = notes
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
            self.date = try container.decode(Date.self, forKey: .date)
            self.value = try container.decode(Int.self, forKey: .value)
            self.tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
            self.notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        }
        
        private enum CodingKeys: String, CodingKey {
            case id, date, value, tags, notes
        }
    }
    
    var color: Color { Color(hex: colorHex) }
}

private struct MoodQuickEntryTrigger: Identifiable {
    let id = UUID()
    let value: Int
}

// MARK: Главный экран mood-мемо
struct MoodContentView: View {
    let item: MemoItem
    @Binding var showMoodStatistics: Bool
    
    @Environment(\.modelContext) private var modelContext
    @State private var moodContent: MemoMoodContent = MemoMoodContent()
    @State private var showEditSheet = false
    @State private var entryToDelete: MemoMoodContent.MoodEntry? = nil
    @State private var entryToEdit: MemoMoodContent.MoodEntry? = nil
    @State private var selectedStatsPeriod: MemoStatsPeriod = .month
    @State private var pendingQuickMood: MoodQuickEntryTrigger? = nil
    @State private var quickMoodNote: String = ""
    @State private var iconPulseTrigger = UUID()
    
    private let hapticManager = HapticSoundManager.shared
    
    private var filteredEntries: [MemoMoodContent.MoodEntry] {
        guard let start = selectedStatsPeriod.startDate() else {
            return moodContent.entries
        }
        return moodContent.entries.filter { $0.date >= start }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    moodCircleView
                    
                    quickInputView
                    
                    if !moodContent.entries.isEmpty {
                        historyView
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
        .sheet(isPresented: $showEditSheet) {
            MoodEditorSheet(moodContent: $moodContent, onSave: {
                saveContent()
            })
        }
        .fullScreenCover(isPresented: $showMoodStatistics) {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 16) {
                        statisticsView
                        if !filteredEntries.isEmpty {
                            ChartView(
                                data: filteredEntries.sorted(by: { $0.date < $1.date }).map {
                                    ChartDataPoint(date: $0.date, value: Double($0.value))
                                },
                                title: "Mood dynamics",
                                color: Color(hex: moodContent.colorHex),
                                unit: "level"
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
                            showMoodStatistics = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .sheet(item: $entryToEdit) { entry in
            MoodEntryEditSheet(
                entry: entry,
                scale: moodContent.scale,
                colorHex: moodContent.colorHex,
                onSave: { updated in
                    if let idx = moodContent.entries.firstIndex(where: { $0.id == updated.id }) {
                        moodContent.entries[idx] = updated
                        saveContent()
                    }
                    entryToEdit = nil
                },
                onCancel: {
                    entryToEdit = nil
                }
            )
        }
        .frostedDeleteConfirmation(
            isPresented: Binding(
                get: { entryToDelete != nil },
                set: { if !$0 { entryToDelete = nil } }
            ),
            title: "Delete mood entry?",
            message: "This action cannot be undone.",
            onConfirm: {
                if let entry = entryToDelete {
                    deleteEntry(entry)
                    entryToDelete = nil
                }
            }
        )
    }
    
    // MARK: Горизонтальная шапка — иконка и среднее (как у counter/budget)
    private var moodCircleView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                if let imageData = moodContent.customImageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .clipShape(Circle())
                        .iconPulseOnceOnAppear()
                } else {
                    Image(systemName: moodContent.iconName)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(Color(hex: moodContent.colorHex))
                        .symbolEffect(.pulse, options: .nonRepeating, value: iconPulseTrigger)
                }
                
                if !moodContent.entries.isEmpty {
                    Text(String(format: "%.1f", averageMood) + " / \(moodContent.scale)")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color(hex: moodContent.colorHex))
                } else {
                    Text("No data")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color(hex: moodContent.colorHex).opacity(0.7))
                }
                
                Spacer()
            }
            .padding()
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(hex: moodContent.colorHex).opacity(0.16))
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contextMenu {
            Button {
                showEditSheet = true
            } label: {
                Label("Edit", systemImage: "pencil")
            }
        }
    }
    
    // MARK: Быстрый ввод по сетке значений
    private var quickInputView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "plus.circle")
                    .foregroundColor(Color(hex: moodContent.colorHex))
                Text("Quick entry")
                    .font(.headline)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: min(moodContent.scale, 5)), spacing: 12) {
                ForEach(1...moodContent.scale, id: \.self) { value in
                    Button {
                        quickMoodNote = ""
                        pendingQuickMood = MoodQuickEntryTrigger(value: value)
                    } label: {
                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .fill(getMoodColor(for: value, scale: moodContent.scale).opacity(0.15))
                                    .frame(width: 50, height: 50)
                                
                                VStack(spacing: 2) {
                                    Text("\(value)")
                                        .font(.subheadline.bold())
                                        .foregroundColor(getMoodColor(for: value, scale: moodContent.scale))
                                    
                                    Image(systemName: getMoodSymbol(for: value, scale: moodContent.scale))
                                        .font(.caption)
                                        .foregroundColor(getMoodColor(for: value, scale: moodContent.scale))
                                }
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .sheet(item: $pendingQuickMood) { trigger in
            QuickMoodEntrySheet(
                value: trigger.value,
                scale: moodContent.scale,
                colorHex: moodContent.colorHex,
                note: $quickMoodNote,
                onSaveWithNote: {
                    let trimmed = quickMoodNote.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        addMoodEntry(value: trigger.value, note: trimmed)
                    } else {
                        addMoodEntry(value: trigger.value)
                    }
                    pendingQuickMood = nil
                    quickMoodNote = ""
                },
                onJustValue: {
                    addMoodEntry(value: trigger.value)
                    pendingQuickMood = nil
                    quickMoodNote = ""
                },
                onCancel: {
                    pendingQuickMood = nil
                    quickMoodNote = ""
                }
            )
        }
    }
    
    // MARK: История записей (редактирование / удаление)
    private var historyView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Mood history card
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(Color(hex: moodContent.colorHex))
                    Text("History")
                        .font(.headline)
                    Spacer()
                    Text("\(moodContent.entries.count)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 12) {
                    ForEach(moodContent.entries.sorted(by: { $0.date > $1.date }).prefix(10)) { entry in
                        HStack(spacing: 12) {
                            Button {
                                hapticManager.selectionChanged()
                                entryToEdit = entry
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(getMoodColor(for: entry.value, scale: moodContent.scale))
                                            .frame(width: 40, height: 40)
                                        
                                        Image(systemName: getMoodSymbol(for: entry.value, scale: moodContent.scale))
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(entry.date, style: .date)
                                            .font(.subheadline.bold())
                                        
                                        if !entry.tags.isEmpty {
                                            Text(entry.tags.joined(separator: ", "))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                        
                                        if !entry.notes.isEmpty {
                                            Text(entry.notes)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    
                                    Spacer()
                                    
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
    
    // MARK: Мини-статистика по периоду
    private var statisticsView: some View {
        VStack(spacing: 16) {
            MemoStatsPeriodSegmentedPicker(selection: $selectedStatsPeriod)
            
            Text("Statistics")
                .font(.headline)
            
            HStack(spacing: 16) {
                MemoStatisticMetricCard(
                    valueScalesDown: true,
                    title: "Average",
                    value: String(format: "%.1f", filteredAverageMood),
                    icon: "chart.bar",
                    color: filteredAverageMoodColor
                )
                
                MemoStatisticMetricCard(
                    valueScalesDown: true,
                    title: "Entries",
                    value: "\(filteredEntries.count)",
                    icon: "list.bullet",
                    color: .purple
                )
            }
            
            if !filteredEntries.isEmpty {
                HStack(spacing: 16) {
                    let minMood = filteredEntries.map { $0.value }.min() ?? 0
                    MemoStatisticMetricCard(
                        valueScalesDown: true,
                        title: "Lowest",
                        value: "\(minMood)",
                        icon: "arrow.down.circle",
                        color: getMoodColor(for: minMood, scale: moodContent.scale)
                    )
                    
                    let maxMood = filteredEntries.map { $0.value }.max() ?? 0
                    MemoStatisticMetricCard(
                        valueScalesDown: true,
                        title: "Highest",
                        value: "\(maxMood)",
                        icon: "arrow.up.circle",
                        color: getMoodColor(for: maxMood, scale: moodContent.scale)
                    )
                }
                
                HStack(spacing: 16) {
                    let goodDays = filteredEntries.filter { Double($0.value) / Double(moodContent.scale) >= 0.6 }.count
                    MemoStatisticMetricCard(
                        valueScalesDown: true,
                        title: "Good days",
                        value: "\(goodDays)",
                        icon: "sun.max",
                        color: .green
                    )
                    
                    let badDays = filteredEntries.filter { Double($0.value) / Double(moodContent.scale) < 0.4 }.count
                    MemoStatisticMetricCard(
                        valueScalesDown: true,
                        title: "Bad days",
                        value: "\(badDays)",
                        icon: "cloud.rain",
                        color: .orange
                    )
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: Вычисляемые средние и цвета
    private var averageMood: Double {
        guard !moodContent.entries.isEmpty else { return 0 }
        return Double(moodContent.entries.reduce(0) { $0 + $1.value }) / Double(moodContent.entries.count)
    }
    
    private var averageMoodColor: Color {
        getMoodColor(for: Int(averageMood.rounded()), scale: moodContent.scale)
    }
    
    private var filteredAverageMood: Double {
        guard !filteredEntries.isEmpty else { return 0 }
        return Double(filteredEntries.reduce(0) { $0 + $1.value }) / Double(filteredEntries.count)
    }
    
    private var filteredAverageMoodColor: Color {
        getMoodColor(for: Int(filteredAverageMood.rounded()), scale: moodContent.scale)
    }
    
    // MARK: Загрузка, сохранение, цвет/символ по значению
    private func loadContent() {
        if let data = item.contentData,
           let content = try? JSONDecoder().decode(MemoMoodContent.self, from: data) {
            moodContent = content
            moodContent.scale = 10
        }
    }
    
    private func saveContent() {
        if let data = try? JSONEncoder().encode(moodContent) {
            item.contentData = data
            try? modelContext.save()
        }
    }
    
    private func addMoodEntry(value: Int, note: String? = nil) {
        let entry = MemoMoodContent.MoodEntry(
            date: Date(),
            value: value,
            tags: [],
            notes: note ?? ""
        )
        moodContent.entries.append(entry)
        hapticManager.playHaptic(style: .medium)
        saveContent()
    }
    
    private func deleteEntry(_ entry: MemoMoodContent.MoodEntry) {
        withAnimation {
            moodContent.entries.removeAll { $0.id == entry.id }
        }
        hapticManager.playHaptic(style: .medium)
        saveContent()
    }
    
    private func getMoodColor(for value: Int, scale: Int) -> Color {
        let ratio = Double(value) / Double(max(scale, 1))
        if ratio < 0.25 { return .red }
        else if ratio < 0.55 { return .orange }
        else if ratio < 0.75 { return .yellow }
        else { return .green }
    }
    
    private func getMoodSymbol(for value: Int, scale: Int) -> String {
        let ratio = Double(value) / Double(max(scale, 1))
        if ratio < 0.25 { return "cloud.rain.fill" }
        else if ratio < 0.55 { return "face.smiling.inverse" }
        else if ratio < 0.75 { return "face.smiling" }
        else { return "star.fill" }
    }
}

// MARK: Sheet — быстрая запись с опциональной заметкой
struct QuickMoodEntrySheet: View {
    let value: Int
    let scale: Int
    let colorHex: String
    @Binding var note: String
    let onSaveWithNote: () -> Void
    let onJustValue: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section(AppEditFormChrome.moodSectionTitle) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(getMoodColor(for: value, scale: scale))
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: getMoodSymbol(for: value, scale: scale))
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Mood: \(value)")
                                .font(.headline)
                            Text("Scale 1-\(scale)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section(AppEditFormChrome.noteSectionTitle) {
                    TextField("add a short note", text: $note)
                }
                
                Section {
                    if !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button {
                            onSaveWithNote()
                        } label: {
                            Label("Save with note", systemImage: "checkmark.circle.fill")
                        }
                    } else {
                        Button {
                            onJustValue()
                        } label: {
                            Label("Just save value", systemImage: "checkmark")
                        }
                    }
                }
            }
            .navigationTitle("New mood entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
        }
    }
}

// MARK: Sheet — правка одной записи из истории
struct MoodEntryEditSheet: View {
    let entry: MemoMoodContent.MoodEntry
    let scale: Int
    let colorHex: String
    let onSave: (MemoMoodContent.MoodEntry) -> Void
    let onCancel: () -> Void
    
    @State private var editableValue: Int
    @State private var editableNotes: String
    
    init(entry: MemoMoodContent.MoodEntry, scale: Int, colorHex: String, onSave: @escaping (MemoMoodContent.MoodEntry) -> Void, onCancel: @escaping () -> Void) {
        self.entry = entry
        self.scale = scale
        self.colorHex = colorHex
        self.onSave = onSave
        self.onCancel = onCancel
        _editableValue = State(initialValue: min(max(1, entry.value), scale))
        _editableNotes = State(initialValue: entry.notes)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(AppEditFormChrome.moodSectionTitle) {
                    Picker("Value", selection: $editableValue) {
                        ForEach(1...max(1, scale), id: \.self) { value in
                            HStack(spacing: 8) {
                                Image(systemName: moodSymbol(for: value))
                                    .foregroundColor(getMoodColor(for: value, scale: scale))
                                Text("\(value)")
                            }
                            .tag(value)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section(AppEditFormChrome.noteSectionTitle) {
                    TextEditor(text: $editableNotes)
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
                        let updated = MemoMoodContent.MoodEntry(
                            id: entry.id,
                            date: entry.date,
                            value: editableValue,
                            tags: entry.tags,
                            notes: editableNotes
                        )
                        onSave(updated)
                    }
                }
            }
        }
    }
    
    private func moodSymbol(for value: Int) -> String {
        let ratio = Double(value) / Double(max(scale, 1))
        if ratio < 0.25 { return "cloud.rain.fill" }
        else if ratio < 0.55 { return "face.smiling.inverse" }
        else if ratio < 0.75 { return "face.smiling" }
        else { return "star.fill" }
    }
}

// MARK: Sheet — заметки и оформление трекера
struct MoodEditorSheet: View {
    @Binding var moodContent: MemoMoodContent
    let onSave: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section(AppEditFormChrome.additionalSectionTitle) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        TextEditor(text: $moodContent.notes)
                            .frame(minHeight: 100)
                    }
                }
                
                Section(AppEditFormChrome.appearanceSectionTitle) {
                    MediaCirclePicker(
                        config: MediaCirclePickerConfiguration(
                            dialogTitle: "Mood media",
                            tintHex: moodContent.colorHex,
                            size: 72,
                            fallbackIconName: "face.smiling"
                        ),
                        imageData: $moodContent.customImageData,
                        iconName: Binding(
                            get: { Optional(moodContent.iconName) },
                            set: { newValue in
                                if let newValue { moodContent.iconName = newValue }
                            }
                        )
                    )
                    
                    ColorPicker("Color", selection: Binding(
                        get: { Color(hex: moodContent.colorHex) },
                        set: { moodContent.colorHex = $0.toHex() ?? "#FF2D55" }
                    ))
                }
            }
            .navigationTitle("Edit mood tracker")
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

// MARK: Общие хелперы цвета и иконки по шкале
func getMoodColor(for value: Int, scale: Int) -> Color {
    let ratio = Double(value) / Double(max(scale, 1))
    if ratio < 0.25 { return .red }
    else if ratio < 0.55 { return .orange }
    else if ratio < 0.75 { return .yellow }
    else { return .green }
}

func getMoodSymbol(for value: Int, scale: Int) -> String {
    let ratio = Double(value) / Double(max(scale, 1))
    if ratio < 0.25 { return "cloud.rain.fill" }
    else if ratio < 0.55 { return "face.smiling.inverse" }
    else if ratio < 0.75 { return "face.smiling" }
    else { return "star.fill" }
}
