import XCTest
@testable import DailyRoutineApp

final class DateUtilsTests: XCTestCase {

    func testRoundTripDateKey() {
        let key = "2026-06-06"
        XCTAssertEqual(dateKey(from: date(from: key)), key)
    }

    func testPrevNextAreInverse() {
        let key = "2026-03-15"
        XCTAssertEqual(prevDay(nextDay(key)), key)
        XCTAssertEqual(nextDay(prevDay(key)), key)
    }

    func testPrevDayCrossesMonthBoundary() {
        XCTAssertEqual(prevDay("2026-03-01"), "2026-02-28")
        XCTAssertEqual(nextDay("2026-02-28"), "2026-03-01")
    }

    func testPrevDayCrossesLeapDay() {
        // 2024 is a leap year.
        XCTAssertEqual(nextDay("2024-02-28"), "2024-02-29")
        XCTAssertEqual(nextDay("2024-02-29"), "2024-03-01")
    }

    func testBuildDayTabsReturnsEightConsecutiveDays() {
        let tabs = buildDayTabs()
        XCTAssertEqual(tabs.count, 8)
        for i in 1..<tabs.count {
            XCTAssertEqual(nextDay(tabs[i - 1]), tabs[i], "tab \(i) should follow the previous")
        }
        // Today sits at index 4 (offsets -4...3).
        XCTAssertEqual(tabs[4], todayKey())
    }

    func testGetWeekDaysIsMondayThroughSunday() {
        // 2026-06-06 is a Saturday.
        let week = getWeekDays(for: "2026-06-06")
        XCTAssertEqual(week.count, 7)
        XCTAssertEqual(week.first, "2026-06-01") // Monday
        XCTAssertEqual(week.last, "2026-06-07")  // Sunday
    }

    func testGetMonthDaysCoversWholeMonth() {
        let days = getMonthDays(for: "2026-02-15")
        XCTAssertEqual(days.count, 28) // Feb 2026, non-leap
        XCTAssertEqual(days.first, "2026-02-01")
        XCTAssertEqual(days.last, "2026-02-28")
    }
}
