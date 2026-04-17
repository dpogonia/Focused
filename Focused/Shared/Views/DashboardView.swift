import SwiftUI
import SwiftData
import Charts

// MARK: - Дашборд статистики (Presentation)
//
// Сводка по целям/задачам/привычкам/мемо. Данные — `@Query`; навигация назад — стандартный SwiftUI dismiss.
// Не смешивает доменные расчёты с `ImpactEngine` напрямую — при расширении лучше вынести агрегацию в use case.

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query private var goals: [Goal]
    @Query private var tasks: [SuperTask]
    @Query private var habits: [Habit]
    @Query private var spheres: [Sphere]
    @Query private var memoItems: [MemoItem]
    
    @State private var selectedPeriod: StatsPeriod = .month
    @State private var habitsCompletionRate: Double = 0
    @State private var bestHabitStreak: Int = 0
    @State private var last7DaysHabitCompletion: [(date: Date, rate: Double, dayLabel: String)] = []
    
    private let hapticManager = HapticSoundManager.shared
    
    enum StatsPeriod: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case quarter = "Quarter"
        case year = "Year"
        
        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .quarter: return 90
            case .year: return 365
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    periodPicker
                    
                    goalsSection
                    
                    tasksSection
                    
                    habitsSection
                    
                    spheresDynamicsSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        hapticManager.selectionChanged()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .task(id: selectedPeriod) {
            try? await Task.sleep(nanoseconds: 50_000_000) // 0.05s — дать view отрисоваться
            computeHabitStats()
        }
    }

    private func computeHabitStats() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = periodStartDate

        var rate = 0.0
        var totalScheduled = 0
        var totalCompleted = 0
        for habit in habits where !habit.isArchived {
            let logic = HabitLogicService(habit: habit)
            var date = start
            while date <= today {
                if logic.isScheduled(on: date) {
                    totalScheduled += 1
                    if habit.isCompletedHabit(on: date) { totalCompleted += 1 }
                }
                date = calendar.date(byAdding: .day, value: 1, to: date) ?? today
            }
        }
        rate = totalScheduled > 0 ? Double(totalCompleted) / Double(totalScheduled) : 0

        var streak = 0
        for habit in habits where !habit.isArchived {
            var current = 0
            var date = today
            let logic = HabitLogicService(habit: habit)
            for _ in 0..<90 {
                if logic.isScheduled(on: date) {
                    if habit.isCompletedHabit(on: date) { current += 1 }
                    else { break }
                }
                guard let prev = calendar.date(byAdding: .day, value: -1, to: date) else { break }
                date = prev
            }
            streak = max(streak, current)
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        let chartData = (0..<7).reversed().map { daysAgo -> (Date, Double, String) in
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today
            var scheduled = 0, completed = 0
            for habit in habits where !habit.isArchived {
                let logic = HabitLogicService(habit: habit)
                if logic.isScheduled(on: date) {
                    scheduled += 1
                    if habit.isCompletedHabit(on: date) { completed += 1 }
                }
            }
            let r = scheduled > 0 ? Double(completed) / Double(scheduled) : 0
            return (date, r, formatter.string(from: date))
        }

        habitsCompletionRate = rate
        bestHabitStreak = streak
        last7DaysHabitCompletion = chartData.map { ($0.0, $0.1, $0.2) }
    }
    
    // MARK: - Period Picker
    private var periodPicker: some View {
        Picker("Period", selection: $selectedPeriod) {
            ForEach(StatsPeriod.allCases, id: \.self) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }
    
    // MARK: - Goals Section
    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Goals", icon: "target", color: .orange)
            
            HStack(spacing: 12) {
                goalStatCard(
                    title: "Completed",
                    value: completedGoalsCount,
                    total: totalGoalsInPeriod,
                    color: .green
                )
                
                goalStatCard(
                    title: "In Progress",
                    value: inProgressGoalsCount,
                    total: totalGoalsInPeriod,
                    color: .blue
                )
                
                goalStatCard(
                    title: "Pending",
                    value: pendingGoalsCount,
                    total: totalGoalsInPeriod,
                    color: .gray
                )
            }
            
            if totalGoalsInPeriod > 0 {
                goalsProgressChart
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    private func goalStatCard(title: String, value: Int, total: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if total > 0 {
                Text("\(Int(Double(value) / Double(total) * 100))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var goalsProgressChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Completion Rate")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            GeometryReader { geometry in
                let completedWidth = geometry.size.width * goalCompletionRate
                
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [.green, .green.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: completedWidth)
                }
            }
            .frame(height: 24)
            
            Text("\(Int(goalCompletionRate * 100))% of goals completed")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Tasks Section
    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Tasks", icon: "text.badge.checkmark", color: .blue)
            
            HStack(spacing: 12) {
                taskStatCard(
                    title: "Completed",
                    value: completedTasksCount,
                    color: .green,
                    icon: "checkmark.circle.fill"
                )
                
                taskStatCard(
                    title: "Active",
                    value: activeTasksCount,
                    color: .blue,
                    icon: "clock.fill"
                )
                
                taskStatCard(
                    title: "Overdue",
                    value: overdueTasksCount,
                    color: .red,
                    icon: "exclamationmark.triangle.fill"
                )
            }
            
            if !tasksByStatus.isEmpty {
                tasksByStatusChart
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    private func taskStatCard(title: String, value: Int, color: Color, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text("\(value)")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var tasksByStatusChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tasks by Status")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            HStack(spacing: 16) {
                ForEach(tasksByStatus, id: \.status) { item in
                    VStack(spacing: 4) {
                        Circle()
                            .fill(item.color)
                            .frame(width: 12, height: 12)
                        Text("\(item.count)")
                            .font(.headline)
                        Text(item.label)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - Habits Section
    private var habitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Habits", icon: "repeat", color: .purple)
            
            HStack(spacing: 12) {
                habitStatCard(
                    title: "Completion Rate",
                    value: "\(Int(habitsCompletionRate * 100))%",
                    subtitle: "of scheduled",
                    color: .purple
                )
                
                habitStatCard(
                    title: "Active Habits",
                    value: "\(habits.count)",
                    subtitle: "total",
                    color: .blue
                )
                
                habitStatCard(
                    title: "Best Streak",
                    value: "\(bestHabitStreak)",
                    subtitle: "days",
                    color: .orange
                )
            }
            
            if !habits.isEmpty {
                habitsCompletionChart
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    private func habitStatCard(title: String, value: String, subtitle: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var habitsCompletionChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Weekly Completion")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            HStack(spacing: 4) {
                ForEach(last7DaysHabitCompletion, id: \.date) { day in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(day.rate > 0.7 ? Color.green : day.rate > 0.4 ? Color.yellow : Color.red.opacity(0.3))
                            .frame(height: CGFloat(day.rate * 40 + 10))
                        
                        Text(day.dayLabel)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 70)
        }
    }
    
    // MARK: - Spheres Dynamics Section
    private var spheresDynamicsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Life Spheres", icon: "circle.hexagonpath", color: .teal)
            
            if spheres.isEmpty {
                Text("No spheres created yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(spheres.sorted { $0.orderIndex < $1.orderIndex }) { sphere in
                    sphereRow(sphere)
                }
                
                spheresSummaryChart
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    private func sphereRow(_ sphere: Sphere) -> some View {
        HStack(spacing: 12) {
            Image(systemName: sphere.iconName)
                .font(.title3)
                .foregroundColor(Color(hex: sphere.colorHex))
                .frame(width: 32, height: 32)
                .background(Color(hex: sphere.colorHex).opacity(0.15))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(sphere.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(Int(sphere.satisfaction))% satisfaction")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            GeometryReader { geometry in
                let width = geometry.size.width * (sphere.satisfaction / 100)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: sphere.colorHex))
                        .frame(width: width)
                }
            }
            .frame(width: 80, height: 8)
        }
        .padding(.vertical, 4)
    }
    
    private var spheresSummaryChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Average Satisfaction")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(averageSatisfaction))%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.teal)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Total Spheres")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(spheres.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                }
            }
        }
    }
    
    // MARK: - Helper Views
    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(title)
                .font(.headline)
            Spacer()
        }
    }
    
    // MARK: - Computed Properties
    
    private var periodStartDate: Date {
        Calendar.current.date(byAdding: .day, value: -selectedPeriod.days, to: Date()) ?? Date()
    }
    
    // Goals
    private var goalsInPeriod: [Goal] {
        goals.filter { $0.creationDate >= periodStartDate }
    }
    
    private var totalGoalsInPeriod: Int { goalsInPeriod.count }
    
    private var completedGoalsCount: Int {
        goalsInPeriod.filter { $0.status == .completed }.count
    }
    
    private var inProgressGoalsCount: Int {
        goalsInPeriod.filter { $0.status == .inProgress }.count
    }
    
    private var pendingGoalsCount: Int {
        goalsInPeriod.filter { $0.status == .pending }.count
    }
    
    private var goalCompletionRate: Double {
        guard totalGoalsInPeriod > 0 else { return 0 }
        return Double(completedGoalsCount) / Double(totalGoalsInPeriod)
    }
    
    // Tasks
    private var tasksInPeriod: [SuperTask] {
        tasks.filter { $0.creationDate >= periodStartDate }
    }
    
    private var completedTasksCount: Int {
        tasksInPeriod.filter { $0.statusEnum == .completed }.count
    }
    
    private var activeTasksCount: Int {
        tasksInPeriod.filter { $0.statusEnum == .inProgress }.count
    }
    
    private var overdueTasksCount: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return tasksInPeriod.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate < today && task.statusEnum != .completed && task.statusEnum != .archived
        }.count
    }
    
    private var tasksByStatus: [(status: SuperTask.Status, count: Int, label: String, color: Color)] {
        let grouped = Dictionary(grouping: tasksInPeriod) { $0.statusEnum }
        return [
            (SuperTask.Status.inProgress, grouped[.inProgress]?.count ?? 0, "In Progress", .blue),
            (SuperTask.Status.completed, grouped[.completed]?.count ?? 0, "Completed", .green),
            (SuperTask.Status.archived, grouped[.archived]?.count ?? 0, "Archived", .gray)
        ].filter { $0.count > 0 }
    }
    
    // Spheres
    private var averageSatisfaction: Double {
        guard !spheres.isEmpty else { return 0 }
        return spheres.reduce(0) { $0 + $1.satisfaction } / Double(spheres.count)
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: [Goal.self, SuperTask.self, Habit.self, Sphere.self, MemoItem.self])
}
