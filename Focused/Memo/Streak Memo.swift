import SwiftUI
import SwiftData

// MARK: - Streak Content Model
struct MemoStreakContent: Codable, Hashable {
    var currentStreak: Int = 0
    var bestStreak: Int = 0
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
}

// MARK: - Streak Content View
struct StreakContentView: View {
    let item: MemoItem
    @Binding var showStreakStatistics: Bool
    
    @Environment(\.modelContext) private var modelContext
    @State private var streakContent: MemoStreakContent = MemoStreakContent()
    @State private var showEditSheet = false
    @State private var editingField: EditingField? = nil
    @State private var editedText: String = ""
    @State private var showIconPicker = false
    
    private let hapticManager = HapticSoundManager.shared
    
    enum EditingField {
        case goal, notes
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Statistics View
            if showStreakStatistics {
                statisticsView
                    .padding()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            ScrollView {
                VStack(spacing: 24) {
                    // Main Streak Circle
                    streakCircleView
                        .padding(.top)
                    
                    // Check Today Button
                    checkTodayButton
                    
                    // Streak Stats
                    streakStatsView
                    
                    // Goal
                    if !streakContent.goal.isEmpty {
                        goalView
                    }
                    
                    // Notes
                    if !streakContent.notes.isEmpty {
                        notesView
                    }
                    
                    // History
                    if !streakContent.checkHistory.isEmpty {
                        historyView
                    }
                }
                .padding()
            }
        }
        .onAppear {
            loadStreak()
            checkAndResetStreak()
        }
        .sheet(isPresented: $showEditSheet) {
            StreakEditorSheet(streakContent: $streakContent, onSave: {
                saveStreak()
            })
        }
        .sheet(isPresented: $showIconPicker) {
            IconPickerView(
                selectedIcon: Binding(
                    get: { streakContent.iconName },
                    set: { newIcon in
                        streakContent.iconName = newIcon
                        saveStreak()
                    }
                ),
                isPresented: $showIconPicker
            )
        }
    }
    
