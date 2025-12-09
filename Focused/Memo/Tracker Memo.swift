import SwiftUI

struct MemoTrackerContent: Codable, Hashable {
    var trackerName: String = ""
    var trackerType: String = "counter" // counter, limit, range, boolean
    var dailyLimit: Double?
    var currentValue: Double = 0.0
    var targetValue: Double?
    var unit: String = ""
    var entries: [TrackerEntry] = []
    var notes: String = ""
    
    struct TrackerEntry: Codable, Hashable {
        var date: Date
        var value: Double
        var category: String = ""
        var notes: String = ""
        var tags: [String] = []
    }
}


// MARK: - Tracker Content View
struct TrackerContentView: View {
    let item: MemoItem
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        if let data = item.contentData, let tracker = try? JSONDecoder().decode(MemoTrackerContent.self, from: data) {
            VStack(alignment: .leading, spacing: 20) {
                // Tracker Overview
                VStack(spacing: 16) {
            HStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .foregroundColor(.teal)
                        Text(tracker.trackerName.isEmpty ? "Трекер" : tracker.trackerName)
                            .font(.headline)
                    Spacer()
                        Text("\(tracker.entries.count) записей")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    }

                    // Current Value Display
                    ZStack {
                        Circle()
                            .fill(Color.teal.opacity(0.2))
                            .frame(width: 120, height: 120)

                        VStack {
                            Text("\(tracker.currentValue, format: .number)")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.teal)

                            if !tracker.unit.isEmpty {
                                Text(tracker.unit)
                        .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)

                    // Limits and Targets
                    if tracker.dailyLimit != nil || tracker.targetValue != nil {
                        HStack(spacing: 20) {
                            if let limit = tracker.dailyLimit {
                                VStack {
                                    Text("\(limit, format: .number)")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(.orange)
                                    Text("Лимит")
                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            if let target = tracker.targetValue {
                                VStack {
                                    Text("\(target, format: .number)")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(.green)
                                    Text("Цель")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                // Recent Entries
                if !tracker.entries.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
            HStack {
                            Image(systemName: "list.bullet")
                                .foregroundColor(.teal)
                            Text("Последние записи")
                                .font(.headline)
                    Spacer()
                            Text("5 последних")
                                .font(.caption)
                                .foregroundColor(.secondary)
            }
            
                        VStack(spacing: 8) {
                            ForEach(tracker.entries.suffix(5), id: \.date) { entry in
                HStack {
                                    ZStack {
                                        Circle()
                                            .fill(Color.teal.opacity(0.2))
                                            .frame(width: 32, height: 32)

                                        Image(systemName: "circle.fill")
                                            .font(.caption)
                                            .foregroundColor(.teal)
                                    }

                        VStack(alignment: .leading) {
                                        Text("\(entry.value, format: .number) \(tracker.unit)")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                            Text(entry.date, style: .date)
                                .font(.caption)
                                            .foregroundColor(.secondary)

                                        if !entry.category.isEmpty {
                                            Text(entry.category)
                                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                                        if !entry.notes.isEmpty {
                                            Text(entry.notes)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                
                Spacer()
                
                            Text(entry.tags.joined(separator: ", "))
                                .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    } else {
                        Text("Записи отсутствуют")
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
}

