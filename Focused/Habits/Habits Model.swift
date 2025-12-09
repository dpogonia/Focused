import SwiftUI
import SwiftData
import AVFoundation

// MARK: - HABIT MODEL
@Model
final class Habit: Identifiable, Equatable {
    var id: UUID
    var title: String
    var colorHex: String
    var iconName: String
    var creationDate: Date
    var completions: [Completion]
    var missedHabitDates: Set<Date>
    var skippedHabitDates: Set<Date>
    var orderIndex: Int
    var repeatingRules: [RepeatingRule]
    var sphereID: UUID?
    var isPassive: Bool
    var positiveImpact: Double = 0.0
    var negativeImpact: Double = 0.0
    var requiredRepetitions: Int = 1
    
    @Relationship(deleteRule: .cascade) var tags: [Tag] = []
    
    init(title: String, colorHex: String, iconName: String = "star.fill", orderIndex: Int, creationDate: Date, initialRule: RepeatingRule, sphereID: UUID? = nil, isPassive: Bool = false, positiveImpact: Double = 0.0, negativeImpact: Double = 0.0, requiredRepetitions: Int = 1) {
        self.id = UUID()
        self.title = title
        self.colorHex = colorHex
        self.iconName = iconName
        self.creationDate = creationDate
        self.orderIndex = orderIndex
        self.completions = []
        self.missedHabitDates = []
        self.skippedHabitDates = []
        self.repeatingRules = [initialRule]
        self.sphereID = sphereID
        self.isPassive = isPassive
        self.positiveImpact = positiveImpact
        self.negativeImpact = negativeImpact
        self.requiredRepetitions = max(1, min(100, requiredRepetitions))
    }
    
    func isCompletedHabit(on date: Date) -> Bool {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        guard let completion = completions.first(where: { Calendar.current.isDate($0.date, inSameDayAs: normalizedDate) }) else { return false }
        return completion.count >= requiredRepetitions
    }
    
    func currentCompletionCount(on date: Date) -> Int {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        return completions.first(where: { Calendar.current.isDate($0.date, inSameDayAs: normalizedDate) })?.count ?? 0
    }
    
    func isMissedHabit(on date: Date) -> Bool { missedHabitDates.contains(Calendar.current.startOfDay(for: date)) }
    func isSkippedHabit(on date: Date) -> Bool { skippedHabitDates.contains(Calendar.current.startOfDay(for: date)) }
    
    func completionStatus(on date: Date) -> HabitStatus {
        if isPassive {
            if isCompletedHabit(on: date) { return .completedHabit }
            if isMissedHabit(on: date) { return .missedHabit }
            if isSkippedHabit(on: date) { return .skippedHabit }
            return .activeHabit
        } else {
            if isMissedHabit(on: date) { return .missedHabit }
            if isSkippedHabit(on: date) { return .skippedHabit }
            if isCompletedHabit(on: date) { return .completedHabit }
            if currentCompletionCount(on: date) > 0 { return .partialHabit }
            return .activeHabit
        }
    }
    
    func updateStatus(to newStatus: HabitStatus, on date: Date) {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        
        completions.removeAll { Calendar.current.isDate($0.date, inSameDayAs: normalizedDate) }
        missedHabitDates.remove(normalizedDate)
        skippedHabitDates.remove(normalizedDate)
        
        switch newStatus {
        case .completedHabit:
            if !isPassive {
                if let index = completions.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: normalizedDate) }) {
                    completions[index].count = requiredRepetitions
                } else {
                    completions.append(Completion(date: normalizedDate, count: requiredRepetitions))
                }
            } else {
                completions.append(Completion(date: normalizedDate, count: 1))
            }
        case .missedHabit:
            missedHabitDates.insert(normalizedDate)
        case .skippedHabit:
            skippedHabitDates.insert(normalizedDate)
        case .activeHabit:
            break
        case .partialHabit:
            if let index = completions.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: normalizedDate) }) {
                completions[index].count = min(completions[index].count, requiredRepetitions - 1) // Ensure it's partial
            } else {
                completions.append(Completion(date: normalizedDate, count: 1))
            }
        }
    }
    
    func incrementCompletion(on date: Date) {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        
        missedHabitDates.remove(normalizedDate)
        skippedHabitDates.remove(normalizedDate)
        
        if let index = completions.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: normalizedDate) }) {
            if !isPassive && completions[index].count < requiredRepetitions {
                completions[index].count += 1
            } else if isPassive {
                completions.remove(at: index)
            }
        } else {
            if !isPassive {
                completions.append(Completion(date: normalizedDate, count: 1))
            } else {
                completions.append(Completion(date: normalizedDate, count: 1))
            }
        }
    }
    
    func decrementCompletion(on date: Date) {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        if let index = completions.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: normalizedDate) }) {
            if completions[index].count > 1 {
                completions[index].count -= 1
            } else {
                completions.remove(at: index)
            }
        }
    }
    
    static func ==(lhs: Habit, rhs: Habit) -> Bool { lhs.id == rhs.id }
}

struct Completion: Codable, Equatable {
    let date: Date
    var count: Int
}

// MARK: - Supplements For Habits Model
enum HabitStatus: Int, Comparable {
    case activeHabit = 0, partialHabit = 1, skippedHabit = 2, missedHabit = 3, completedHabit = 4
    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

enum HabitsViewDesign: String, CaseIterable, Identifiable {
    case basic
    case colorful
    
    var id: String { self.rawValue }
}

// MARK: - Habit Logic Service
class HabitLogicService {
    private let habit: Habit
    private let calendar = Calendar.current
    
