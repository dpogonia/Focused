import SwiftUI
import SwiftData

/// Compact "momentum" sphere card (short version of Dashboard summary).
/// Intended to live in the old mini-sphere-card slot under the main Vision visualization.
struct VisionMomentumSphereCard: View {
    let sphere: Sphere
    let goals: [Goal]
    let tasks: [SuperTask]
    let habits: [Habit]
    
    private var sphereColor: Color { Color(hex: sphere.colorHex) }
    private var satisfactionPercent: Int { Int(max(0, min(100, sphere.satisfaction)).rounded()) }
    private var activeGoals: Int { goals.filter { $0.status != .archived && $0.status != .completed }.count }
    private var activeTasks: Int { tasks.filter { $0.statusEnum != .archived && $0.statusEnum != .completed }.count }
    private var activeHabits: Int { habits.filter { !$0.isArchived }.count }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: sphere.iconName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(sphereColor)
                    .frame(width: 38, height: 38)
                    .background(sphereColor.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Momentum")
                        .font(.headline.weight(.semibold))
                    Text("\(sphere.title) • \(activeGoals) goals • \(activeTasks) tasks • \(activeHabits) habits")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer(minLength: 10)
                
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(sphereColor)
                    Text("\(satisfactionPercent)%")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(sphereColor.opacity(0.10), in: Capsule())
            }
            
            HStack(spacing: 10) {
                Image(systemName: "chart.bar.xaxis")
                    .foregroundStyle(.secondary)
                Text(dynamicHintText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                miniMomentumBars(values: momentumSeriesForSphere)
                    .frame(width: 74, height: 18)
            }
        }
        .padding(14)
        .mainListCardChrome(
            fill: LinearGradient(
                colors: [sphereColor.opacity(0.14), Color(UIColor.secondarySystemGroupedBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            stroke: Color.black.opacity(0.06),
            cornerRadius: 20
        )
    }
    
    private var dynamicHintText: String {
        if satisfactionPercent >= 80 { return "Strong pace — keep it going" }
        if satisfactionPercent >= 45 { return "Steady progress — one more push" }
        return "Small steps today = big changes soon"
    }
    
    private var momentumSeriesForSphere: [Double] {
        let anchor = max(0.05, min(0.95, Double(satisfactionPercent) / 100.0))
        return momentumSeries(seedID: sphere.id, anchorProgress: anchor)
    }
    
    private func miniMomentumBars(values: [Double]) -> some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(values.enumerated()), id: \.offset) { _, v in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color.primary.opacity(0.18))
                    .frame(width: 5, height: max(3, 18 * v))
            }
        }
    }
    
    private func momentumSeries(seedID: UUID, anchorProgress: Double) -> [Double] {
        let base = 0.22 + 0.60 * anchorProgress
        var out: [Double] = []
        for i in 0..<7 {
            let n = seededUnit(seedID, salt: i * 997 + 13)
            let slope = Double(i) / 6.0 * 0.10
            let v = clamp01(base * 0.55 + n * 0.45 + slope - 0.06)
            out.append(v)
        }
        return out
    }
    
    private func seededUnit(_ id: UUID, salt: Int) -> Double {
        var h: UInt64 = 1469598103934665603
        for b in id.uuidString.utf8 {
            h ^= UInt64(b)
            h &*= 1099511628211
        }
        h ^= UInt64(salt & 0xffff_ffff)
        h &*= 1099511628211
        return Double(h % 10_000) / 10_000.0
    }
    
    private func clamp01(_ x: Double) -> Double { max(0, min(1, x)) }
}

/// Full-height momentum card (occupies the entire lower Vision area, no scroll).
/// Header → compact Goals/Tasks/Habits tiles → today's task completion (calendar rules) → weekly activity.
struct VisionMomentumFullCardView: View {
    let sphere: Sphere
    let goals: [Goal]
    let tasks: [SuperTask]
    let habits: [Habit]
    /// Sum of positive impact still achievable (incomplete goals + memo counters), same as `VisionsView.totalPositiveImpact`.
    let positiveImpactPotential: Double
    
    private var sphereColor: Color { Color(hex: sphere.colorHex) }
    private var satisfactionPercent: Int { Int(max(0, min(100, sphere.satisfaction)).rounded()) }
    
    /// Projected sphere satisfaction if remaining positive impact is fully realized (clamped 0…100).
    private var projectedSatisfaction: Double {
        max(0, min(100, sphere.satisfaction + positiveImpactPotential))
    }
    
