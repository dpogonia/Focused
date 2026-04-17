import Foundation

// Interactor · Habits — отбор привычек на дату через `HabitLogicService` (доменная логика расписания).

// MARK: - Use Case: привычки на выбранный день
//
// Использует `HabitLogicService` для расписания (**Domain service** рядом с моделью привычки).

struct FilterHabitsUseCase {
    func execute(habits: [Habit], input: HabitsListFilterInput) -> [Habit] {
        let calendar = Calendar.current
        let normalizedSelectedDate = calendar.startOfDay(for: input.selectedDate)

        var tempHabits = habits.filter { habit in
            HabitLogicService(habit: habit).isScheduled(on: normalizedSelectedDate)
        }

        if !input.localShowArchivedHabits {
            tempHabits = tempHabits.filter { !$0.isArchived }
        }

        if !input.searchText.isEmpty {
            let lower = input.searchText.lowercased()
            tempHabits = tempHabits.filter { $0.title.lowercased().contains(lower) }
        }

        if let selectedSphereID = input.selectedSphereID {
            tempHabits = tempHabits.filter { $0.sphereID == selectedSphereID }
        }

        if let selectedTag = input.selectedTag {
            tempHabits = tempHabits.filter { $0.tags.contains(where: { $0.name == selectedTag }) }
        }

        if !input.localShowCompletedHabits {
            tempHabits = tempHabits.filter { habit in
                let status = habit.completionStatus(on: normalizedSelectedDate)
                return status == .activeHabit || status == .partialHabit
            }
        }

        tempHabits.sort { h1, h2 in
            let status1 = h1.completionStatus(on: normalizedSelectedDate)
            let status2 = h2.completionStatus(on: normalizedSelectedDate)
            if status1 != status2 {
                return status1 < status2
            }
            return h1.orderIndex < h2.orderIndex
        }

        return tempHabits
    }
}
