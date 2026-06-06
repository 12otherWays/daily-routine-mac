import Foundation

// Pre-grouped projection consumed by every aggregate function on this page.
// Grouping once is cheaper than rebuilding the dictionary on every call.
struct StatsInput {
    let recordsByDay: [String: [TaskRecord]]

    init(_ records: [TaskRecord]) {
        self.recordsByDay = Dictionary(grouping: records, by: \.dayKey)
    }

    static let empty = StatsInput([])
}

// Counts consecutive fully-completed past days (today excluded by design).
func computeStreak(_ stats: StatsInput) -> Int {
    let cal = Calendar.current
    var streak = 0
    var check = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: Date())) ?? Date()
    while true {
        let key = dateKey(from: check)
        guard let tasks = stats.recordsByDay[key], !tasks.isEmpty, tasks.allSatisfy(\.done) else { break }
        streak += 1
        check = cal.date(byAdding: .day, value: -1, to: check) ?? check
    }
    return streak
}

func computeLongestStreak(_ stats: StatsInput) -> Int {
    let sorted = stats.recordsByDay.keys.sorted()
    var longest = 0, current = 0
    var prevDate: Date? = nil
    let cal = Calendar.current

    for key in sorted {
        guard let tasks = stats.recordsByDay[key], !tasks.isEmpty, tasks.allSatisfy(\.done) else {
            current = 0; prevDate = nil; continue
        }
        let d = date(from: key)
        if let prev = prevDate, cal.dateComponents([.day], from: prev, to: d).day == 1 {
            current += 1
        } else {
            current = 1
        }
        longest = max(longest, current)
        prevDate = d
    }
    return longest
}

func computePerfectDays(_ stats: StatsInput) -> Int {
    stats.recordsByDay.values.filter { !$0.isEmpty && $0.allSatisfy(\.done) }.count
}

func overallCompletionRate(_ stats: StatsInput) -> Double {
    let all = stats.recordsByDay.values.flatMap { $0 }
    guard !all.isEmpty else { return 0 }
    return Double(all.filter(\.done).count) / Double(all.count)
}

// Last `count` days oldest → newest with completion rate per day.
func completionByDay(_ stats: StatsInput, count: Int = 30) -> [(key: String, rate: Double, total: Int)] {
    let cal = Calendar.current
    let today = cal.startOfDay(for: Date())
    return (0..<count).reversed().compactMap { offset -> (String, Double, Int)? in
        guard let d = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
        let key = dateKey(from: d)
        let tasks = stats.recordsByDay[key] ?? []
        let rate = tasks.isEmpty ? 0 : Double(tasks.filter(\.done).count) / Double(tasks.count)
        return (key, rate, tasks.count)
    }
}

// Average completion rate per weekday (0 = Monday … 6 = Sunday).
func completionByWeekday(_ stats: StatsInput) -> [Int: Double] {
    var totals = [Int: (done: Int, total: Int)]()
    var cal = Calendar.current
    cal.firstWeekday = 2

    for (key, tasks) in stats.recordsByDay {
        guard !tasks.isEmpty else { continue }
        let d = date(from: key)
        let weekday = cal.component(.weekday, from: d)
        let idx = (weekday - 2 + 7) % 7
        let prev = totals[idx] ?? (0, 0)
        totals[idx] = (prev.done + tasks.filter(\.done).count, prev.total + tasks.count)
    }

    return totals.mapValues { pair in
        pair.total == 0 ? 0 : Double(pair.done) / Double(pair.total)
    }
}

// MARK: - Contribution heatmap

// Per-day state used to colour a heatmap cell.
enum HeatState { case empty, partial, done }

// Optional "only show…" filter applied on top of the colour mapping.
// Non-matching days collapse back to `.empty` so they read as inactive.
enum HeatStateFilter: String, CaseIterable {
    case all     = "All days"
    case perfect = "Perfect only"
    case misses  = "Has misses"
}

struct HeatCell: Hashable {
    let key: String        // yyyy-MM-dd, or "" for padding cells outside the range
    let state: HeatState
    let done: Int
    let total: Int
}

// Builds a Monday-aligned week grid (`weeks` columns × 7 rows) ending in the
// week that contains `endDate`. Each cell reflects that day's tasks, optionally
// narrowed to a single `category`, then run through `stateFilter`.
func heatmapWeeks(_ stats: StatsInput,
                  endDate: Date,
                  weeks: Int = 26,
                  category: String? = nil,
                  stateFilter: HeatStateFilter = .all) -> [[HeatCell]] {
    var cal = Calendar.current
    cal.firstWeekday = 2
    let end = cal.startOfDay(for: endDate)
    let endWeekday = cal.component(.weekday, from: end)
    let daysFromMon = (endWeekday - 2 + 7) % 7
    guard let thisMonday = cal.date(byAdding: .day, value: -daysFromMon, to: end),
          let startMonday = cal.date(byAdding: .weekOfYear, value: -(weeks - 1), to: thisMonday)
    else { return [] }

    return (0..<weeks).map { weekOffset in
        (0..<7).compactMap { dayOffset -> HeatCell? in
            guard let base = cal.date(byAdding: .weekOfYear, value: weekOffset, to: startMonday),
                  let d = cal.date(byAdding: .day, value: dayOffset, to: base)
            else { return nil }
            let key = dateKey(from: d)
            var tasks = stats.recordsByDay[key] ?? []
            if let category { tasks = tasks.filter { $0.category == category } }

            let total = tasks.count
            let done = tasks.filter(\.done).count
            var state: HeatState = total == 0 ? .empty : (done == total ? .done : .partial)
            switch stateFilter {
            case .all:     break
            case .perfect: if state != .done    { state = .empty }
            case .misses:  if state != .partial { state = .empty }
            }
            return HeatCell(key: key, state: state, done: done, total: total)
        }
    }
}

// Distinct years that contain at least one task, newest first, always including
// the current year so the year-jump menu is never empty.
func yearsWithData(_ stats: StatsInput) -> [Int] {
    let cal = Calendar.current
    var years = Set(stats.recordsByDay.keys.map { cal.component(.year, from: date(from: $0)) })
    years.insert(cal.component(.year, from: Date()))
    return years.sorted(by: >)
}

// Completion rate per category, busiest first.
func completionByCategory(_ stats: StatsInput) -> [(category: String, done: Int, total: Int)] {
    var map = [String: (done: Int, total: Int)]()
    for tasks in stats.recordsByDay.values {
        for task in tasks {
            let cat = task.category.isEmpty ? "Uncategorized" : task.category
            let prev = map[cat] ?? (0, 0)
            map[cat] = (prev.done + (task.done ? 1 : 0), prev.total + 1)
        }
    }
    return map.map { (category: $0.key, done: $0.value.done, total: $0.value.total) }
        .sorted { $0.total > $1.total }
}
