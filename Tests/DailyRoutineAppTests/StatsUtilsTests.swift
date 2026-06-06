import XCTest
@testable import DailyRoutineApp

final class StatsUtilsTests: XCTestCase {

    /// Day key for `offset` days from today (negative = past).
    private func dayKey(_ offset: Int) -> String {
        let cal = Calendar.current
        let d = cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: Date()))!
        return dateKey(from: d)
    }

    private func record(_ day: String, done: Bool, category: String = "Health") -> TaskRecord {
        TaskRecord(dayKey: day, done: done, category: category)
    }

    func testStreakCountsConsecutivePerfectPastDaysEndingYesterday() {
        // Yesterday and day-before-yesterday fully done; 3 days ago has a miss.
        let stats = StatsInput([
            record(dayKey(-1), done: true),
            record(dayKey(-2), done: true), record(dayKey(-2), done: true),
            record(dayKey(-3), done: true), record(dayKey(-3), done: false),
        ])
        XCTAssertEqual(computeStreak(stats), 2)
    }

    func testStreakExcludesTodayByDesign() {
        // Only today is perfect; nothing before. Streak ends yesterday => 0.
        let stats = StatsInput([record(dayKey(0), done: true)])
        XCTAssertEqual(computeStreak(stats), 0)
    }

    func testStreakIsZeroWhenYesterdayHasNoTasks() {
        let stats = StatsInput([record(dayKey(-2), done: true)])
        XCTAssertEqual(computeStreak(stats), 0)
    }

    func testLongestStreakFindsBestRun() {
        // A run of 3 perfect days, a gap, then a run of 2.
        let stats = StatsInput([
            record("2026-01-01", done: true),
            record("2026-01-02", done: true),
            record("2026-01-03", done: true),
            record("2026-01-04", done: false), // breaks the run
            record("2026-01-10", done: true),
            record("2026-01-11", done: true),
        ])
        XCTAssertEqual(computeLongestStreak(stats), 3)
    }

    func testPerfectDaysCountsFullyDoneNonEmptyDays() {
        let stats = StatsInput([
            record("2026-01-01", done: true),
            record("2026-01-02", done: true), record("2026-01-02", done: false),
            record("2026-01-03", done: true), record("2026-01-03", done: true),
        ])
        XCTAssertEqual(computePerfectDays(stats), 2) // Jan 1 and Jan 3
    }

    func testOverallCompletionRate() {
        let stats = StatsInput([
            record("2026-01-01", done: true),
            record("2026-01-01", done: false),
            record("2026-01-02", done: true),
            record("2026-01-02", done: true),
        ])
        XCTAssertEqual(overallCompletionRate(stats), 0.75, accuracy: 0.0001)
    }

    func testOverallCompletionRateEmptyIsZero() {
        XCTAssertEqual(overallCompletionRate(.empty), 0)
    }

    func testCompletionByCategoryGroupsAndSortsByVolume() {
        let stats = StatsInput([
            record("2026-01-01", done: true, category: "Work"),
            record("2026-01-01", done: false, category: "Work"),
            record("2026-01-02", done: true, category: "Work"),
            record("2026-01-02", done: true, category: "Health"),
        ])
        let result = completionByCategory(stats)
        XCTAssertEqual(result.first?.category, "Work") // busiest first
        let work = result.first { $0.category == "Work" }
        XCTAssertEqual(work?.done, 2)
        XCTAssertEqual(work?.total, 3)
    }

    func testCompletionByCategoryLabelsBlankAsUncategorized() {
        let stats = StatsInput([record("2026-01-01", done: true, category: "")])
        XCTAssertEqual(completionByCategory(stats).first?.category, "Uncategorized")
    }

    func testHeatmapWeeksShape() {
        let weeks = heatmapWeeks(.empty, endDate: date(from: "2026-06-06"), weeks: 4)
        XCTAssertEqual(weeks.count, 4)
        XCTAssertTrue(weeks.allSatisfy { $0.count == 7 })
    }
}
