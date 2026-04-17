import XCTest
@testable import Focused

// Тесты · проверка границ архитектуры без UI: `AppEvent`, `AppFactory`, чистые use case / календарная стратегия.
// Интеграционные тесты SwiftData и UI — по мере необходимости; модуль приложения — `@testable import Focused`.

// MARK: - Этап 6: дымовые тесты архитектуры
//
// Проверяем фабрику, события и чистые use case без SwiftData, где возможно.
// Запуск: схема `Focused` → Test (`FocusedTests`). Статус этапов — `Core/ArchitectureStagesAndMap.swift`.

final class AppEventTests: XCTestCase {
    func testAllAppEventsMapToDistinctNotifications() {
        var seen = Set<Notification.Name>()
        for event in AppEvent.allCases {
            let name = event.notification
            XCTAssertFalse(seen.contains(name), "Duplicate notification for \(event)")
            seen.insert(name)
        }
        XCTAssertEqual(seen.count, AppEvent.allCases.count)
    }

    func testAppEventInitFromNotification() {
        for event in AppEvent.allCases {
            XCTAssertEqual(AppEvent(notification: event.notification), event)
        }
    }
}

final class AppFactoryTests: XCTestCase {
    func testMakeFilterGoalsUseCaseReturnsCallable() {
        let uc = AppFactory.makeFilterGoalsUseCase()
        let input = GoalsListFilterInput(
            selectedDate: Date(),
            calendarVisible: false,
            globalCalendarSettings: [],
            searchText: "",
            selectedSphereID: nil,
            selectedTag: nil,
            localShowCompletedGoals: true,
            localShowArchivedGoals: true
        )
        let result = uc.execute(goals: [], input: input)
        XCTAssertEqual(result.count, 0)
    }

    func testMakeSphereSatisfactionFacadeUsesEngine() {
        let facade = AppFactory.makeSphereSatisfactionFacade()
        XCTAssertNotNil(facade)
    }
}

final class CalendarStrategyTests: XCTestCase {
    func testGoalsCalendarFilterEmpty() {
        let f = GoalsCalendarFilter(goals: [])
        XCTAssertEqual(f.filterForDate(Date()).count, 0)
    }
}