    init(habit: Habit) {
        self.habit = habit
    }
    
    func isScheduled(on date: Date) -> Bool {
        let normalizedDate = calendar.startOfDay(for: date)
        
        guard normalizedDate >= calendar.startOfDay(for: habit.creationDate) else { return false }
        
        guard let activeRule = habit.repeatingRules.last(where: { calendar.startOfDay(for: $0.startDate) <= normalizedDate }) else { return false }
        
        let weekday = calendar.component(.weekday, from: normalizedDate)
        if activeRule.weeklyFrequency.contains(weekday) { return true }
        
        let dayOfMonth = calendar.component(.day, from: normalizedDate)
        if activeRule.monthlySpecificDays.contains(dayOfMonth) { return true }
        
        return false
    }
    
    func calculateStreak(upTo date: Date) -> Int {
        var streakCount = 0
        var currentDate = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: date))!
        let normalizedCreationDate = calendar.startOfDay(for: habit.creationDate)
        
        while currentDate >= normalizedCreationDate {
            if isScheduled(on: currentDate) {
                
                if habit.isCompletedHabit(on: currentDate) {
                    streakCount += 1
                } else if habit.isSkippedHabit(on: currentDate) {
                    streakCount += 0
                } else {
                    break
                }
            }
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
        }
        return streakCount
    }
    
    func statusesForWeek(endingOn endDate: Date) -> [(Date, HabitStatus)] {
        var statuses: [(Date, HabitStatus)] = []
        
        guard let weekStartDate = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: endDate)) else {
            return []
        }
        
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: i, to: weekStartDate) {
                if calendar.compare(date, to: endDate, toGranularity: .day) != .orderedDescending {
                    if self.isScheduled(on: date) {
                        statuses.append((date, habit.completionStatus(on: date)))
                    }
                }
            }
        }
        return statuses
    }
    
    func calculateStats(from startDate: Date, upTo endDate: Date, for period: StatsPeriod) -> (pieData: PieChartData, barData: [BarChartDataPoint]) {
        var currentDate = calendar.startOfDay(for: max(startDate, habit.creationDate))
        let normalizedEndDate = calendar.startOfDay(for: endDate)
        
        var completed = 0, missed = 0, skipped = 0
        var barChartData: [Date: (completed: Int, missed: Int, skipped: Int)] = [:]
        
        guard currentDate <= normalizedEndDate else {
            return (PieChartData(completed: 0, missed: 0, skipped: 0), [])
        }
        
        while currentDate <= normalizedEndDate {
            if isScheduled(on: currentDate) {
                switch habit.completionStatus(on: currentDate) {
                case .completedHabit:
                    completed += 1
                    let keyDate = getKeyDate(for: currentDate, period: period)
                    barChartData[keyDate, default: (0, 0, 0)].completed += 1
                case .missedHabit:
                    missed += 1
                    let keyDate = getKeyDate(for: currentDate, period: period)
                    barChartData[keyDate, default: (0, 0, 0)].missed += 1
                case .skippedHabit:
                    skipped += 1
                    let keyDate = getKeyDate(for: currentDate, period: period)
                    barChartData[keyDate, default: (0, 0, 0)].skipped += 1
                case .activeHabit, .partialHabit:
                    break
                }
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        let pieData = PieChartData(completed: completed, missed: missed, skipped: skipped)
        let barData = barChartData.map { BarChartDataPoint(period: $0.key, completed: $0.value.completed, missed: $0.value.missed, skipped: $0.value.skipped) }.sorted { $0.period < $1.period }
        
        return (pieData, barData)
    }
    
    private func getKeyDate(for date: Date, period: StatsPeriod) -> Date {
        switch period {
        case .week:
            return calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!
        case .month1:
            return calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
        case .month3:
            let year = calendar.component(.year, from: date)
            let month = calendar.component(.month, from: date)
            let startMonthOfQuarter = ((month - 1) / 3) * 3 + 1
            return calendar.date(from: DateComponents(year: year, month: startMonthOfQuarter, day: 1))!
        case .month6:
            let year = calendar.component(.year, from: date)
            let month = calendar.component(.month, from: date)
            let startMonthOfHalfYear = ((month - 1) / 6) * 6 + 1
            return calendar.date(from: DateComponents(year: year, month: startMonthOfHalfYear, day: 1))!
        case .year1:
            return calendar.date(from: calendar.dateComponents([.year], from: date))!
        case .all:
            let creationYear = calendar.component(.year, from: habit.creationDate)
            let currentYear = calendar.component(.year, from: date)
            let intervalOffset = ((currentYear - creationYear) / 3) * 3
            let intervalStartYear = creationYear + intervalOffset
            return calendar.date(from: DateComponents(year: intervalStartYear, month: 1, day: 1))!
        }
    }
}

// MARK: - Habits Settings Model
@Model
final class HabitsSettings {
    var showCompletedAndSkippedHabits: Bool
    var currentDesignRawValue: String
    
    init(showCompletedAndSkippedHabits: Bool = true, currentDesign: HabitsViewDesign = .basic) {
        self.showCompletedAndSkippedHabits = showCompletedAndSkippedHabits
        self.currentDesignRawValue = currentDesign.rawValue
    }
    
    var currentDesign: HabitsViewDesign {
        get {
            return HabitsViewDesign(rawValue: currentDesignRawValue) ?? .basic
        }
        set {
            currentDesignRawValue = newValue.rawValue
        }
    }
}