    /// Same rule as the old mini sphere card: only show arrow when growth is meaningful.
    private var showsProjectedGrowth: Bool {
        projectedSatisfaction >= 10 && projectedSatisfaction > sphere.satisfaction + 0.1
    }
    
    // MARK: Goals stats (this sphere)
    private var goalsVisible: [Goal] { goals.filter { $0.status != .archived } }
    private var goalsCompleted: Int { goalsVisible.filter { $0.status == .completed }.count }
    private var goalsTotal: Int { goalsVisible.count }
    private var goalsRate: Double {
        guard goalsTotal > 0 else { return 0 }
        return Double(goalsCompleted) / Double(goalsTotal)
    }
    
    // MARK: Tasks stats (this sphere)
    private var tasksVisible: [SuperTask] { tasks.filter { $0.statusEnum != .archived } }
    private var tasksCompleted: Int { tasksVisible.filter { $0.statusEnum == .completed }.count }
    private var tasksTotal: Int { tasksVisible.count }
    private var tasksRate: Double {
        guard tasksTotal > 0 else { return 0 }
        return Double(tasksCompleted) / Double(tasksTotal)
    }
    
    /// Tasks that belong to «today» for this sphere (same rules as `TasksCalendarFilter`).
    private var tasksDueToday: [SuperTask] {
        TasksCalendarFilter(tasks: tasksVisible).filterForDate(Date())
    }
    private var tasksTodayCompleted: Int { tasksDueToday.filter { $0.statusEnum == .completed }.count }
    private var tasksTodayTotal: Int { tasksDueToday.count }
    private var tasksTodayRate: Double {
        guard tasksTodayTotal > 0 else { return 0 }
        return Double(tasksTodayCompleted) / Double(tasksTodayTotal)
    }
    
    // MARK: Habits stats (this sphere, last 7 days)
    private var habitsActive: [Habit] { habits.filter { !$0.isArchived } }
    private var weeklyHabitStats: (rate: Double, series: [(label: String, value: Double)]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let fmt = DateFormatter()
        fmt.dateFormat = "E"
        
        var totalScheduled = 0
        var totalCompleted = 0
        var series: [(String, Double)] = []
        
        for daysAgo in (0..<7).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { continue }
            var scheduled = 0
            var completed = 0
            for habit in habitsActive {
                let logic = HabitLogicService(habit: habit)
                if logic.isScheduled(on: date) {
                    scheduled += 1
                    if habit.isCompletedHabit(on: date) { completed += 1 }
                }
            }
            totalScheduled += scheduled
            totalCompleted += completed
            let rate = scheduled > 0 ? Double(completed) / Double(scheduled) : 0
            series.append((fmt.string(from: date), rate))
        }
        
