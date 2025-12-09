import SwiftUI
import SwiftData

// MARK: - Date Rectangle Icon (Rounded Rectangle Style)
struct DateRectangleIcon: View {
    var forcePulse: Bool = false
    
    @State private var pulse = false
    @Environment(\.colorScheme) var colorScheme
    
    private var strokeWidth: CGFloat { 3.5 }
    private var cornerRadius: CGFloat { 12 }
    
    private var ringColor: Color {
        Color.accentColor  // Accent color для пульсирующего прямоугольника
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .stroke(ringColor.opacity(colorScheme == .dark ? 0.6 : 0.8), lineWidth: strokeWidth)
            .scaleEffect(pulseScale)
            .onAppear { updatePulse() }
            .onChange(of: forcePulse) { _, _ in updatePulse() }
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: forcePulse)
    }
    
    private var pulseScale: CGFloat {
        guard shouldPulse else { return 1.0 }
        return pulse ? 1.05 : 0.98
    }
    
    private func updatePulse() {
        guard shouldPulse else {
            pulse = false
            return
        }
        pulse = false
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            pulse = true
        }
    }
    
    private var shouldPulse: Bool { forcePulse }
}

// MARK: - Compact Calendar View
struct calendarView: View {
    @Binding var selectedDate: Date
    @Binding var weekStartDate: Date
    @Binding var isVisible: Bool
    
    private let hapticManager = HapticSoundManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 6) {
                // MARK: Left selected date rectangle: month and day on same level as weekdays
                VStack(alignment: .center, spacing: 4) {
                    
                    
                    ZStack {
                        DateRectangleIcon(forcePulse: true)
                            .frame(width: 32, height: 32)
                        
                        Text(dayFormatter.string(from: selectedDate))
                            .font(.system(size: 16, weight: .semibold, design: .default))
                            .monospacedDigit()
                            .foregroundColor(.accentColor)
                    }
                    Text(monthFormatter.string(from: selectedDate).uppercased())
                        .font(.system(size: 12, weight: .semibold, design: .default))
                        .foregroundColor(.accentColor)
                    
                }
                .frame(height: 32)
                .padding(.horizontal, 8)
                //.offset(y: -1)
                .onTapGesture {
                    guard !isTodaySelected else { return }
                    hapticManager.selectionChanged()
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                        selectedDate = .now
                        weekStartDate = Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now))!
                    }
                }
                
                // MARK: Compact week strip with 7 days (Mon–Sun)
                WeekView(selectedDate: $selectedDate, weekStartDate: $weekStartDate)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
        }
        .frame(height: 60)
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
    
    private let hapticManager = HapticSoundManager.shared
    
    var body: some View {
        HStack(spacing: 0) {
            // MARK: Horizontal list of week days
            WeekDaysView(weekStartDate: weekStartDate, selectedDate: $selectedDate)
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
    private let hapticManager = HapticSoundManager.shared
    
    var body: some View {
        let days = daysOfWeek()
        return HStack(spacing: 2) {
            ForEach(Array(days.enumerated()), id: \.element) { index, date in
                // MARK: Single day cell (weekday label + day circle)
                CompactDayView(date: date, isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate))
                    .frame(maxWidth: .infinity)
//                    .overlay(
//                        // Вертикальный разделитель справа, кроме последнего элемента
//                        Group {
//                            if index < days.count - 1 {
//                                Rectangle()
//                                    .frame(width: 0.5)
//                                    .foregroundColor(Color.gray.opacity(0.2))
//                            }
//                        }
//                        , alignment: .trailing
//                    )
                    .onTapGesture {
                        hapticManager.selectionChanged()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            selectedDate = date
                        }
                    }
            }
        }
        .frame(height: 45)
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
    private let hapticManager = HapticSoundManager.shared
    
    @Environment(\.colorScheme) var colorScheme
    
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
    
    @State private var pulse = false
    
    var body: some View {
        ZStack {
            // Фон для сегодняшнего дня - закругленный прямоугольник под днем недели и цифрой (только если не выбран)
            if isToday && !isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(UIColor.tertiarySystemBackground))
                    .frame(width: 40, height: 50)
                    
            }
            
            VStack(spacing: 4) {
                // MARK: Weekday abbreviation (MON, TUE, ...) - 3 буквы
                Text(weekdayAbbreviation)
                    .font(.system(size: isSelected ? 14 : 12, weight: .semibold, design: .default))
                    .foregroundColor(isSelected ? .accentColor : (colorScheme == .dark ? .white : .black))
                
                // MARK: Day number
                if isSelected {
                    // Выбранный день - белая цифра в круге accentColor с пульсацией
                    ZStack {
                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(width: 30, height: 30)
                            .cornerRadius(8)
                            //.scaleEffect(pulse ? 1.12 : 1.0)
                        
                        Text(dayFormatter.string(from: date))
                            .font(.system(size: 16, weight: .semibold, design: .default))
                            .monospacedDigit()
                            .foregroundColor(.white)
                            //.scaleEffect(pulse ? 1.12 : 1.0)
                    }
                    .onAppear {
                        pulse = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                                pulse = true
                            }
                        }
                    }
                    .onChange(of: isSelected) { _, newValue in
                        if !newValue {
                            pulse = false
                        } else {
                            pulse = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                                    pulse = true
                                }
                            }
                        }
                    }
                } else if isToday {
                    // Сегодняшний день - черная/белая цифра как у остальных (фон уже в ZStack)
                    Text(dayFormatter.string(from: date))
                        .font(.system(size: 16, weight: .semibold, design: .default))
                        .monospacedDigit()
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .frame(width: 32, height: 32)
                } else {
                    // Обычный день - черная цифра на светлой схеме, белая на темной
                    Text(dayFormatter.string(from: date))
                        .font(.system(size: 16, weight: .semibold, design: .default))
                        .monospacedDigit()
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .frame(width: 32, height: 32)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
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
    @Published var selectedDate: Date = .now
    @Published var weekStartDate: Date = Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now))!
    @Published var isVisible: Bool = true
    
    private let hapticManager = HapticSoundManager.shared
    
    func toggleCalendar() {
        hapticManager.selectionChanged()
        withAnimation(.easeInOut(duration: 0.3)) {
            isVisible.toggle()
        }
    }
    
    func selectDate(_ date: Date) {
        hapticManager.selectionChanged()
        withAnimation {
            selectedDate = date
        }
    }
    
    func goToToday() {
        hapticManager.selectionChanged()
        withAnimation {
            selectedDate = .now
            weekStartDate = Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now))!
        }
    }
}
