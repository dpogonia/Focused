import SwiftUI

struct MemoTimeContent: Codable, Hashable {
    var initialMinutes: Double = 0.0 // Изначальное время
    var stepMinutes: Double = 15.0 // Шаг времени в минутах (по умолчанию 15)
    var currentMinutes: Double = 0.0 // Текущее время (начинается с initialMinutes)
    var iconName: String = "clock.fill"
    var customImageData: Data? = nil
    var colorHex: String = "#0A84FF" // default blue
    var sphereID: UUID? = nil
    var notes: String = ""
    var entries: [TimeEntry] = []
    
    struct TimeEntry: Codable, Hashable, Identifiable {
        var id: UUID = UUID()
        var date: Date
        var minutes: Double // положительное = добавлено время, отрицательное = вычтено
        var note: String = ""
    }
    
    var color: Color { Color(hex: colorHex) }
}

// MARK: - Time Content View
struct TimeContentView: View {
    let item: MemoItem
    @Environment(\.modelContext) private var modelContext
    
    @State private var timeContent: MemoTimeContent = MemoTimeContent()
    @State private var deltaMinutes: Double = 0.0
    @State private var minutesText: String = "0"
    @FocusState private var isTextFieldFocused: Bool
    
    private let hapticManager = HapticSoundManager.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Кнопки - и + с полем времени
                HStack(spacing: 20) {
                    Button {
                        deltaMinutes -= timeContent.stepMinutes
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
                        .foregroundColor(timeContent.color)
                        .multilineTextAlignment(.center)
                        .keyboardType(.numbersAndPunctuation)
                        .focused($isTextFieldFocused)
                        .onChange(of: minutesText) { oldValue, newValue in
                            deltaMinutes = parseTimeInput(newValue)
                        }
                        .frame(width: 120)
                    
                    Spacer()
                    
                    Button {
                        deltaMinutes += timeContent.stepMinutes
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
                    .background(timeContent.color)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .disabled(deltaMinutes == 0.0)
                }
                .padding(.horizontal, 20)
                
                // История изменений
                if !timeContent.entries.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("История изменений")
                            .font(.headline)
                            .padding(.horizontal, 20)
                        
                        LazyVStack(spacing: 8) {
                            ForEach(timeContent.entries.sorted(by: { $0.date > $1.date })) { entry in
                                HStack {
                                    Text(entry.date, style: .date)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text((entry.minutes >= 0 ? "+" : "") + formatMinutes(entry.minutes))
                                        .font(.subheadline.bold())
                                        .foregroundColor(entry.minutes >= 0 ? .blue : .red)
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
        if let data = item.contentData, let content = try? JSONDecoder().decode(MemoTimeContent.self, from: data) {
            timeContent = content
            // Если currentMinutes не установлено, устанавливаем из initialMinutes
            if timeContent.currentMinutes == 0.0 && timeContent.initialMinutes > 0.0 {
                timeContent.currentMinutes = timeContent.initialMinutes
            }
        }
    }
    
    private func save() {
        if let data = try? JSONEncoder().encode(timeContent) {
            item.contentData = data
            try? modelContext.save()
        }
    }
    
    private func resetDelta() {
        deltaMinutes = 0.0
        minutesText = "0"
        isTextFieldFocused = false
    }
    
    private func updateMinutesText() {
        let totalMinutes = Int(abs(deltaMinutes))
        
        if deltaMinutes == 0.0 {
            minutesText = "0"
        } else {
            minutesText = "\(totalMinutes)"
            // Добавляем знак минус если нужно
            if deltaMinutes < 0 {
                minutesText = "-" + minutesText
            }
        }
    }
    
    private func parseTimeInput(_ input: String) -> Double {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            return 0.0
        }
        
        // Проверяем наличие знака минус
        let isNegative = trimmed.hasPrefix("-")
        let cleanInput = isNegative ? String(trimmed.dropFirst()) : trimmed
        
        // Пробуем распарсить как число (минуты)
        if let minutes = Double(cleanInput) {
            return isNegative ? -minutes : minutes
        }
        
        // Пробуем распарсить формат "чч:мм" или "ч:мм"
        if let colonIndex = cleanInput.firstIndex(of: ":") {
            let hoursPart = String(cleanInput[..<colonIndex])
            let minutesPart = String(cleanInput[cleanInput.index(after: colonIndex)...])
            
            if let hours = Double(hoursPart), let minutes = Double(minutesPart) {
                let totalMinutes = hours * 60 + minutes
                return isNegative ? -totalMinutes : totalMinutes
            }
        }
        
        // Если не удалось распарсить, возвращаем 0
        return 0.0
    }
    
    private func saveChange() {
        guard deltaMinutes != 0.0 else { return }
        
        timeContent.currentMinutes += deltaMinutes
        
        let entry = MemoTimeContent.TimeEntry(
            date: Date(),
            minutes: deltaMinutes,
            note: ""
        )
        timeContent.entries.append(entry)
        
        hapticManager.playHaptic(style: .medium)
        save()
        resetDelta()
    }
    
    private func formatMinutes(_ minutes: Double) -> String {
        let totalMinutes = Int(abs(minutes))
        let hrs = totalMinutes / 60
        let mins = totalMinutes % 60
        let sign = minutes < 0 ? "-" : ""
        if hrs > 0 {
            return sign + String(format: "%dч %02dм", hrs, mins)
        } else {
            return sign + String(format: "%dм", mins)
        }
    }
}



