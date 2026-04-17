import SwiftUI
import SwiftData
import Charts

// Presentation · Memo — тип «календарь»: записи по дням, мини-графики (Charts).
// Оглавление: `MemoCalendarContent` → хелперы дат → экран месяца → статистика → ячейка дня.

// MARK: Модель контента calendar-мемо
struct MemoCalendarContent: Codable, Hashable {
    /// Keys: "yyyy-MM-dd", values: text (max 200 chars)
    var entries: [String: String] = [:]
    var iconName: String = "calendar"
    var customImageData: Data? = nil
    var colorHex: String = "#5856D6" // iOS purple
    var sphereID: UUID? = nil
    var positiveImpact: Double = 0.0
    var negativeImpact: Double = 0.0
    var additionalImpacts: [SphereImpact] = []
    
    static let maxCharsPerEntry = 200
    
    func text(for dateKey: String) -> String {
        entries[dateKey] ?? ""
    }
    
    func daysWithEntriesCount(in dateRange: ClosedRange<Date>) -> Int {
        let cal = Calendar.current
        var count = 0
        var d = dateRange.lowerBound
        while d <= dateRange.upperBound {
            let key = dateKey(for: d)
            if !(entries[key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                count += 1
            }
            d = cal.date(byAdding: .day, value: 1, to: d) ?? d
        }
        return count
    }
}

// MARK: Ключи дат и подписи (форматтеры)
private func dateKey(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone.current
    return formatter.string(from: date)
}

private func weekdayShortEn(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "EE"
    formatter.locale = Locale(identifier: "en_US")
    return String(formatter.string(from: date).prefix(2)).uppercased()
}

private func dateRangeDisplay(from date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMMM, yyyy"
    formatter.locale = Locale.current
    return formatter.string(from: date)
}

// MARK: Главный экран календаря (сетка дней, ввод)
struct CalendarContentView: View {
    let item: MemoItem
    @Environment(\.modelContext) private var modelContext
    @State private var calendarContent: MemoCalendarContent = MemoCalendarContent()
    @State private var displayedMonth: Date = Date()
    @State private var pendingEdits: [String: String] = [:]
    @FocusState private var focusedDayKey: String?
    @State private var scrollToDayKey: String?
    @State private var iconPulseTrigger = UUID()
    
    private let hapticManager = HapticSoundManager.shared
    
    private var displayedMonthRange: (start: Date, end: Date) {
        let cal = Calendar.current
        let start = cal.date(from: DateComponents(year: cal.component(.year, from: displayedMonth), month: cal.component(.month, from: displayedMonth), day: 1))!
        let end = cal.date(byAdding: DateComponents(month: 1, day: -1), to: start)!
        return (start, end)
    }
    
    private var days: [Date] {
        let cal = Calendar.current
        var result: [Date] = []
        var d = displayedMonthRange.start
        while d <= displayedMonthRange.end {
            result.append(d)
            d = cal.date(byAdding: .day, value: 1, to: d) ?? d
        }
        return result
    }
    
    private var todayStart: Date {
        Calendar.current.startOfDay(for: Date())
    }
    
    private func isWeekend(_ date: Date) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        return weekday == 1 || weekday == 7 // Sun=1, Sat=7
    }
    
    private func isToday(_ date: Date) -> Bool {
        Calendar.current.isDate(date, inSameDayAs: Date())
    }
    
    private func cellBackground(for date: Date) -> Color {
        if isToday(date) {
            return Color(hex: calendarContent.colorHex).opacity(0.16)
        }
        if isWeekend(date) {
            return .white
        }
        return Color(UIColor.secondarySystemGroupedBackground)
    }
    
    private func effectiveText(for dateKey: String) -> String {
        pendingEdits[dateKey] ?? calendarContent.text(for: dateKey)
    }
    
