import SwiftUI
import SwiftData

// MARK: - Counter Content Model
struct MemoCounterContent: Codable, Hashable {
    var currentValue: Int = 0
    var targetValue: Int?
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
        var value: Int
        var note: String = ""
    }
}

// MARK: - Sphere Impact Model (for multiple sphere impacts)
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

// MARK: - Counter Content View
struct CounterContentView: View {
    let item: MemoItem
    @Binding var showCounterStatistics: Bool
    
    @Environment(\.modelContext) private var modelContext
    @State private var counterContent: MemoCounterContent = MemoCounterContent()
    @State private var showEditSheet = false
    @State private var editingField: EditingField? = nil
    @State private var editedText: String = ""
    @State private var showIconPicker = false
    @State private var showValueEditor = false
    
    private let hapticManager = HapticSoundManager.shared
    
    enum EditingField {
        case currentValue, targetValue, unit, notes
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Statistics View
            if showCounterStatistics {
                statisticsView
                    .padding()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            ScrollView {
                VStack(spacing: 24) {
                    // Main Counter Circle
                    counterCircleView
                        .padding(.top)
                    
                    // Control Buttons
                    controlButtonsView
                    
                    // Progress to Target
                    if let target = counterContent.targetValue, target > 0 {
                        progressView(target: target)
                    }
                    
                    // Notes
                    if !counterContent.notes.isEmpty {
                        notesView
                    }
                    
                    // History
                    if !counterContent.history.isEmpty {
                        historyView
                    }
                }
                .padding()
            }
        }
        .onAppear {
            loadCounter()
        }
        .sheet(isPresented: $showEditSheet) {
            CounterEditorSheet(counterContent: $counterContent, onSave: {
                saveCounter()
            })
        }
        .sheet(isPresented: $showIconPicker) {
            IconPickerView(
                selectedIcon: Binding(
                    get: { counterContent.iconName },
                    set: { newIcon in
                        counterContent.iconName = newIcon
                        saveCounter()
                    }
                ),
                isPresented: $showIconPicker
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
    
    // MARK: - Counter Circle View
    private var counterCircleView: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: counterContent.colorHex).opacity(0.2))
                    .frame(width: 150, height: 150)
                
                VStack(spacing: 8) {
                    // Icon
                    if let imageData = counterContent.customImageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: counterContent.iconName)
                            .font(.system(size: 32))
                            .foregroundColor(Color(hex: counterContent.colorHex))
                    }
                    
