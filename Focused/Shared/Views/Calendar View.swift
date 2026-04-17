import SwiftUI
import SwiftData

// Presentation · Shared — календарь/неделя/кружки дней и `CalendarManager` для выбора даты на нескольких вкладках.
// Не содержит бизнес-фильтрации списков — только UI состояние даты; фильтры — `*CalendarFilter` + use case на экранах списков.

// MARK: - Compact Calendar View
struct calendarView: View {
    @Binding var selectedDate: Date
    @Binding var weekStartDate: Date
    @Binding var isVisible: Bool
    /// Высота в pt; nil = 60. Для Vision можно передать UIScreen.main.bounds.height * 0.071
    var height: CGFloat? = nil

    @Query private var appCalendarSettings: [AppCalendarSettings]
    @Query(sort: \Sphere.orderIndex) private var spheres: [Sphere]

    private let hapticManager = HapticSoundManager.shared
    /// Одинаковый зазор слева и справа от вертикальной черты (визуально по центру между блоками)
    private let dividerGutter: CGFloat = 6
    
    private var resolvedHeight: CGFloat { height ?? 60 }

    /// Цвет точки «сегодня» — как у выбранной сферы на Vision (`accentSphereID`); иначе системный акцент.
    private var todayIndicatorColor: Color {
        if let sid = appCalendarSettings.first?.accentSphereID,
           let hex = spheres.first(where: { $0.id == sid })?.colorHex {
            return Color(hex: hex)
        }
        return Color.accentColor
    }
    
    /// Дата для индикатора: если selectedDate в видимой неделе — она; иначе — четверг видимой недели
    private var indicatorDate: Date {
        let calendar = Calendar.current
        let isSelectedInVisibleWeek = calendar.isDate(selectedDate, equalTo: weekStartDate, toGranularity: .weekOfYear)
        if isSelectedInVisibleWeek {
            return selectedDate
        }
        let weekday = calendar.component(.weekday, from: weekStartDate)
        let daysToThursday = (5 - weekday + 7) % 7
        return calendar.date(byAdding: .day, value: daysToThursday, to: weekStartDate) ?? weekStartDate
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 0) {
                // MARK: Left — крупный день и месяц, разделитель акцентом (как на макете)
                HStack(alignment: .center, spacing: 0) {
                    VStack(alignment: .center, spacing: 2) {
                        Text(dayFormatter.string(from: indicatorDate))
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(.primary)
                            .minimumScaleFactor(0.8)
                            .lineLimit(1)
                        Text(monthFormatter.string(from: indicatorDate).uppercased())
                            .font(.system(size: 10, weight: .semibold, design: .default))
                            .foregroundColor(.primary)
                    }
                    .frame(minWidth: 44)
                    .padding(.leading, 8)
                    .padding(.trailing, dividerGutter)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        let cal = Calendar.current
                        let now = Date()
                        if isTodaySelected && isVisibleWeekShowingToday { return }
                        hapticManager.selectionChanged()
                        var txn = Transaction()
                        txn.disablesAnimations = true
                        withTransaction(txn) {
                            selectedDate = cal.startOfDay(for: now)
                            weekStartDate = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
                        }
                    }

                    Rectangle()
                        .fill(Color.primary)
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                        .padding(.vertical, 2)
                }

                // MARK: Неделя — свайп по полосе
                WeekView(selectedDate: $selectedDate, weekStartDate: $weekStartDate, todayIndicatorColor: todayIndicatorColor)
                    .padding(.leading, dividerGutter)
            }
            .padding(.trailing, 8)
            .padding(.vertical, 3)
            .frame(maxHeight: .infinity)
        }
        .frame(height: resolvedHeight)
        .background(Color.clear)
        .preferredColorScheme(.none)
    }
    
    private var monthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter
    }
    
    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }
    
    private var isTodaySelected: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }
    
    /// После свайпа недели `weekStartDate` меняется, а `selectedDate` может остаться «сегодня» — полоса уезжает, хотя день всё ещё сегодня.
    private var isVisibleWeekShowingToday: Bool {
        Calendar.current.isDate(Date(), equalTo: weekStartDate, toGranularity: .weekOfYear)
    }
    
    private var currentMonthAndYear: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: selectedDate).uppercased()
    }
}

// MARK: - Compact Week View
struct WeekView: View {
    @Binding var selectedDate: Date
    @Binding var weekStartDate: Date
    var todayIndicatorColor: Color

    private let hapticManager = HapticSoundManager.shared

