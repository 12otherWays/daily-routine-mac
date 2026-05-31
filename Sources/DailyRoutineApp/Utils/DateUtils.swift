import Foundation

private let isoFmt: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.locale = Locale(identifier: "en_US_POSIX")
    return f
}()

func todayKey() -> String {
    isoFmt.string(from: Date())
}

func dateKey(from date: Date) -> String {
    isoFmt.string(from: date)
}

func date(from key: String) -> Date {
    isoFmt.date(from: key) ?? Date()
}

// Returns 8 day keys: 4 past + today + 3 upcoming
func buildDayTabs() -> [String] {
    let cal = Calendar.current
    let today = cal.startOfDay(for: Date())
    return (-4...3).compactMap { offset in
        cal.date(byAdding: .day, value: offset, to: today).map { dateKey(from: $0) }
    }
}

// Returns Mon–Sun keys for the week containing the given day key
func getWeekDays(for dayKey: String) -> [String] {
    var cal = Calendar.current
    cal.firstWeekday = 2 // Monday
    let d = date(from: dayKey)
    let weekday = cal.component(.weekday, from: d)
    let daysFromMonday = (weekday - cal.firstWeekday + 7) % 7
    guard let monday = cal.date(byAdding: .day, value: -daysFromMonday, to: d) else { return [] }
    return (0..<7).compactMap { offset in
        cal.date(byAdding: .day, value: offset, to: monday).map { dateKey(from: $0) }
    }
}

// Returns all day keys in the month containing the given day key
func getMonthDays(for dayKey: String) -> [String] {
    let cal = Calendar.current
    let d = date(from: dayKey)
    let comps = cal.dateComponents([.year, .month], from: d)
    guard let firstOfMonth = cal.date(from: comps),
          let range = cal.range(of: .day, in: .month, for: firstOfMonth) else { return [] }
    return range.compactMap { day -> String? in
        var c = comps
        c.day = day
        return cal.date(from: c).map { dateKey(from: $0) }
    }
}

func prevDay(_ key: String) -> String {
    let cal = Calendar.current
    let d = date(from: key)
    return cal.date(byAdding: .day, value: -1, to: d).map { dateKey(from: $0) } ?? key
}

func nextDay(_ key: String) -> String {
    let cal = Calendar.current
    let d = date(from: key)
    return cal.date(byAdding: .day, value: 1, to: d).map { dateKey(from: $0) } ?? key
}

// Formats a date key for display
func formatKey(_ key: String, style: DateFormatter.Style = .long) -> String {
    let d = date(from: key)
    let f = DateFormatter()
    f.dateStyle = style
    f.timeStyle = .none
    return f.string(from: d)
}

func formatKeyShort(_ key: String) -> String {
    let d = date(from: key)
    let f = DateFormatter()
    f.dateFormat = "EEE, MMM d"
    return f.string(from: d)
}

func headerTitle(for key: String, viewMode: ViewMode) -> String {
    let d = date(from: key)
    switch viewMode {
    case .day:
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d, yyyy"
        return f.string(from: d)
    case .week:
        let days = getWeekDays(for: key)
        guard days.count == 7 else { return "This Week" }
        let start = date(from: days[0])
        let end = date(from: days[6])
        let f = DateFormatter(); f.dateFormat = "MMM d"
        return "\(f.string(from: start)) – \(f.string(from: end))"
    case .month:
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"
        return f.string(from: d)
    case .stats:
        return "Statistics"
    }
}