        let overall = totalScheduled > 0 ? Double(totalCompleted) / Double(totalScheduled) : 0
        return (overall, series)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            statTilesRow
            todayTasksCompletionSection
            weeklyActivity
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .mainListCardChrome(
            fill: LinearGradient(
                colors: [sphereColor.opacity(0.14), Color(UIColor.secondarySystemGroupedBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            stroke: Color.black.opacity(0.06),
            cornerRadius: 22
        )
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 12)
    }
    
    // MARK: - Sections
    
    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: sphere.iconName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(sphereColor)
                .frame(width: 38, height: 38)
                .background(sphereColor.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Momentum")
                    .font(.headline.weight(.semibold))
                Text("\(sphere.title) • \(dynamicHintText)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer(minLength: 10)
            
            // Same visual language as the old mini sphere card: solid sphere tint + white % chips.
            HStack(spacing: 6) {
                Text("\(String(format: "%.1f", sphere.satisfaction))%")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.white.opacity(0.18))
                    .clipShape(Capsule())
                if showsProjectedGrowth {
                    Text("→ \(Int(projectedSatisfaction.rounded()))%")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.white.opacity(0.12))
                        .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 0.75))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(sphereColor)
            )
        }
    }
    
    /// Dashboard-style completion block: tasks scheduled for **today** in this sphere (calendar rules).
    private var todayTasksCompletionSection: some View {
        let pct = Int((tasksTodayRate * 100).rounded())
        return VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geometry in
                let w = geometry.size.width * max(0, min(1, tasksTodayRate))
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.2))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.green, Color.green.opacity(0.75)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, w))
                }
            }
            .frame(height: 10)
            
            if tasksTodayTotal == 0 {
                Text("No tasks for today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(pct)% of today's tasks completed (\(tasksTodayCompleted)/\(tasksTodayTotal))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mainListCardChrome(
            fill: Color(UIColor.secondarySystemGroupedBackground).opacity(0.55),
            stroke: Color.black.opacity(0.06),
            cornerRadius: 14
        )
    }
    
    private var statTilesRow: some View {
        HStack(spacing: 10) {
            compactStatTile(title: "Goals", icon: "target", color: Color(red: 0.95, green: 0.55, blue: 0.25), rate: goalsRate)
            compactStatTile(title: "Tasks", icon: "checkmark.circle", color: .blue, rate: tasksRate)
            compactStatTile(title: "Habits", icon: "repeat", color: .purple, rate: weeklyHabitStats.rate)
        }
    }
    
    private func compactStatTile(title: String, icon: String, color: Color, rate: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text("\(Int((rate * 100).rounded()))%")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(color.opacity(0.9))
            }
            
            GeometryReader { g in
                let w = g.size.width * max(0, min(1, rate))
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.black.opacity(0.06))
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(color.opacity(0.85))
                        .frame(width: w)
                }
            }
            .frame(height: 5)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mainListCardChrome(
            fill: color.opacity(0.10),
            stroke: color.opacity(0.18),
            cornerRadius: 14
        )
    }
    
    private var weeklyActivity: some View {
        let series = weeklyHabitStats.series
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.xaxis")
                    .foregroundStyle(.secondary)
                Text("Weekly activity")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(habitsActive.isEmpty ? "Habits not set" : "habits completion")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            GeometryReader { g in
                let bars = max(1, series.count)
                let spacing: CGFloat = 6
                let totalSpacing = CGFloat(bars - 1) * spacing
                let barW = max(6, (g.size.width - totalSpacing) / CGFloat(bars))
                let maxH = g.size.height - 16
                
                HStack(alignment: .bottom, spacing: spacing) {
                    ForEach(Array(series.enumerated()), id: \.offset) { _, item in
                        VStack(spacing: 4) {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(colorForRate(item.value))
                                .frame(width: barW, height: max(3, maxH * CGFloat(item.value)))
                            Text(item.label)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(10)
        .mainListCardChrome(
            fill: Color(UIColor.secondarySystemGroupedBackground).opacity(0.6),
            stroke: Color.black.opacity(0.06),
            cornerRadius: 14
        )
    }
    
    // MARK: - Helpers
    
    private func colorForRate(_ r: Double) -> Color {
        if r >= 0.7 { return sphereColor.opacity(0.9) }
        if r >= 0.4 { return sphereColor.opacity(0.55) }
        if r > 0 { return sphereColor.opacity(0.30) }
        return Color.black.opacity(0.12)
    }
    
    private var dynamicHintText: String {
        if satisfactionPercent >= 80 { return "Strong pace — keep it going" }
        if satisfactionPercent >= 45 { return "Steady progress — one more push" }
        return "Small steps today = big changes soon"
    }
}

/// Scrollable «Life Spheres» block for Vision bottom pager (same layout language as `DashboardView`).
/// Rows sorted by **descending** `satisfaction` (ties: `orderIndex`).
struct VisionLifeSpheresPageView: View {
    let spheres: [Sphere]
    
    private var sortedSpheres: [Sphere] {
        spheres.sorted {
            if $0.satisfaction != $1.satisfaction {
                return $0.satisfaction > $1.satisfaction
            }
            return $0.orderIndex < $1.orderIndex
        }
    }
    
    private var averageSatisfaction: Double {
        guard !spheres.isEmpty else { return 0 }
        return spheres.reduce(0.0) { $0 + $1.satisfaction } / Double(spheres.count)
    }
    
    var body: some View {
        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader(title: "Life Spheres", icon: "circle.hexagonpath", color: .teal)
                    
                    if spheres.isEmpty {
                        Text("No spheres created yet")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(sortedSpheres) { sphere in
                            sphereRow(sphere)
                        }
                        spheresSummary
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, minHeight: geo.size.height, alignment: .top)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 12)
        .padding(.top, 6)
    }
    
    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(title)
                .font(.headline)
            Spacer()
        }
    }
    
    private func sphereRow(_ sphere: Sphere) -> some View {
        let tint = Color(hex: sphere.colorHex)
        let sat = min(100, max(0, sphere.satisfaction))
        return HStack(spacing: 12) {
            Image(systemName: sphere.iconName)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(sphere.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("\(Int(sat))% satisfaction")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer(minLength: 8)
            
            GeometryReader { geometry in
                let width = geometry.size.width * (sat / 100)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.gray.opacity(0.2))
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(tint)
                        .frame(width: width)
                }
            }
            .frame(width: 80, height: 8)
        }
        .padding(.vertical, 4)
    }
    
    private var spheresSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Average Satisfaction")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(Int(averageSatisfaction.rounded()))%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.teal)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Total Spheres")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(spheres.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                }
            }
        }
    }
}

