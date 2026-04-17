import SwiftUI
import SwiftData

// Presentation · Memo — тип «стрик»: серии выполнений, календарь отметок.
// Оглавление: модель → экран → шапка/кнопка/статы/цель/заметки/история/календарь/стат → карточка и sheet’ы.

// MARK: Модель данных streak-мемо
struct MemoStreakContent: Codable, Hashable {
    var currentStreak: Int = 0
    var bestStreak: Int = 0
    var targetStreak: Int? = nil
    var goal: String = ""
    var notes: String = ""
    var checkHistory: [StreakCheckEntry] = []
    var iconName: String = "flame.fill"
    var customImageData: Data? = nil
    var colorHex: String = "#FF3B30" // default red
    var sphereID: UUID? = nil
    var positiveImpact: Double = 0.0
    var negativeImpact: Double = 0.0
    var additionalImpacts: [SphereImpact] = []
    
    struct StreakCheckEntry: Codable, Hashable, Identifiable {
        var id: UUID = UUID()
        var date: Date
        var note: String = ""
    }
    
    /// Пересчёт текущего и лучшего стрика по истории отметок.
    /// Правило автосброса: стрик считается только если последняя отметка — сегодня или вчера;
    /// иначе текущий стрик = 0 (наступил следующий день после дня без отметки).
    /// Восстановление: если пользователь в календаре отметит пропущенный день, пересчёт восстановит стрик.
    static func recalculateStreakValues(history: [StreakCheckEntry], existingBest: Int) -> (current: Int, best: Int) {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let uniqueDays = Set(history.map { calendar.startOfDay(for: $0.date) })
        let sortedDays = uniqueDays.sorted(by: >)
        
        guard let mostRecent = sortedDays.first else { return (0, existingBest) }
        
        let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart
        let allowedStart = mostRecent == todayStart || mostRecent == yesterdayStart
        guard allowedStart else {
            return (0, existingBest)
        }
        
        var current = 0
        var cursor = mostRecent
        while uniqueDays.contains(cursor) {
            current += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        
        let best = max(existingBest, current)
        return (current, best)
    }
}

// MARK: Главный экран streak-мемо
struct StreakContentView: View {
    let item: MemoItem
    @Binding var showStreakStatistics: Bool
    
    @Environment(\.modelContext) private var modelContext
    @State private var streakContent: MemoStreakContent = MemoStreakContent()
    @State private var showEditSheet = false
    @State private var alertField: EditingField? = nil
    @State private var fieldEditText: String = ""
    @State private var selectedStatsPeriod: MemoStatsPeriod = .month
    @State private var entryToDelete: MemoStreakContent.StreakCheckEntry? = nil
    @State private var entryToEdit: MemoStreakContent.StreakCheckEntry? = nil
    @State private var circlePulseScale: CGFloat = 1.0
    @State private var flamePulseTrigger = UUID()
    @State private var calendarSelectedDate: Date = Calendar.current.startOfDay(for: Date())
    
    private let hapticManager = HapticSoundManager.shared
    
    private var filteredCheckHistory: [MemoStreakContent.StreakCheckEntry] {
        guard let start = selectedStatsPeriod.startDate() else {
            return streakContent.checkHistory
        }
        return streakContent.checkHistory.filter { $0.date >= start }
    }
    
    enum EditingField {
        case goal, notes
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    // Main Streak Header
                    streakCircleView
                    
                    // Check Today Button
                    checkTodayButton
                    
                    // Streak Stats
                    streakStatsView
                    
                    if let targetDays = goalTargetDays {
                        streakProgressView(target: targetDays)
                    }
                    
                    // Goal (custom text, when targetStreak not used)
                    if !streakContent.goal.isEmpty && streakContent.targetStreak == nil {
                        goalView
                    }
                    
                    if streakContent.currentStreak > 0 {
                        currentStreakSummaryView
                    }
                    
                    if streakContent.bestStreak > 0 {
                        bestStreakSummaryView
                    }
                    
                    // Notes
                    if !streakContent.notes.isEmpty {
                        notesView
                    }
                    
                    // Calendar: mark past day to restore streak
                    streakCalendarSection
                    
