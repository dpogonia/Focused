import SwiftUI
import SwiftData

// MARK: - HABITS STATISTICS VIEWS
struct PieChartData: Equatable {
    let completed: Int
    let missed: Int
    let skipped: Int
    var total: Int { completed + missed + skipped }
}

struct BarChartDataPoint: Identifiable, Equatable {
    let id = UUID()
    let period: Date
    let completed: Int
    let missed: Int
    let skipped: Int
    
    static func ==(lhs: BarChartDataPoint, rhs: BarChartDataPoint) -> Bool {
        return lhs.id == rhs.id &&
        lhs.period == rhs.period &&
        lhs.completed == rhs.completed &&
        lhs.missed == rhs.missed &&
        lhs.skipped == rhs.skipped
    }
}

enum StatsPeriod: String, CaseIterable, Identifiable {
    case week = "1W"
    case month1 = "1M"
    case month3 = "3M"
    case month6 = "6M"
    case year1 = "1Y"
    case all = "All"
    
    var id: String { self.rawValue }
    
    func startDate(for habitCreationDate: Date, endDate: Date) -> Date {
        let calendar = Calendar.current
        switch self {
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: endDate)!
        case .month1:
            return calendar.date(byAdding: .month, value: -1, to: endDate)!
        case .month3:
            return calendar.date(byAdding: .month, value: -3, to: endDate)!
        case .month6:
            return calendar.date(byAdding: .month, value: -6, to: endDate)!
        case .year1:
            return calendar.date(byAdding: .year, value: -1, to: endDate)!
        case .all:
            return habitCreationDate
        }
    }
}

struct StatisticsView: View {
    let habit: Habit
    let endDate: Date
    
    enum ChartType: String, CaseIterable, Identifiable {
        case pie = "Overall"
        case bar = "Trend"
        var id: String { self.rawValue }
    }
    
    @State private var selectedChartType: ChartType = .pie
    @State private var selectedPeriod: StatsPeriod = .month1
    
    @State private var pieData: PieChartData?
    @State private var barData: [BarChartDataPoint]?
    
    private let hapticManager = HapticSoundManager.shared
    
    var body: some View {
        Section(header: Text("Statistics")) {
            Picker("Chart Type", selection: $selectedChartType) {
                Image(systemName: "chart.pie.fill").tag(ChartType.pie)
                Image(systemName: "chart.bar.xaxis").tag(ChartType.bar)
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedChartType) {
                hapticManager.selectionChanged()
            }
            
            Picker("Period", selection: $selectedPeriod) {
                ForEach(StatsPeriod.allCases) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedPeriod) {
                hapticManager.selectionChanged()
            }
            
            VStack {
                if let pieData = pieData, let barData = barData {
                    if selectedChartType == .pie {
                        PieChartView(data: pieData)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    } else {
                        BarChartView(data: barData, selectedPeriod: selectedPeriod)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                } else {
                    ProgressView().frame(height: 150)
                }
            }
            .padding(.vertical, 5)
            .animation(.easeInOut(duration: 0.2), value: pieData)
            .animation(.easeInOut(duration: 0.2), value: barData)
            .animation(.easeInOut(duration: 0.2), value: selectedChartType)
        }
        .onAppear(perform: calculateStats)
        .onChange(of: selectedPeriod) {
            calculateStats()
        }
    }
    
    private func calculateStats() {
        pieData = nil
        barData = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            let periodStartDate = selectedPeriod.startDate(for: habit.creationDate, endDate: endDate)
            let calculationStartDate = max(periodStartDate, habit.creationDate)
            
            let (calculatedPieData, calculatedBarData) = HabitLogicService(habit: habit).calculateStats(from: calculationStartDate, upTo: endDate, for: selectedPeriod)
            
            DispatchQueue.main.async {
                self.pieData = calculatedPieData
                self.barData = calculatedBarData
            }
        }
    }
}

struct PieChartView: View {
    let data: PieChartData
    