                    // Value
                    Text("\(counterContent.currentValue)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.primary)
                        .onTapGesture(count: 2) {
                            showValueEditor = true
                        }
                    
                    // Unit
                    if !counterContent.unit.isEmpty {
                        Text(counterContent.unit)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .onTapGesture(count: 2) {
                                startEditing(.unit)
                            }
                    }
                }
            }
            .onLongPressGesture(minimumDuration: 0.3) {
                incrementCounter()
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
    
    // MARK: - Control Buttons
    private var controlButtonsView: some View {
        HStack(spacing: 20) {
            // Decrement Button
            Button {
                decrementCounter()
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(Color(hex: counterContent.colorHex))
            }
            
            Spacer()
            
            // Increment Button
            Button {
                incrementCounter()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(Color(hex: counterContent.colorHex))
            }
        }
        .padding(.horizontal, 40)
    }
    
    // MARK: - Progress View
    private func progressView(target: Int) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("Прогресс к цели")
                    .font(.headline)
                Spacer()
                Text("\(counterContent.currentValue) / \(target)")
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
                            width: geometry.size.width * min(CGFloat(counterContent.currentValue) / CGFloat(target), 1.0),
                            height: 12
                        )
                }
            }
            .frame(height: 12)
            
            // Percentage
            Text("\(Int(Double(counterContent.currentValue) / Double(target) * 100))%")
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
    
    // MARK: - Notes View
    private var notesView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "note.text")
                    .foregroundColor(.secondary)
                Text("Заметки")
                    .font(.headline)
            }
            
            Text(counterContent.notes)
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
                    .foregroundColor(Color(hex: counterContent.colorHex))
                Text("История изменений")
                    .font(.headline)
                Spacer()
                Text("\(counterContent.history.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ForEach(counterContent.history.sorted(by: { $0.date > $1.date }).prefix(10)) { entry in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(entry.value) \(counterContent.unit)")
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
                CounterStatisticCard(
                    title: "Текущее",
                    value: "\(counterContent.currentValue)",
                    icon: "number.circle",
                    color: Color(hex: counterContent.colorHex)
                )
                
                if let target = counterContent.targetValue {
                    CounterStatisticCard(
                        title: "Цель",
                        value: "\(target)",
                        icon: "flag.fill",
                        color: .green
                    )
                }
            }
            
            HStack(spacing: 16) {
                if let min = counterContent.history.map({ $0.value }).min() {
                    CounterStatisticCard(
                        title: "Минимум",
                        value: "\(min)",
                        icon: "arrow.down.circle",
                        color: .blue
                    )
                }
                
                if let max = counterContent.history.map({ $0.value }).max() {
                    CounterStatisticCard(
                        title: "Максимум",
                        value: "\(max)",
                        icon: "arrow.up.circle",
                        color: .orange
                    )
                }
            }
            
            // Chart
            if !counterContent.history.isEmpty {
                ChartView(
                    data: counterContent.history.map { ChartDataPoint(date: $0.date, value: Double($0.value)) },
                    title: "Изменение значения",
                    color: Color(hex: counterContent.colorHex),
                    unit: counterContent.unit
                )
                .frame(height: 200)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Helper Methods
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
    
    private func incrementCounter() {
        withAnimation {
            counterContent.currentValue += 1
        }
        addHistoryEntry(value: counterContent.currentValue)
        hapticManager.playHaptic(style: .light)
        saveCounter()
    }
    
    private func decrementCounter() {
        withAnimation {
            counterContent.currentValue = max(0, counterContent.currentValue - 1)
        }
        addHistoryEntry(value: counterContent.currentValue)
        hapticManager.playHaptic(style: .light)
        saveCounter()
    }
    
    private func addHistoryEntry(value: Int, note: String = "") {
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
        editingField = field
        switch field {
        case .currentValue:
            showValueEditor = true
            return
        case .targetValue:
            editedText = counterContent.targetValue != nil ? "\(counterContent.targetValue!)" : ""
        case .unit:
            editedText = counterContent.unit
        case .notes:
            editedText = counterContent.notes
        }
        
        // Show alert for inline editing (only for non-currentValue fields)
        let alert = UIAlertController(title: fieldTitle(for: field), message: nil, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.text = editedText
            textField.placeholder = fieldPlaceholder(for: field)
            if field == .targetValue {
                textField.keyboardType = .numberPad
            }
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
        case .currentValue:
            // Handled by CounterValueEditorSheet
            break
        case .targetValue:
            counterContent.targetValue = Int(text)
        case .unit:
            counterContent.unit = text
        case .notes:
            counterContent.notes = text
        }
        hapticManager.playHaptic(style: .light)
        saveCounter()
    }
    
    private func fieldTitle(for field: EditingField) -> String {
        switch field {
        case .currentValue: return "Текущее значение"
        case .targetValue: return "Целевое значение"
        case .unit: return "Единица измерения"
        case .notes: return "Заметки"
        }
    }
    
    private func fieldPlaceholder(for field: EditingField) -> String {
        switch field {
        case .currentValue: return "0"
        case .targetValue: return "100"
        case .unit: return "раз, мл, стр..."
        case .notes: return "Дополнительная информация"
        }
    }
}

// MARK: - Counter Statistic Card
struct CounterStatisticCard: View {
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

// MARK: - Counter Editor Sheet
struct CounterEditorSheet: View {
    @Binding var counterContent: MemoCounterContent
    let onSave: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var showIconPicker = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Основное") {
                    HStack {
                        Text("Текущее значение")
                        Spacer()
                        TextField("0", value: $counterContent.currentValue, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Целевое значение")
                        Spacer()
                        TextField("Нет", value: $counterContent.targetValue, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Единица измерения")
                        Spacer()
                        TextField("раз, мл, стр...", text: $counterContent.unit)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section("Дополнительно") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Заметки")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        TextEditor(text: $counterContent.notes)
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
                            if let imageData = counterContent.customImageData,
                               let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24, height: 24)
                            } else {
                                Image(systemName: counterContent.iconName)
                                    .foregroundColor(Color(hex: counterContent.colorHex))
                            }
                        }
                    }
                    
                    ColorPicker("Цвет", selection: Binding(
                        get: { Color(hex: counterContent.colorHex) },
                        set: { counterContent.colorHex = $0.toHex() ?? "#FF9500" }
                    ))
                }
            }
            .navigationTitle("Редактировать счетчик")
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
                    selectedIcon: $counterContent.iconName,
                    isPresented: $showIconPicker
                )
            }
        }
    }
}

// MARK: - Counter Value Editor Sheet
struct CounterValueEditorSheet: View {
    let currentValue: Int
    let color: Color
    let onSave: (Int, String) -> Void
    let onCancel: () -> Void
    
    @State private var deltaValue: Int = 0
    @State private var valueText: String = "0"
    @State private var note: String = ""
    @FocusState private var isTextFieldFocused: Bool
    
    private let hapticManager = HapticSoundManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    // Кнопки - и + с полем значения
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
                    
                    // Note field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Заметка (опционально)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                        
                        TextField("Введите заметку", text: $note)
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal, 20)
                    }
                    
                    // Кнопки Принять/Отмена
                    HStack(spacing: 20) {
                        Button("Отмена") {
                            resetDelta()
                            onCancel()
                        }
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        Button("Сохранить") {
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
            valueText = "\(abs(deltaValue))"
        }
    }
    
    private func parseValueInput(_ input: String) -> Int {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            return 0
        }
        
        if let value = Int(trimmed) {
            return value
        }
        
        return 0
    }
}
