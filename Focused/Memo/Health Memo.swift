import SwiftUI

struct MemoHealthContent: Codable, Hashable {
    var initialValue: Double = 0.0 // Изначальное значение
    var stepValue: Double = 0.1 // Шаг изменения значения (по умолчанию 0.1)
    var currentValue: Double = 0.0 // Текущее значение (начинается с initialValue)
    var unit: String = "ед." // Единица измерения
    var iconName: String = "heart.fill"
    var customImageData: Data? = nil
    var colorHex: String = "#E6332A" // default red
    var sphereID: UUID? = nil
    var notes: String = ""
    var entries: [HealthEntry] = []
    
    struct HealthEntry: Codable, Hashable, Identifiable {
        var id: UUID = UUID()
        var date: Date
        var value: Double // изменение значения (положительное = увеличение, отрицательное = уменьшение)
        var note: String = ""
    }
    
    var color: Color { Color(hex: colorHex) }
}


// MARK: - Health Content View
struct HealthContentView: View {
    let item: MemoItem
    @Environment(\.modelContext) private var modelContext
    
    @State private var healthContent: MemoHealthContent = MemoHealthContent()
    @State private var deltaValue: Double = 0.0
    @State private var valueText: String = "0"
    @FocusState private var isTextFieldFocused: Bool
    
    private let hapticManager = HapticSoundManager.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Кнопки - и + с полем значения
                HStack(spacing: 20) {
                    Button {
                        deltaValue -= healthContent.stepValue
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
                            .foregroundColor(healthContent.color)
                            .multilineTextAlignment(.center)
                            .keyboardType(.numbersAndPunctuation)
                            .focused($isTextFieldFocused)
                            .onChange(of: valueText) { oldValue, newValue in
                                deltaValue = parseValueInput(newValue)
                            }
                            .frame(width: 120)
                        
                        Text(healthContent.unit)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button {
                        deltaValue += healthContent.stepValue
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
                
                // Кнопки Принять/Отмена
                HStack(spacing: 20) {
                    Button("Отмена") {
                        resetDelta()
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    Button("Сохранить") {
                        saveChange()
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(healthContent.color)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .disabled(deltaValue == 0.0)
                }
                .padding(.horizontal, 20)
                
                // История изменений
                if !healthContent.entries.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("История изменений")
                            .font(.headline)
                            .padding(.horizontal, 20)
                        
                        LazyVStack(spacing: 8) {
                            ForEach(healthContent.entries.sorted(by: { $0.date > $1.date })) { entry in
                                HStack {
                                    Text(entry.date, style: .date)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text((entry.value >= 0 ? "+" : "") + formatValue(entry.value) + " " + healthContent.unit)
                                        .font(.subheadline.bold())
                                        .foregroundColor(entry.value >= 0 ? .blue : .red)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color(UIColor.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
        .onAppear {
            load()
            resetDelta()
        }
    }
    
    // MARK: - Helpers
    private func load() {
        if let data = item.contentData, let content = try? JSONDecoder().decode(MemoHealthContent.self, from: data) {
            healthContent = content
            // Если currentValue не установлено, устанавливаем из initialValue
            if healthContent.currentValue == 0.0 && healthContent.initialValue != 0.0 {
                healthContent.currentValue = healthContent.initialValue
            }
        }
    }
    
    private func save() {
        if let data = try? JSONEncoder().encode(healthContent) {
            item.contentData = data
            try? modelContext.save()
        }
    }
    
    private func resetDelta() {
        deltaValue = 0.0
        valueText = "0"
        isTextFieldFocused = false
    }
    
    private func updateValueText() {
        if deltaValue == 0.0 {
            valueText = "0"
        } else {
            // Форматируем значение с учетом десятичных знаков
            let absValue = abs(deltaValue)
            if absValue.truncatingRemainder(dividingBy: 1) == 0 {
                valueText = String(format: "%.0f", absValue)
            } else {
                // Определяем количество знаков после запятой на основе stepValue
                let stepString = String(healthContent.stepValue)
                let decimalPlaces = stepString.contains(".") ? stepString.split(separator: ".").last?.count ?? 1 : 0
                valueText = String(format: "%.\(min(decimalPlaces, 2))f", absValue)
            }
            
            // Добавляем знак минус если нужно
            if deltaValue < 0 {
                valueText = "-" + valueText
            }
        }
    }
    
    private func parseValueInput(_ input: String) -> Double {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            return 0.0
        }
        
        // Проверяем наличие знака минус
        let isNegative = trimmed.hasPrefix("-")
        let cleanInput = isNegative ? String(trimmed.dropFirst()) : trimmed
        
        // Пробуем распарсить как число
        if let value = Double(cleanInput) {
            return isNegative ? -value : value
        }
        
        // Если не удалось распарсить, возвращаем 0
        return 0.0
    }
    
    private func saveChange() {
        guard deltaValue != 0.0 else { return }
        
        healthContent.currentValue += deltaValue
        
        let entry = MemoHealthContent.HealthEntry(
            date: Date(),
            value: deltaValue,
            note: ""
        )
        healthContent.entries.append(entry)
        
        hapticManager.playHaptic(style: .medium)
        save()
        resetDelta()
    }
    
    private func formatValue(_ value: Double) -> String {
        let absValue = abs(value)
        if absValue.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", absValue)
        } else {
            // Определяем количество знаков после запятой на основе stepValue
            let stepString = String(healthContent.stepValue)
            let decimalPlaces = stepString.contains(".") ? stepString.split(separator: ".").last?.count ?? 1 : 0
            return String(format: "%.\(min(decimalPlaces, 2))f", absValue)
        }
    }
}