    private func saveAllPending() {
        guard !pendingEdits.isEmpty else { return }
        for (key, text) in pendingEdits {
            let trimmed = String(text.prefix(MemoCalendarContent.maxCharsPerEntry))
            if trimmed.isEmpty {
                calendarContent.entries.removeValue(forKey: key)
            } else {
                calendarContent.entries[key] = trimmed
            }
        }
        pendingEdits.removeAll()
        if let data = try? JSONEncoder().encode(calendarContent) {
            item.contentData = data
            try? modelContext.save()
        }
        hapticManager.completionSuccess()
    }
    
    private var daysWithEntriesInDisplayedMonth: Int {
        var count = 0
        var d = displayedMonthRange.start
        while d <= displayedMonthRange.end {
            let key = dateKey(for: d)
            if !effectiveText(for: key).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                count += 1
            }
            d = Calendar.current.date(byAdding: .day, value: 1, to: d) ?? d
        }
        return count
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Upper info view (style as in other memos): icon + count + month switcher
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Color(hex: calendarContent.colorHex), lineWidth: 2)
                        .frame(width: 44, height: 44)
                    Image(systemName: calendarContent.iconName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hex: calendarContent.colorHex))
                        .symbolEffect(.pulse, options: .nonRepeating, value: iconPulseTrigger)
                }
                Text("\(daysWithEntriesInDisplayedMonth)")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Color(hex: calendarContent.colorHex))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                
                Spacer(minLength: 6)
                
                HStack(spacing: 2) {
                    Button {
                        hapticManager.selectionChanged()
                        displayedMonth = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .foregroundColor(Color(hex: calendarContent.colorHex))
                            .frame(width: 32, height: 36)
                    }
                    Text(dateRangeDisplay(from: displayedMonth))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hex: calendarContent.colorHex))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .layoutPriority(1)
                    Button {
                        hapticManager.selectionChanged()
                        displayedMonth = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.body.weight(.semibold))
                            .foregroundColor(Color(hex: calendarContent.colorHex))
                            .frame(width: 32, height: 36)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(hex: calendarContent.colorHex).opacity(0.16))
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .clear, radius: 0)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 12)
            
            // Scrollable list of days
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(days, id: \.self) { date in
                            let key = dateKey(for: date)
                            CalendarDayCell(
                                date: date,
                                text: Binding(
                                    get: { effectiveText(for: key) },
                                    set: { newVal in
                                        pendingEdits[key] = newVal
                                    }
                                ),
                                backgroundColor: cellBackground(for: date),
                                memoColor: Color(hex: calendarContent.colorHex),
                                isWeekend: isWeekend(date),
                                isToday: isToday(date),
                                focusedDayKey: $focusedDayKey,
                                dayKey: key,
                                maxChars: MemoCalendarContent.maxCharsPerEntry,
                                onTap: { focusedDayKey = key }
                            )
                            .id(key)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                .onChange(of: focusedDayKey) { oldKey, newKey in
                    if oldKey != nil, !pendingEdits.isEmpty {
                        saveAllPending()
                    }
                    if let key = newKey {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            proxy.scrollTo(key, anchor: .center)
                        }
                    }
                }
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .onAppear {
            loadContent()
            iconPulseTrigger = UUID()
        }
    }
    
    private func loadContent() {
        if let data = item.contentData, let content = try? JSONDecoder().decode(MemoCalendarContent.self, from: data) {
            calendarContent = content
        }
    }
}

// MARK: Статистика и графики по календарному мемо
struct CalendarMemoStatisticsView: View {
    let item: MemoItem
    @Environment(\.dismiss) private var dismiss
    
    private var content: MemoCalendarContent {
        guard let data = item.contentData,
              let c = try? JSONDecoder().decode(MemoCalendarContent.self, from: data) else {
            return MemoCalendarContent()
        }
        return c
    }
    
    private var totalDaysWithEntries: Int {
        content.entries.values.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    }
    
