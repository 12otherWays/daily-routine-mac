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