                    // History
                    if !streakContent.checkHistory.isEmpty {
                        historyView
                    }
                }
                .padding(.horizontal)
                .padding(.top, 4)
                .padding(.bottom, 16)
            }
        }
        .onAppear {
            loadStreak()
            checkAndResetStreak()
            flamePulseTrigger = UUID()
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
        .sheet(isPresented: $showEditSheet) {
            StreakEditorSheet(streakContent: $streakContent, onSave: {
                saveStreak()
            })
        }
        .fullScreenCover(isPresented: $showStreakStatistics) {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 16) {
                        statisticsView
                        if !filteredCheckHistory.isEmpty {
                            let chartData = filteredCheckHistory
                                .sorted(by: { $0.date < $1.date })
                                .enumerated()
                                .map { index, entry in
                                    ChartDataPoint(date: entry.date, value: Double(index + 1))
                                }
                            ChartView(
                                data: chartData,
                                title: "Streak progress",
                                color: Color(hex: streakContent.colorHex),
                                unit: "days"
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
                            showStreakStatistics = false
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
            title: "Delete check entry?",
            message: "This action cannot be undone.",
            onConfirm: {
                if let entry = entryToDelete {
                    deleteHistoryEntry(entry)
                    entryToDelete = nil
                }
            }
        )
        .sheet(item: $entryToEdit) { entry in
            StreakEntryEditSheet(
                entry: entry,
                colorHex: streakContent.colorHex,
                onSave: { updated in
                    if let idx = streakContent.checkHistory.firstIndex(where: { $0.id == updated.id }) {
                        streakContent.checkHistory[idx] = updated
                        recalculateStreak()
                        saveStreak()
                    }
                    entryToEdit = nil
                },
                onCancel: {
                    entryToEdit = nil
                }
            )
        }
    }
    
    // MARK: Шапка — иконка, стрик, календарь
    private var streakCircleView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                if let imageData = streakContent.customImageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .clipShape(Circle())
                } else {
                    Image(systemName: streakContent.iconName)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(Color(hex: streakContent.colorHex))
                        .symbolEffect(.pulse, options: .nonRepeating, value: flamePulseTrigger)
                }
                
                Text("\(streakContent.currentStreak) \(streakContent.currentStreak == 1 ? "day" : "days")")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color(hex: streakContent.colorHex))
                
                Spacer()
            }
            .padding()
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(hex: streakContent.colorHex).opacity(0.16))
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .scaleEffect(circlePulseScale)
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onLongPressGesture(minimumDuration: 1.5, maximumDistance: 50) {
            guard !isCheckedToday else { return }
            checkToday()
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
    
    // MARK: Кнопка «отметить сегодня»
    private var checkTodayButton: some View {
        Button {
            if isCheckedToday {
                uncheckToday()
            } else {
                checkToday()
            }
        } label: {
            HStack {
                Image(systemName: isCheckedToday ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                Text(isCheckedToday ? "Checked today" : "Check today")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(isCheckedToday ? Color.green.opacity(0.2) : Color(hex: streakContent.colorHex).opacity(0.2))
            .foregroundColor(isCheckedToday ? .green : Color(hex: streakContent.colorHex))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: Блок чисел (текущий / лучший / цель)
    private var streakStatsView: some View {
        HStack(spacing: 16) {
            VStack {
                Text("\(streakContent.bestStreak)")
                    .font(.title2.bold())
                    .foregroundColor(.orange)
                Text("Best")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack {
                Group {
                    if streakContent.currentStreak > 0 {
                        if let imageData = streakContent.customImageData,
                           let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: streakContent.iconName)
                                .font(.title2)
                                .foregroundColor(Color(hex: streakContent.colorHex))
                        }
                    } else {
                        Image(systemName: "snowflake")
                            .font(.title2)
                            .foregroundColor(.blue.opacity(0.8))
                    }
                }
                Text(streakContent.currentStreak > 0 ? "Active" : "Inactive")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack {
                Text("\(daysSinceLastCheck)")
                    .font(.title2.bold())
                    .foregroundColor(daysSinceLastCheck == 0 ? .green : .orange)
                Text("Last")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: Текст цели стрика
    private var goalView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "target")
                    .foregroundColor(Color(hex: streakContent.colorHex))
                Text("Goal")
                    .font(.headline)
            }
            
            Text(streakContent.goal)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture(count: 2) {
            startEditing(.goal)
        }
    }
    
    // MARK: Заметки
    private var notesView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "note.text")
                    .foregroundColor(Color(hex: streakContent.colorHex))
                Text("Notes")
                    .font(.headline)
            }
            
            Text(streakContent.notes)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture(count: 2) {
            startEditing(.notes)
        }
    }
    
    private var currentStreakSummaryView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(Color(hex: streakContent.colorHex))
                Text("Current streak")
                    .font(.headline)
            }
            
            Text("\(streakContent.currentStreak) \(streakContent.currentStreak == 1 ? "day" : "days")")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var bestStreakSummaryView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundColor(.orange)
                Text("Best streak")
                    .font(.headline)
            }
            
            Text("\(streakContent.bestStreak) \(streakContent.bestStreak == 1 ? "day" : "days")")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: История отметок
    private var historyView: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(Color(hex: streakContent.colorHex))
                    Text("History")
                        .font(.headline)
                    Spacer()
                    Text("\(streakContent.checkHistory.count)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 12) {
                    ForEach(streakContent.checkHistory.sorted(by: { $0.date > $1.date }).prefix(10)) { entry in
                        HStack(spacing: 12) {
                            Button {
                                hapticManager.selectionChanged()
                                entryToEdit = entry
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(entry.date, style: .date)
                                            .font(.subheadline.bold())
                                        if !entry.note.isEmpty {
                                            Text(entry.note)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
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
    
    // MARK: Календарь — досрочная отметка / восстановление
    private var streakCalendarSection: some View {
        let calendar = Calendar.current
        let selectedDayStart = calendar.startOfDay(for: calendarSelectedDate)
        let isCheckedOnSelectedDay = streakContent.checkHistory.contains { calendar.isDate($0.date, inSameDayAs: selectedDayStart) }
        let isFuture = selectedDayStart > calendar.startOfDay(for: Date())
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(Color(hex: streakContent.colorHex))
                Text("Mark past day")
                    .font(.headline)
            }
            
            DatePicker("Day", selection: $calendarSelectedDate, in: ...Date(), displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
            
            if !isFuture {
                Button {
                    toggleCheck(for: selectedDayStart)
                } label: {
                    HStack {
                        Image(systemName: isCheckedOnSelectedDay ? "checkmark.circle.fill" : "plus.circle.fill")
                        Text(isCheckedOnSelectedDay ? "Unmark this day" : "Mark this day")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(isCheckedOnSelectedDay ? Color.red.opacity(0.15) : Color(hex: streakContent.colorHex).opacity(0.2))
                    .foregroundColor(isCheckedOnSelectedDay ? .red : Color(hex: streakContent.colorHex))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func toggleCheck(for dayStart: Date) {
        let calendar = Calendar.current
        if let existing = streakContent.checkHistory.first(where: { calendar.isDate($0.date, inSameDayAs: dayStart) }) {
            streakContent.checkHistory.removeAll { $0.id == existing.id }
        } else {
            streakContent.checkHistory.append(MemoStreakContent.StreakCheckEntry(date: dayStart, note: ""))
        }
        recalculateStreak()
        hapticManager.playHaptic(style: .medium)
        saveStreak()
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
                    value: "\(streakContent.currentStreak)",
                    icon: "flame.fill",
                    color: Color(hex: streakContent.colorHex)
                )
                
                MemoStatisticMetricCard(
                    title: "Best",
                    value: "\(streakContent.bestStreak)",
                    icon: "trophy.fill",
                    color: .orange
                )
            }
            
            HStack(spacing: 16) {
                MemoStatisticMetricCard(
                    title: "Total",
                    value: "\(totalCheckedDays)",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
                
                MemoStatisticMetricCard(
                    title: "Days",
                    value: "\(totalDaysSinceCreation)",
                    icon: "calendar",
                    color: .blue
                )
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: Вычисляемые свойства (даты, фильтры)
    private var isCheckedToday: Bool {
        let today = Calendar.current.startOfDay(for: Date())
        return streakContent.checkHistory.contains { Calendar.current.isDate($0.date, inSameDayAs: today) }
    }
    
    /// Полных календарных дней с последней отметки до сегодня (0 = сегодня, 1 = вчера, 2+ = стрик сброшен на следующий день).
    private var daysSinceLastCheck: Int {
        guard let lastCheck = streakContent.checkHistory.map(\.date).max(by: { $0 < $1 }) else { return 0 }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: calendar.startOfDay(for: lastCheck), to: calendar.startOfDay(for: Date()))
        return max(0, components.day ?? 0)
    }
    
    private var goalTargetDays: Int? {
        if let target = streakContent.targetStreak, target > 0 { return target }
        let digits = streakContent.goal.compactMap { $0.wholeNumberValue }
        guard !digits.isEmpty else { return nil }
        let value = digits.reduce(0) { $0 * 10 + $1 }
        return value > 0 ? value : nil
    }
    
    private var totalDaysSinceCreation: Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: item.creationDate)
        let end = calendar.startOfDay(for: Date())
        let components = calendar.dateComponents([.day], from: start, to: end)
        return max(1, (components.day ?? 0) + 1)
    }
    
    /// Unique calendar days marked as completed (checked) within the selected period
    private var totalCheckedDays: Int {
        let calendar = Calendar.current
        let uniqueDays = Set(filteredCheckHistory.map { calendar.startOfDay(for: $0.date) })
        return uniqueDays.count
    }
    
    // MARK: Сохранение и обновление контента
    private func loadStreak() {
        if let data = item.contentData,
           var content = try? JSONDecoder().decode(MemoStreakContent.self, from: data) {
            if content.targetStreak == nil {
                let digits = content.goal.compactMap { $0.wholeNumberValue }
                if !digits.isEmpty {
                    let value = digits.reduce(0) { $0 * 10 + $1 }
                    if value > 0 { content.targetStreak = value }
                }
            }
            streakContent = content
        }
    }
    
    private func saveStreak() {
        if let data = try? JSONEncoder().encode(streakContent) {
            item.contentData = data
            try? modelContext.save()
        }
    }
    
    private func checkToday() {
        guard !isCheckedToday else { return }
        
        withAnimation {
            let entry = MemoStreakContent.StreakCheckEntry(date: Date(), note: "")
            streakContent.checkHistory.append(entry)
            recalculateStreak()
        }
        
        hapticManager.playHaptic(style: .medium)
        hapticManager.playSound(soundName: "sound_complete", fileType: "wav")
        saveStreak()
    }
    
    private func uncheckToday() {
        let today = Calendar.current.startOfDay(for: Date())
        guard let entry = streakContent.checkHistory.first(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) else { return }
        deleteHistoryEntry(entry)
    }
    
    /// Автосброс: наступил следующий день после дня без отметки — текущий стрик обнуляется.
    /// Восстановление стрика: отметка за прошлый день в календаре пересчитает стрик.
    private func checkAndResetStreak() {
        let daysSince = daysSinceLastCheck
        if daysSince > 1 {
            withAnimation {
                streakContent.currentStreak = 0
            }
            saveStreak()
        } else {
            recalculateStreak()
            saveStreak()
        }
    }
    
    private func streakProgressView(target: Int) -> some View {
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(Color(hex: streakContent.colorHex))
                        .font(.subheadline)
                    Text("Progress to target")
                        .font(.headline)
                }
                Spacer()
                Text("\(streakContent.currentStreak) / \(target)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 12)
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: streakContent.colorHex))
                        .frame(
                            width: geometry.size.width * min(CGFloat(streakContent.currentStreak) / CGFloat(max(target, 1)), 1.0),
                            height: 12
                        )
                }
            }
            .frame(height: 12)
            
            let percent = target > 0 ? Int(Double(streakContent.currentStreak) / Double(target) * 100) : 0
            Text("\(percent)%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func deleteHistoryEntry(_ entry: MemoStreakContent.StreakCheckEntry) {
        withAnimation {
            streakContent.checkHistory.removeAll { $0.id == entry.id }
            // Recalculate current streak
            recalculateStreak()
        }
        hapticManager.playHaptic(style: .medium)
        saveStreak()
    }
    
    private func recalculateStreak() {
        let (current, best) = MemoStreakContent.recalculateStreakValues(history: streakContent.checkHistory, existingBest: streakContent.bestStreak)
        streakContent.currentStreak = current
        streakContent.bestStreak = best
    }
    
    private func startEditing(_ field: EditingField) {
        switch field {
        case .goal:
            fieldEditText = streakContent.goal
        case .notes:
            fieldEditText = streakContent.notes
        }
        alertField = field
    }
    
    private func saveEditedField(_ field: EditingField, text: String) {
        switch field {
        case .goal:
            streakContent.goal = text
        case .notes:
            streakContent.notes = text
        }
        hapticManager.playHaptic(style: .light)
        saveStreak()
    }
    
    private func fieldTitle(for field: EditingField) -> String {
        switch field {
        case .goal: return "Goal"
        case .notes: return "Notes"
        }
    }
    
    private func fieldPlaceholder(for field: EditingField) -> String {
        switch field {
        case .goal: return "What's your goal?"
        case .notes: return "Additional information"
        }
    }
}

// MARK: Sheet — правка записи истории
struct StreakEntryEditSheet: View {
    let entry: MemoStreakContent.StreakCheckEntry
    let colorHex: String
    let onSave: (MemoStreakContent.StreakCheckEntry) -> Void
    let onCancel: () -> Void
    
    @State private var editableNote: String
    
    init(entry: MemoStreakContent.StreakCheckEntry, colorHex: String, onSave: @escaping (MemoStreakContent.StreakCheckEntry) -> Void, onCancel: @escaping () -> Void) {
        self.entry = entry
        self.colorHex = colorHex
        self.onSave = onSave
        self.onCancel = onCancel
        _editableNote = State(initialValue: entry.note)
    }
    
    var body: some View {
        NavigationStack {
            Form {
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
                        let updated = MemoStreakContent.StreakCheckEntry(
                            id: entry.id,
                            date: entry.date,
                            note: editableNote
                        )
                        onSave(updated)
                    }
                }
            }
        }
    }
}

// MARK: Sheet — настройки streak-мемо
struct StreakEditorSheet: View {
    @Binding var streakContent: MemoStreakContent
    let onSave: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section(AppEditFormChrome.generalSectionTitle) {
                    HStack {
                        Text("Current streak")
                        Spacer()
                        Text("\(streakContent.currentStreak) \(streakContent.currentStreak == 1 ? "day" : "days")")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Best streak")
                        Spacer()
                        Text("\(streakContent.bestStreak) \(streakContent.bestStreak == 1 ? "day" : "days")")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(AppEditFormChrome.goalAndNotesSectionTitle) {
                    HStack {
                        Text("Target streak")
                        Spacer()
                        TextField("None", value: Binding(
                            get: { streakContent.targetStreak },
                            set: { newValue in
                                if let v = newValue, v > 0 {
                                    streakContent.targetStreak = v
                                } else {
                                    streakContent.targetStreak = nil
                                }
                            }
                        ), format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        TextEditor(text: $streakContent.notes)
                            .frame(minHeight: 100)
                    }
                }
                
                Section(AppEditFormChrome.appearanceSectionTitle) {
                    MediaCirclePicker(
                        config: MediaCirclePickerConfiguration(
                            dialogTitle: "Streak media",
                            tintHex: streakContent.colorHex,
                            size: 72,
                            fallbackIconName: "flame.fill"
                        ),
                        imageData: $streakContent.customImageData,
                        iconName: Binding(
                            get: { Optional(streakContent.iconName) },
                            set: { newValue in
                                if let newValue { streakContent.iconName = newValue }
                            }
                        )
                    )
                    
                    ColorPicker("Color", selection: Binding(
                        get: { Color(hex: streakContent.colorHex) },
                        set: { streakContent.colorHex = $0.toHex() ?? "#FF3B30" }
                    ))
                }
            }
            .navigationTitle("Edit Streak")
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