    var body: some View {
        HStack(spacing: 0) {
            // MARK: Horizontal list of week days
            WeekDaysView(weekStartDate: weekStartDate, selectedDate: $selectedDate, todayIndicatorColor: todayIndicatorColor)
                .frame(maxWidth: .infinity)
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    let threshold: CGFloat = 50
                    if value.translation.width > threshold {
                        // Swipe right - previous week
                        hapticManager.playHaptic(style: .soft)
                        changeWeek(by: -1)
                    } else if value.translation.width < -threshold {
                        // Swipe left - next week
                        hapticManager.playHaptic(style: .soft)
                        changeWeek(by: 1)
                    }
                }
        )
    }
    
    private func startOfWeek(for index: Int = 0) -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let weekOfYear = calendar.component(.weekOfYear, from: today)
        let yearForWeekOfYear = calendar.component(.yearForWeekOfYear, from: today)
        let startOfWeek = calendar.date(from: DateComponents(weekOfYear: weekOfYear, yearForWeekOfYear: yearForWeekOfYear))!
        return calendar.date(byAdding: .weekOfYear, value: index, to: startOfWeek)!
    }
    
    private func changeWeek(by value: Int) {
        if let newDate = Calendar.current.date(byAdding: .weekOfYear, value: value, to: weekStartDate) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                weekStartDate = newDate
            }
        }
    }
}

// MARK: - Compact Week Days View
struct WeekDaysView: View {
    let weekStartDate: Date
    @Binding var selectedDate: Date
    var todayIndicatorColor: Color
    private let hapticManager = HapticSoundManager.shared

    var body: some View {
        let days = daysOfWeek()
        return HStack(spacing: 4) {
            ForEach(0..<days.count, id: \.self) { index in
                let date = days[index]
                // MARK: Single day cell (weekday label + day circle)
                CompactDayView(
                    date: date,
                    isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                    todayIndicatorColor: todayIndicatorColor
                )
                    .frame(maxWidth: .infinity)
                    .onTapGesture {
                        hapticManager.selectionChanged()
                        var txn = Transaction()
                        txn.disablesAnimations = true
                        withTransaction(txn) {
                            selectedDate = Calendar.current.startOfDay(for: date)
                        }
                    }
            }
        }
        // Стабильная идентичность недели: при смене вкладки не переиспользовать ячейки с устаревшим isSelected.
        .id(weekStartDate.timeIntervalSince1970)
        .transaction { $0.disablesAnimations = true }
    }

    private func daysOfWeek() -> [Date] {
        var dates: [Date] = []
        for i in 0..<7 {
            if let date = Calendar.current.date(byAdding: .day, value: i, to: weekStartDate) {
                dates.append(date)
            }
        }
        return dates
    }
}

// MARK: - Compact Day Circle (Pulsing Circle for Calendar Days)
//struct CompactDayCircle: View {
//    let dayText: String
//    let isSelected: Bool
//    var size: CGFloat = 33
//
//    @State private var pulse = false
//    @Environment(\.colorScheme) var colorScheme
//    
//    private var outerRingWidth: CGFloat { size * 0.12 }
//    private var innerRingSize: CGFloat { size * 0.68 }
//    private var coreSize: CGFloat { size * 0.46 }
//    private let dayFontSize: CGFloat = 18
//    
//    private var backgroundColor: Color {
//        colorScheme == .dark
//            ? Color(UIColor.systemGray3)
//            : Color.white
//    }
//    
//    private var textColor: Color {
//        Color.black
//    }
//    
//    private var ringColor: Color {
//        Color.black
//    }
//    
//    var body: some View {
//        ZStack {
//            // Outer, soft ring - пульсирующее внешнее кольцо
//            Circle()
//                .stroke(ringColor.opacity(colorScheme == .dark ? 0.6 : 0.8), lineWidth: outerRingWidth)
//                .frame(width: size, height: size)
//                .scaleEffect(pulseScale)
//            
//            // Inner crisp ring - пульсирующее внутреннее кольцо
//            Circle()
//                .stroke(ringColor.opacity(colorScheme == .dark ? 0.3 : 0.4), lineWidth: outerRingWidth * 0.95)
//                .frame(width: innerRingSize, height: innerRingSize)
//                .scaleEffect(innerPulseScale)
//            
//            // Core fill - адаптивный фон
//            Circle()
//                .fill(backgroundColor)
//                .frame(width: coreSize, height: coreSize)
//                .shadow(color: ringColor.opacity(colorScheme == .dark ? 0.2 : 0.15), radius: 2, x: 0, y: 1)
//            
//            // Day number text
//            Text(dayText)
//                .font(.system(size: dayFontSize, weight: .heavy))
//                .foregroundColor(textColor)
//        }
//        .frame(width: size, height: size)
//        .shadow(color: ringColor.opacity(colorScheme == .dark ? 0.25 : 0.2), radius: 4, x: 0, y: 1.5)
//        .onAppear { updatePulse() }
//        .onChange(of: isSelected) { _, _ in updatePulse() }
//        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isSelected)
//    }
//    
//    private var pulseScale: CGFloat {
//        guard shouldPulse else { return 1.0 }
//        return pulse ? 1.08 : 0.96
//    }
//    
//    private var innerPulseScale: CGFloat {
//        guard shouldPulse else { return 1.0 }
//        return pulse ? 1.03 : 0.98
//    }
//    
//    private func updatePulse() {
//        guard shouldPulse else {
//            pulse = false
//            return
//        }
//        pulse = false
//        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
//            pulse = true
//        }
//    }
//    
//    private var shouldPulse: Bool { isSelected }
//}

