import SwiftUI
import SwiftData
import Charts

// Presentation · Memo — сводная статистика по всем мемо (агрегация в `MemoStatistics`).
// Оглавление: экран статистики → карточки-плитки → модель агрегации → данные для графиков.

// MARK: Экран «Memo Statistics» (скролл, секции)
struct MemoStatisticsView: View {
    let memoItems: [MemoItem]

    private var statistics: MemoStatistics {
        MemoStatistics(memoItems: memoItems)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Text("📊 Memo Statistics")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Analysis of your entries")
                            .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    .padding(.top)

                    // Overview Cards
                    overviewCards

                    // Type Distribution
                    typeDistributionChart

                    // Tag Distribution
                    if statistics.uniqueTagsCount > 0 {
                        tagDistributionChart
                    }

                    // Recent Activity
                    recentActivitySection

                    // Trends
                    trendsSection
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var overviewCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            StatisticCard(
                title: "Total entries",
                value: "\(statistics.totalCount)",
                icon: "doc.text.fill",
                color: .blue
            )

            StatisticCard(
                title: "Today",
                value: "\(statistics.todayCount)",
                icon: "calendar",
                color: .green
            )

            StatisticCard(
                title: "This week",
                value: "\(statistics.weekCount)",
                icon: "calendar.badge.clock",
                color: .orange
            )

            StatisticCard(
                title: "Types",
                value: "\(statistics.uniqueTypesCount)",
                icon: "folder.fill",
                color: .purple
            )

            StatisticCard(
                title: "Tags",
                value: "\(statistics.uniqueTagsCount)",
                icon: "tag.fill",
                color: .green
            )
        }
    }

    private var typeDistributionChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Distribution by type")
                .font(.headline)

            VStack(spacing: 8) {
                ForEach(statistics.typeCounts.sorted(by: { $0.value > $1.value }), id: \.key) { type, count in
                HStack {
                        Image(systemName: type.iconName)
                            .foregroundColor(type.color)
                            .frame(width: 24)

                        Text(type.displayName)
                            .font(.subheadline)

                    Spacer()

                        Text("\(count)")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        // Progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 4)

                                Rectangle()
                                    .fill(type.color)
                                    .frame(width: geometry.size.width * CGFloat(count) / CGFloat(statistics.totalCount), height: 4)
                            }
                        }
                        .frame(width: 60, height: 4)
                    }
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var tagDistributionChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Distribution by tags")
                .font(.headline)

            VStack(spacing: 8) {
                ForEach(statistics.tagCounts.sorted(by: { $0.value > $1.value }).prefix(10), id: \.key) { tag, count in
                    HStack {
                        Image(systemName: "tag")
                            .foregroundColor(.green)
                            .frame(width: 24)

                        Text(tag)
                            .font(.subheadline)

                        Spacer()

                        Text("\(count)")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        // Progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 4)

                                Rectangle()
                                    .fill(Color.green)
                                    .frame(width: geometry.size.width * CGFloat(count) / CGFloat(statistics.totalCount), height: 4)
                            }
                        }
                        .frame(width: 60, height: 4)
                    }
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent activity")
                .font(.headline)

            VStack(spacing: 8) {
                ForEach(statistics.recentItems.prefix(5)) { item in
                    HStack {
                        Image(systemName: item.itemType.iconName)
                            .foregroundColor(item.itemType.color)
                            .frame(width: 24)

                        VStack(alignment: .leading) {
                            Text(item.title)
                                .font(.subheadline)
                                .lineLimit(1)

                            Text(item.creationDate, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Text(item.itemType.displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private var trendsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trends")
                .font(.headline)

            VStack(spacing: 8) {
                ForEach(statistics.dailyActivity.prefix(7), id: \.date) { activity in
                    HStack {
                        Text(activity.date, style: .date)
                            .font(.subheadline)

                        Spacer()

                        Text("\(activity.count) entries")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        // Simple trend indicator
                        if activity.count > 0 {
                            Image(systemName: "arrow.up")
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                    }
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: Универсальная карточка-метрика
struct StatisticCard: View {
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
                .font(.title)
                        .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: Модель `MemoStatistics` (подсчёты по типам)
struct MemoStatistics {
    let totalCount: Int
    let todayCount: Int
    let weekCount: Int
    let uniqueTypesCount: Int
    let typeCounts: [MemoItemType: Int]
    let tagCounts: [String: Int]
    let uniqueTagsCount: Int
    let recentItems: [MemoItem]
    let dailyActivity: [DailyActivity]

    struct DailyActivity {
        let date: Date
        let count: Int
    }

    init(memoItems: [MemoItem]) {
        self.totalCount = memoItems.count
        self.recentItems = Array(memoItems.prefix(10))

        // Calculate today count
        let today = Calendar.current.startOfDay(for: Date())
        self.todayCount = memoItems.filter {
            Calendar.current.isDate($0.creationDate, inSameDayAs: today)
        }.count

        // Calculate week count
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        self.weekCount = memoItems.filter {
            $0.creationDate >= weekAgo
        }.count

        // Calculate type distribution
        var typeCounts: [MemoItemType: Int] = [:]
        for item in memoItems {
            typeCounts[item.itemType, default: 0] += 1
        }
        self.typeCounts = typeCounts
        self.uniqueTypesCount = typeCounts.count

        // Calculate tag distribution
        var tagCounts: [String: Int] = [:]
        for item in memoItems {
            for tag in item.tags {
                tagCounts[tag, default: 0] += 1
            }
        }
        self.tagCounts = tagCounts
        self.uniqueTagsCount = tagCounts.count

        // Calculate daily activity for last 7 days
        var dailyActivity: [DailyActivity] = []
        for i in 0..<7 {
            let date = Calendar.current.date(byAdding: .day, value: -i, to: Date()) ?? Date()
            let count = memoItems.filter {
                Calendar.current.isDate($0.creationDate, inSameDayAs: date)
            }.count
            dailyActivity.append(DailyActivity(date: date, count: count))
        }
        self.dailyActivity = dailyActivity.reversed()
    }
}

// MARK: Структуры для Charts (серии, точки)
struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let label: String

    init(date: Date, value: Double, label: String = "") {
        self.date = date
        self.value = value
        self.label = label
    }
}

struct ChartView: View {
    let data: [ChartDataPoint]
    let title: String
    let color: Color
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                Spacer()
                Text("\(data.count) points")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if data.isEmpty {
                Text("No data for chart")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                Chart {
                    ForEach(data) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Value", point.value)
                        )
                        .foregroundStyle(color)
                        .symbol(.circle)
                        .interpolationMethod(.linear)
                    }
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { value in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.day().month())
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .padding(.vertical, 8)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