    private var allMonthsSpan: (start: Date, end: Date) {
        let cal = Calendar.current
        let keys = content.entries.keys.compactMap { k -> Date? in
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            fmt.locale = Locale(identifier: "en_US_POSIX")
            return fmt.date(from: k)
        }
        guard !keys.isEmpty, let mn = keys.min(), let mx = keys.max() else {
            let now = Date()
            return (cal.date(from: DateComponents(year: cal.component(.year, from: now), month: cal.component(.month, from: now), day: 1)) ?? now, now)
        }
        return (mn, mx)
    }
    
    
    private var mostActiveDays: [(String, Int)] {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE"
        fmt.locale = Locale(identifier: "en_US")
        var byWeekday: [String: Int] = [:]
        for (k, v) in content.entries where !v.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let d = isoDate(from: k) {
                let name = fmt.string(from: d)
                byWeekday[name, default: 0] += 1
            }
        }
        return byWeekday.sorted { $0.value > $1.value }.prefix(7).map { ($0.key, $0.value) }
    }
    
    private func isoDate(from key: String) -> Date? {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        return fmt.date(from: key)
    }
    
    private var entriesByMonthChartData: [ChartDataPoint] {
        let cal = Calendar.current
        var byMonth: [Date: Int] = [:]
        for (k, v) in content.entries where !v.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard let d = isoDate(from: k),
                  let start = cal.date(from: DateComponents(year: cal.component(.year, from: d), month: cal.component(.month, from: d), day: 1)) else { continue }
            byMonth[start, default: 0] += 1
        }
        return byMonth.sorted { $0.key < $1.key }.map { ChartDataPoint(date: $0.key, value: Double($0.value)) }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Text("Calendar Statistics")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text(item.title)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    
                    StatisticCard(title: "Days with entries", value: "\(totalDaysWithEntries)", icon: "calendar", color: Color(hex: content.colorHex))
                        .padding(.horizontal)
                    
                    if !entriesByMonthChartData.isEmpty {
                        ChartView(
                            data: entriesByMonthChartData,
                            title: "Entries by month",
                            color: Color(hex: content.colorHex),
                            unit: "days"
                        )
                        .padding(.horizontal)
                    }
                    
                    if !mostActiveDays.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Most active days")
                                .font(.headline)
                            VStack(spacing: 8) {
                                ForEach(mostActiveDays, id: \.0) { dayName, count in
                                    HStack {
                                        Text(dayName)
                                            .font(.subheadline)
                                        Spacer()
                                        Text("\(count)")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        GeometryReader { g in
                                            ZStack(alignment: .leading) {
                                                RoundedRectangle(cornerRadius: 2)
                                                    .fill(Color.gray.opacity(0.2))
                                                RoundedRectangle(cornerRadius: 2)
                                                    .fill(Color(hex: content.colorHex))
                                                    .frame(width: g.size.width * CGFloat(count) / CGFloat(max(1, mostActiveDays.map(\.1).max() ?? 1)))
                                            }
                                        }
                                        .frame(width: 60, height: 6)
                                    }
                                }
                            }
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: Одна ячейка дня в сетке
private struct CalendarDayCell: View {
    let date: Date
    @Binding var text: String
    let backgroundColor: Color
    let memoColor: Color
    var isWeekend: Bool = false
    var isToday: Bool = false
    var focusedDayKey: FocusState<String?>.Binding
    let dayKey: String
    let maxChars: Int
    var onTap: () -> Void
    
    private let cal = Calendar.current
    private let minCellHeight: CGFloat = 36
    
    private var dayNumber: Int { cal.component(.day, from: date) }
    private var weekdayShort: String { weekdayShortEn(date) }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Day number + weekday
            VStack(alignment: .leading, spacing: 2) {
                Text("\(dayNumber)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                Text(weekdayShort)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 32, alignment: .leading)
            
            // Text field
            TextField("", text: $text, axis: .vertical)
                .font(.body)
                .lineLimit(1...10)
                .focused(focusedDayKey, equals: dayKey)
                .onChange(of: text) { _, newVal in
                    if newVal.count > maxChars {
                        text = String(newVal.prefix(maxChars))
                    }
                }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(minHeight: minCellHeight, alignment: .leading)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke((isWeekend && !isToday) ? memoColor.opacity(0.28) : .clear, lineWidth: 1.5)
        )
        .shadow(color: .clear, radius: 0)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}