    var body: some View {
        VStack {
            if data.total == 0 {
                Text("no data yet")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .frame(height: 150)
            } else {
                ZStack {
                    PieSliceView(startAngle: .degrees(0), endAngle: angle(for: data.completed))
                        .fill(Color.green)
                    PieSliceView(startAngle: angle(for: data.completed), endAngle: angle(for: data.completed) + angle(for: data.missed))
                        .fill(Color.red)
                    PieSliceView(startAngle: angle(for: data.completed) + angle(for: data.missed), endAngle: .degrees(360))
                        .fill(Color(UIColor.systemGray4))
                }
                .frame(width: 150, height: 150)
                .padding(.bottom)
                
                HStack(spacing: 20) {
                    legendItem(color: .green, value: data.completed, label: "Done")
                    legendItem(color: .red, value: data.missed, label: "Missed")
                    legendItem(color: .gray, value: data.skipped, label: "Skipped")
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
    
    private func angle(for value: Int) -> Angle {
        if data.total == 0 { return .degrees(0) }
        return .degrees(Double(value) / Double(data.total) * 360.0)
    }
    
    @ViewBuilder
    private func legendItem(color: Color, value: Int, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text("\(value) \(label)").font(.caption)
        }
    }
}

struct PieSliceView: Shape {
    var startAngle: Angle
    var endAngle: Angle
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        path.move(to: center)
        path.addArc(center: center, radius: rect.width / 2, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.closeSubpath()
        return path
    }
}

struct BarChartView: View {
    let data: [BarChartDataPoint]
    let selectedPeriod: StatsPeriod
    private let maxBarHeight: CGFloat = AppConstants.Chart.maxBarHeight
    private let labelSpaceAboveBar: CGFloat = AppConstants.Chart.labelSpaceAboveBar
    
    private var maxTotalCount: Int {
        data.map { $0.completed + $0.missed + $0.skipped }.max() ?? 0
    }
    
    var body: some View {
        VStack {
            if data.isEmpty {
                Text("no data yet")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .frame(height: maxBarHeight + labelSpaceAboveBar + AppConstants.Chart.periodLabelAreaHeight)
            } else {
                ZStack {
                    GeometryReader { proxy in
                        let yPositionFor50PercentLine = (proxy.size.height - AppConstants.Chart.periodLabelAreaHeight) - (maxBarHeight / 2)
                        
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: yPositionFor50PercentLine))
                            path.addLine(to: CGPoint(x: proxy.size.width, y: yPositionFor50PercentLine))
                        }
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                        .foregroundColor(.gray.opacity(0.6))
                    }
                    .frame(height: maxBarHeight + labelSpaceAboveBar + AppConstants.Chart.periodLabelAreaHeight)
                    
                    HStack(alignment: .bottom, spacing: 0) {
                        VStack {
                            Spacer()
                                .frame(height: AppConstants.Chart.periodLabelAreaHeight)
                            Text("100%")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .offset(y: -6)
                            Spacer()
                            Text("50%")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .offset(y: -3)
                            Spacer()
                            Text("0%")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .offset(y: 1)
                            Spacer()
                                .frame(height: AppConstants.Chart.periodLabelAreaHeight)
                        }
                        .frame(height: maxBarHeight + labelSpaceAboveBar + AppConstants.Chart.periodLabelAreaHeight)
                        .padding(.trailing, 4)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(data) { point in
                                    VStack {
                                        HStack(spacing: 4) {
                                            VStack {
                                                Text("\(point.completed)")
                                                    .font(.caption)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.green)
                                                    .offset(y: point.completed == 0 ? 10 : 0)
                                                    .padding(.bottom, 0)
                                                
                                                Rectangle()
                                                    .fill(Color.green)
                                                    .frame(width: 20, height: barHeight(for: point.completed))
                                                    .cornerRadius(4)
                                            }
                                            .frame(height: maxBarHeight + labelSpaceAboveBar, alignment: .bottom)
                                            
                                            VStack {
                                                Text("\(point.missed)")
                                                    .font(.caption)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.red)
                                                    .offset(y: point.missed == 0 ? 10 : 0)
                                                
                                                Rectangle()
                                                    .fill(Color.red)
                                                    .frame(width: 20, height: barHeight(for: point.missed))
                                                    .cornerRadius(4)
                                            }
                                            .frame(height: maxBarHeight + labelSpaceAboveBar, alignment: .bottom)
                                            
                                            VStack {
                                                Text("\(point.skipped)")
                                                    .font(.caption)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.gray)
                                                    .offset(y: point.skipped == 0 ? 10 : 0)
                                                
                                                Rectangle()
                                                    .fill(Color.gray)
                                                    .frame(width: 20, height: barHeight(for: point.skipped))
                                                    .cornerRadius(4)
                                            }
                                            .frame(height: maxBarHeight + labelSpaceAboveBar, alignment: .bottom)
                                        }
                                        
                                        Text(formatPeriod(point.period, for: selectedPeriod))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .frame(height: maxBarHeight + labelSpaceAboveBar + AppConstants.Chart.periodLabelAreaHeight)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: maxBarHeight + labelSpaceAboveBar + AppConstants.Chart.periodLabelAreaHeight + 10)
    }
    
    private func barHeight(for value: Int) -> CGFloat {
        guard maxTotalCount > 0 else { return 0 }
        return CGFloat(value) / CGFloat(maxTotalCount) * maxBarHeight
    }
    
    private func formatPeriod(_ date: Date, for period: StatsPeriod) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        switch period {
        case .week:
            formatter.dateFormat = "'W'w"
            return formatter.string(from: date)
        case .month1:
            formatter.dateFormat = "MMM"
            return formatter.string(from: date)
        case .month3:
            formatter.dateFormat = "MMM"
            guard let endOfMonth = calendar.date(byAdding: .month, value: 2, to: date) else { return "" }
            return "\(formatter.string(from: date)) - \(formatter.string(from: endOfMonth))"
        case .month6:
            formatter.dateFormat = "MMM"
            guard let endOfMonth = calendar.date(byAdding: .month, value: 5, to: date) else { return "" }
            return "\(formatter.string(from: date)) - \(formatter.string(from: endOfMonth))"
        case .year1:
            formatter.dateFormat = "yyyy"
            return formatter.string(from: date)
        case .all:
            formatter.dateFormat = "yyyy"
            let startYear = calendar.component(.year, from: date)
            let endYear = startYear + 2
            return "\(startYear) - \(endYear)"
        }
    }
}