    // MARK: - Streak Circle View
    private var streakCircleView: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: streakContent.colorHex).opacity(0.2))
                    .frame(width: 150, height: 150)
                
                VStack(spacing: 8) {
                    // Icon
                    if let imageData = streakContent.customImageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: streakContent.iconName)
                            .font(.system(size: 32))
                            .foregroundColor(Color(hex: streakContent.colorHex))
                            .symbolEffect(.pulse, options: streakContent.currentStreak > 0 ? .repeating : .default)
                    }
                    
                    // Current Streak
                    Text("\(streakContent.currentStreak)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("дней")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .contextMenu {
                Button {
                    showIconPicker = true
                } label: {
                    Label("Изменить иконку", systemImage: "photo")
                }
                
                Button {
                    showEditSheet = true
                } label: {
                    Label("Редактировать", systemImage: "pencil")
                }
            }
        }
    }
    
    // MARK: - Check Today Button
    private var checkTodayButton: some View {
        Button {
            checkToday()
        } label: {
            HStack {
                Image(systemName: isCheckedToday ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                Text(isCheckedToday ? "Отмечено сегодня" : "Отметить сегодня")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isCheckedToday ? Color.green.opacity(0.2) : Color(hex: streakContent.colorHex).opacity(0.2))
            .foregroundColor(isCheckedToday ? .green : Color(hex: streakContent.colorHex))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(isCheckedToday)
    }
    
    // MARK: - Streak Stats
    private var streakStatsView: some View {
        HStack(spacing: 16) {
            VStack {
                Text("\(streakContent.bestStreak)")
                    .font(.title2.bold())
                    .foregroundColor(.orange)
                Text("Лучший")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack {
                Text(streakContent.currentStreak > 0 ? "🔥" : "❄️")
                    .font(.title2)
                Text(streakContent.currentStreak > 0 ? "Активен" : "Не активен")
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
                Text("Последний")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Goal View
    private var goalView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "target")
                    .foregroundColor(.blue)
                Text("Цель")
                    .font(.headline)
            }
            
            Text(streakContent.goal)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .onTapGesture(count: 2) {
                    startEditing(.goal)
                }
        }
    }
    
    // MARK: - Notes View
    private var notesView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "note.text")
                    .foregroundColor(.secondary)
                Text("Заметки")
                    .font(.headline)
            }
            
            Text(streakContent.notes)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .onTapGesture(count: 2) {
                    startEditing(.notes)
                }
        }
    }
    
    // MARK: - History View
    private var historyView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(Color(hex: streakContent.colorHex))
                Text("История отметок")
                    .font(.headline)
                Spacer()
                Text("\(streakContent.checkHistory.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ForEach(streakContent.checkHistory.sorted(by: { $0.date > $1.date }).prefix(10)) { entry in
                HStack {
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
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        deleteHistoryEntry(entry)
                    } label: {
                        Label("Удалить", systemImage: "trash")
                    }
                }
            }
        }
    }
    
    // MARK: - Statistics View
    private var statisticsView: some View {
        VStack(spacing: 16) {
            Text("Статистика")
                .font(.headline)
            
            HStack(spacing: 16) {
                StreakStatisticCard(
                    title: "Текущий",
                    value: "\(streakContent.currentStreak)",
                    icon: "flame.fill",
                    color: Color(hex: streakContent.colorHex)
                )
                
                StreakStatisticCard(
                    title: "Лучший",
                    value: "\(streakContent.bestStreak)",
                    icon: "trophy.fill",
                    color: .orange
                )
            }
            
            HStack(spacing: 16) {
                StreakStatisticCard(
                    title: "Всего",
                    value: "\(streakContent.checkHistory.count)",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
                
                StreakStatisticCard(
                    title: "Активность",
                    value: streakContent.currentStreak > 0 ? "🔥" : "❄️",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .blue
                )
            }
            
            // Chart
            if !streakContent.checkHistory.isEmpty {
                let chartData = streakContent.checkHistory
                    .sorted(by: { $0.date < $1.date })
                    .suffix(30)
                    .enumerated()
                    .map { index, entry in
                        ChartDataPoint(date: entry.date, value: Double(index + 1))
                    }
                
                ChartView(
                    data: chartData,
                    title: "Прогресс стрика",
                    color: Color(hex: streakContent.colorHex),
                    unit: "дней"
                )
                .frame(height: 200)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Helper Computed Properties
    private var isCheckedToday: Bool {
        guard let lastCheck = streakContent.checkHistory.last?.date else { return false }
        return Calendar.current.isDateInToday(lastCheck)
    }
    
    private var daysSinceLastCheck: Int {
        guard let lastCheck = streakContent.checkHistory.last?.date else { return -1 }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: calendar.startOfDay(for: lastCheck), to: calendar.startOfDay(for: Date()))
        return components.day ?? 0
    }
    
    // MARK: - Helper Methods
    private func loadStreak() {
        if let data = item.contentData,
           let content = try? JSONDecoder().decode(MemoStreakContent.self, from: data) {
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
            // Add entry
            let entry = MemoStreakContent.StreakCheckEntry(date: Date(), note: "")
            streakContent.checkHistory.append(entry)
            
            // Update streak
            streakContent.currentStreak += 1
            streakContent.bestStreak = max(streakContent.bestStreak, streakContent.currentStreak)
        }
        
        hapticManager.playHaptic(style: .medium)
        hapticManager.playSound(soundName: "sound_complete", fileType: "wav")
        saveStreak()
    }
    
    private func checkAndResetStreak() {
        let daysSince = daysSinceLastCheck
        
        // If more than 1 day passed, reset streak
        if daysSince > 1 {
            withAnimation {
                streakContent.currentStreak = 0
            }
            saveStreak()
        }
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
        // Recalculate streak based on remaining history
        let sortedHistory = streakContent.checkHistory.sorted(by: { $0.date > $1.date })
        var currentStreak = 0
        var previousDate: Date?
        
        for entry in sortedHistory {
            if let prev = previousDate {
                let calendar = Calendar.current
                let components = calendar.dateComponents([.day], from: calendar.startOfDay(for: entry.date), to: calendar.startOfDay(for: prev))
                if let days = components.day, days == 1 {
                    currentStreak += 1
                } else {
                    break
                }
            } else {
                if Calendar.current.isDateInToday(entry.date) || Calendar.current.isDateInYesterday(entry.date) {
                    currentStreak = 1
                } else {
                    break
                }
            }
            previousDate = entry.date
        }
        
        streakContent.currentStreak = currentStreak
    }
    
    private func startEditing(_ field: EditingField) {
        editingField = field
        switch field {
        case .goal:
            editedText = streakContent.goal
        case .notes:
            editedText = streakContent.notes
        }
        
        // Show alert for inline editing
        let alert = UIAlertController(title: fieldTitle(for: field), message: nil, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.text = editedText
            textField.placeholder = fieldPlaceholder(for: field)
        }
        
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Сохранить", style: .default) { _ in
            if let text = alert.textFields?.first?.text {
                saveEditedField(field, text: text)
            }
        })
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alert, animated: true)
        }
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
        case .goal: return "Цель"
        case .notes: return "Заметки"
        }
    }
    
    private func fieldPlaceholder(for field: EditingField) -> String {
        switch field {
        case .goal: return "Какая ваша цель?"
        case .notes: return "Дополнительная информация"
        }
    }
}

// MARK: - Streak Statistic Card
struct StreakStatisticCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3.bold())
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Streak Editor Sheet
struct StreakEditorSheet: View {
    @Binding var streakContent: MemoStreakContent
    let onSave: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var showIconPicker = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Основное") {
                    HStack {
                        Text("Текущий стрик")
                        Spacer()
                        Text("\(streakContent.currentStreak) дней")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Лучший стрик")
                        Spacer()
                        Text("\(streakContent.bestStreak) дней")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Цель и заметки") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Цель")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        TextField("Какая ваша цель?", text: $streakContent.goal)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Заметки")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        TextEditor(text: $streakContent.notes)
                            .frame(minHeight: 100)
                    }
                }
                
                Section("Внешний вид") {
                    Button {
                        showIconPicker = true
                    } label: {
                        HStack {
                            Text("Иконка")
                            Spacer()
                            if let imageData = streakContent.customImageData,
                               let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24, height: 24)
                            } else {
                                Image(systemName: streakContent.iconName)
                                    .foregroundColor(Color(hex: streakContent.colorHex))
                            }
                        }
                    }
                    
                    ColorPicker("Цвет", selection: Binding(
                        get: { Color(hex: streakContent.colorHex) },
                        set: { streakContent.colorHex = $0.toHex() ?? "#FF3B30" }
                    ))
                }
            }
            .navigationTitle("Редактировать стрик")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        onSave()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showIconPicker) {
                IconPickerView(
                    selectedIcon: $streakContent.iconName,
                    isPresented: $showIconPicker
                )
            }
        }
    }
}