/// Goals grid on Vision: only **Important** goals (`isFlagged`),3 columns, drag-and-drop to reorder (`visionGridOrder`).
struct VisionGoalsGridView: View {
    @Environment(\.modelContext) private var modelContext
    let goals: [Goal]
    let fallbackIconName: String
    let fallbackColorHex: String
    
    private var visibleGoals: [Goal] {
        goals
            .filter { $0.isFlagged && $0.status != .archived }
            .sorted {
                if $0.visionGridOrder != $1.visionGridOrder {
                    return $0.visionGridOrder < $1.visionGridOrder
                }
                return $0.orderIndex < $1.orderIndex
            }
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                if visibleGoals.isEmpty {
                    emptyState
                } else {
                    goalsGrid
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var goalsGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]
        
        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(visibleGoals) { goal in
                goalPhotoCard(goal)
            }
        }
    }
    
    private func goalPhotoCard(_ goal: Goal) -> some View {
        let tint = Color(hex: goal.colorHex ?? fallbackColorHex)
        
        let card = VStack(alignment: .leading, spacing: 8) {
            GoalSquareImage(goal: goal, fallbackSystemName: goal.iconName ?? fallbackIconName, tint: tint)
                .frame(maxWidth: .infinity)
            
            Text(goal.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .mainListCardChrome(
            fill: Color(UIColor.secondarySystemGroupedBackground),
            stroke: Color.black.opacity(0.06),
            cornerRadius: 16
        )
        
        return card
            .draggable(goal.id.uuidString) {
                Image(systemName: "star.fill")
                    .font(.title2)
                    .foregroundStyle(tint)
                    .padding(14)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .dropDestination(for: String.self) { items, _ in
                guard let s = items.first,
                      let draggedId = UUID(uuidString: s),
                      draggedId != goal.id else { return false }
                commitVisionGridReorder(draggedId: draggedId, targetId: goal.id)
                return true
            }
    }
    
    private func commitVisionGridReorder(draggedId: UUID, targetId: UUID) {
        var list = visibleGoals
        guard let from = list.firstIndex(where: { $0.id == draggedId }),
              let to = list.firstIndex(where: { $0.id == targetId }),
              from != to else { return }
        let mover = list.remove(at: from)
        let insertIndex = to > from ? to - 1 : to
        list.insert(mover, at: insertIndex)
        for (i, g) in list.enumerated() {
            g.visionGridOrder = i
        }
        try? modelContext.save()
        HapticSoundManager.shared.selectionChanged()
    }
    
    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "star")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color(hex: fallbackColorHex).opacity(0.7))
                .padding(.bottom, 2)
            Text("No important goals")
                .font(.headline.weight(.semibold))
            Text("Open a goal and tap the star next to the title to show it here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .mainListCardChrome(
            fill: Color(UIColor.secondarySystemGroupedBackground),
            stroke: Color.black.opacity(0.06),
            cornerRadius: 20
        )
        .padding(.top, 6)
    }
}

private struct GoalSquareImage: View {
    let goal: Goal
    let fallbackSystemName: String
    let tint: Color
    
    var body: some View {
        GeometryReader { geo in
            let side = geo.size.width
            ZStack {
                if let data = goal.imageData, let ui = UIImage(data: data) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                } else {
                    LinearGradient(
                        colors: [tint.opacity(0.22), Color.black.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    Image(systemName: fallbackSystemName)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(tint.opacity(0.85))
                }
            }
            .frame(width: side, height: side)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        // Force square layout in LazyVGrid regardless of image aspect ratio.
        .aspectRatio(1, contentMode: .fit)
    }
}

