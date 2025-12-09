import SwiftUI

struct MemoMoodContent: Codable, Hashable {
    var entries: [MoodEntry] = []
    var scale: Int = 10 // 1-10 scale
    var iconName: String = "face.smiling"
    var customImageData: Data? = nil
    var colorHex: String = "#FF2D55" // Default iOS pink
    var sphereID: UUID? = nil
    var notes: String = ""
    
    struct MoodEntry: Codable, Hashable {
        var date: Date
        var value: Int // 1-10
        var tags: [String] = []
        var notes: String = ""
    }
}

// MARK: - Mood Content View
struct MoodContentView: View {
    let item: MemoItem
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        if let data = item.contentData, let mood = try? JSONDecoder().decode(MemoMoodContent.self, from: data) {
            VStack(alignment: .leading, spacing: 20) {
                // Mood Overview
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "face.smiling")
                            .foregroundColor(.pink)
                        Text("Настроение")
                            .font(.headline)
                        Spacer()
                        Text("\(mood.entries.count) записей")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Average Mood
                    if !mood.entries.isEmpty {
                        let averageMood = Double(mood.entries.reduce(0) { $0 + $1.value }) / Double(mood.entries.count)
                        VStack(spacing: 8) {
                            Text("Среднее настроение")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            ZStack {
                                Circle()
                                    .fill(getMoodColor(for: Int(averageMood), scale: mood.scale).opacity(0.2))
                                    .frame(width: 80, height: 80)

                                VStack {
                                    Text(String(format: "%.1f", averageMood))
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(getMoodColor(for: Int(averageMood), scale: mood.scale))

                                    Text("из \(mood.scale)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }

                // Quick Mood Input
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "plus.circle")
                            .foregroundColor(.pink)
                        Text("Быстрый ввод")
                            .font(.headline)
                    }
                    
                    QuickMoodInputView(
                        scale: mood.scale,
                        onMoodSelected: { value in
                            addMoodEntry(item: item, content: mood, value: value)
                        }
                    )
                }
                
                // Recent Entries
                if !mood.entries.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(.pink)
                            Text("Последние записи")
                                .font(.headline)
                            Spacer()
                            Text("5 последних")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        VStack(spacing: 8) {
                            ForEach(mood.entries.suffix(5), id: \.date) { entry in
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(getMoodColor(for: entry.value, scale: mood.scale))
                                            .frame(width: 40, height: 40)

                                        VStack(spacing: 1) {
                                            Text("\(entry.value)")
                                                .font(.caption)
                                                .foregroundColor(.white)
                                                .fontWeight(.bold)
                                            
                                            Text(getMoodEmoji(for: entry.value, scale: mood.scale))
                                                .font(.caption2)
                                        }
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(entry.date, style: .date)
                                            .font(.subheadline)
                                            .fontWeight(.medium)

                                        if !entry.tags.isEmpty {
                                            Text(entry.tags.joined(separator: ", "))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color(UIColor.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }

                        // Chart
                        ChartView(
                            data: mood.entries.map { ChartDataPoint(date: $0.date, value: Double($0.value)) },
                            title: "Динамика настроения",
                            color: .pink,
                            unit: "уровень"
                        )
                    }
                } else {
                    Text("История настроений пуста")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 40)
                }
            }
        } else {
            EmptyMemoView()
        }
    }
    
    private func addMoodEntry(item: MemoItem, content: MemoMoodContent, value: Int) {
        var updatedContent = content
        updatedContent.entries.append(MemoMoodContent.MoodEntry(
            date: Date(),
            value: value,
            tags: []
        ))
        
        if let data = try? JSONEncoder().encode(updatedContent) {
            item.contentData = data
            try? modelContext.save()
        }
    }
    
    private func getMoodColor(for value: Int, scale: Int) -> Color {
        let ratio = Double(value) / Double(scale)
        if ratio < 0.2 { return .red }
        else if ratio < 0.4 { return .orange }
        else if ratio < 0.6 { return .yellow }
        else if ratio < 0.8 { return .green }
        else { return .blue }
    }
    
    private func getMoodEmoji(for value: Int, scale: Int) -> String {
        let ratio = Double(value) / Double(scale)
        if ratio < 0.2 { return "😢" }
        else if ratio < 0.4 { return "😐" }
        else if ratio < 0.6 { return "🙂" }
        else if ratio < 0.8 { return "😊" }
        else { return "😄" }
    }
}



// MARK: - Quick Mood Input View
struct QuickMoodInputView: View {
    let scale: Int
    let onMoodSelected: (Int) -> Void
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: min(scale, 5)), spacing: 12) {
            ForEach(1...scale, id: \.self) { value in
                Button(action: {
                    onMoodSelected(value)
                }) {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(getMoodColor(for: value, scale: scale).opacity(0.15))
                                .frame(width: 60, height: 60)
                            
                            VStack(spacing: 2) {
                                Text("\(value)")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(getMoodColor(for: value, scale: scale))
                                
                                Text(getMoodEmoji(for: value, scale: scale))
                                    .font(.title2)
                            }
                        }
                        
                        Text("\(value)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 12)
    }
}



// MARK: - Helper Functions
func getMoodColor(for value: Int, scale: Int) -> Color {
    let percentage = Double(value) / Double(scale)
    switch percentage {
    case 0.0..<0.2: return .red
    case 0.2..<0.4: return .orange
    case 0.4..<0.6: return .yellow
    case 0.6..<0.8: return .blue
    default: return .green
    }
}

func getMoodEmoji(for value: Int, scale: Int) -> String {
    let percentage = Double(value) / Double(scale)
    switch percentage {
    case 0.0..<0.2: return "😢"
    case 0.2..<0.4: return "😕"
    case 0.4..<0.6: return "😐"
    case 0.6..<0.8: return "🙂"
    default: return "😊"
    }
}