// MARK: - Compact Day View
struct CompactDayView: View {
    let date: Date
    let isSelected: Bool
    var todayIndicatorColor: Color = Color.accentColor
    private let hapticManager = HapticSoundManager.shared

    /// Минимальная ширина столбца как у двух цифр (1–9 не уже, чем 10–31)
    private static let dayColumnMinWidth: CGFloat = 26
    private static let selectedDayStrokeWidth: CGFloat = 1

    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }
    
    private var weekdayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter
    }
    
    private var weekdayAbbreviation: String {
        let fullAbbr = weekdayFormatter.string(from: date)
        guard !fullAbbr.isEmpty else { return "" }
        // Возвращаем первые 2 буквы (MO, TU, WE и т.д.)
        return String(fullAbbr.prefix(2)).uppercased()
    }
    
    private var isToday: Bool {
        Calendar.current.isDate(date, inSameDayAs: .now)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 2) {
                Text(weekdayAbbreviation)
                    .font(.system(size: 10, weight: .semibold, design: .default))
                    .foregroundColor(.primary)

                // Точка — только «сегодня»; фиксированная высота для выравнивания столбцов
                ZStack {
                    if isToday {
                        Circle()
                            .fill(todayIndicatorColor)
                            .frame(width: 5, height: 5)
                    }
                }
                .frame(height: 6)

                Text(dayFormatter.string(from: date))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.primary)
            }
            .frame(minWidth: Self.dayColumnMinWidth)
            // Узкая вертикальная капсула у выбранного дня — минимальный отступ по бокам, как на макете
            .padding(.horizontal, isSelected ? 3 : 4)
            .padding(.vertical, 4)
            .background {
                if isSelected {
                    Capsule(style: .continuous)
                        .stroke(Color.primary, lineWidth: Self.selectedDayStrokeWidth)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .animation(nil, value: isSelected)
        .transaction { $0.disablesAnimations = true }
    }
}

// MARK: - Calendar Toggle Button
struct CalendarToggleButton: View {
    @Binding var isVisible: Bool
    @Binding var selectedDate: Date
    
    private let hapticManager = HapticSoundManager.shared
    
    var body: some View {
        Button(action: {
            hapticManager.selectionChanged()
            withAnimation(.easeInOut(duration: 0.3)) {
                isVisible.toggle()
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.system(size: 12, weight: .medium))
                
                Text(dayFormatter.string(from: selectedDate))
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(isVisible ? .accentColor : .primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isVisible ? Color.accentColor.opacity(0.1) : Color.gray.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
    }
    
    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }
}

// MARK: - Calendar Manager
class CalendarManager: ObservableObject {
    @Published var selectedDate: Date
    @Published var weekStartDate: Date
    @Published var isVisible: Bool = true
    
    private let hapticManager = HapticSoundManager.shared
    
    init() {
        let cal = Calendar.current
        let now = Date()
        selectedDate = cal.startOfDay(for: now)
        weekStartDate = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
    }
    
    /// Вызывать при смене корневой вкладки: неактивные экраны могли не перерисоваться, из‑за чего на кадр мелькала старая обводка дня.
    func refreshObservationForTabChange() {
        objectWillChange.send()
    }
    
    func toggleCalendar() {
        hapticManager.selectionChanged()
        withAnimation(.easeInOut(duration: 0.3)) {
            isVisible.toggle()
        }
    }
    
    func selectDate(_ date: Date) {
        hapticManager.selectionChanged()
        var txn = Transaction()
        txn.disablesAnimations = true
        withTransaction(txn) {
            selectedDate = Calendar.current.startOfDay(for: date)
        }
    }
    
    func goToToday() {
        hapticManager.selectionChanged()
        let cal = Calendar.current
        let now = Date()
        var txn = Transaction()
        txn.disablesAnimations = true
        withTransaction(txn) {
            selectedDate = cal.startOfDay(for: now)
            weekStartDate = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        }
    }
}
