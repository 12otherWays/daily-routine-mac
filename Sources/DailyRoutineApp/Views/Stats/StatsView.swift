import SwiftUI
import Charts

struct StatsView: View {
    @EnvironmentObject var store: AppStore

    // Single fetch of the lightweight `TaskRecord` projection — cached by AppStore
    // and invalidated whenever a write happens, so this is essentially free to read.
    private var stats: StatsInput { store.statsInput() }

    private var streak: Int    { computeStreak(stats) }
    private var longest: Int   { computeLongestStreak(stats) }
    private var perfect: Int   { computePerfectDays(stats) }
    private var rate: Double   { overallCompletionRate(stats) }
    private var last30: [(key: String, rate: Double, total: Int)] { completionByDay(stats, count: 30) }
    private var byWeekday: [Int: Double] { completionByWeekday(stats) }
    private var byCategory: [(category: String, done: Int, total: Int)] { completionByCategory(stats) }

    private let weekdayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {

            // KPI cards row
            HStack(spacing: 16) {
                StatCard(label: "Current streak", value: "\(streak)", unit: streak == 1 ? "day" : "days",
                         primary: streak >= 7, systemImage: streak > 0 ? "flame.fill" : "flame")
                StatCard(label: "Best streak", value: "\(longest)", unit: longest == 1 ? "day" : "days")
                StatCard(label: "Perfect days", value: "\(perfect)")
                StatCard(label: "Completion rate", value: "\(Int(rate * 100))", unit: "%")
            }

            // 30-day bar chart
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("30-DAY COMPLETION")

                if last30.isEmpty || last30.allSatisfy({ $0.total == 0 }) {
                    noDataLabel
                } else {
                    Chart(last30, id: \.key) { item in
                        BarMark(
                            x: .value("Date", shortDate(item.key)),
                            y: .value("Rate", item.total == 0 ? 0 : item.rate * 100)
                        )
                        .foregroundStyle(item.rate >= 1.0 ? AppColors.ink : AppColors.inkMuted.opacity(0.5))
                        .cornerRadius(2)
                    }
                    .chartYScale(domain: 0...100)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: 7)) { value in
                            AxisValueLabel {
                                if let s = value.as(String.self) {
                                    Text(s).font(AppFonts.mono(9)).foregroundStyle(AppColors.inkFaint)
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading, values: [0, 50, 100]) { value in
                            AxisValueLabel {
                                if let v = value.as(Double.self) {
                                    Text("\(Int(v))%").font(AppFonts.mono(9)).foregroundStyle(AppColors.inkFaint)
                                }
                            }
                            AxisGridLine().foregroundStyle(AppColors.borderWeak)
                        }
                    }
                    .frame(height: 160)
                    .chartBackground { _ in AppColors.bg }
                }
            }
            .chartContainer

            // Weekday chart
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("BY DAY OF WEEK")

                if byWeekday.isEmpty {
                    noDataLabel
                } else {
                    Chart {
                        ForEach(0..<7, id: \.self) { idx in
                            let rate = byWeekday[idx] ?? 0
                            BarMark(
                                x: .value("Rate", rate * 100),
                                y: .value("Day", weekdayLabels[idx])
                            )
                            .foregroundStyle(rate >= 0.8 ? AppColors.ink : AppColors.inkMuted.opacity(0.5))
                            .cornerRadius(2)
                        }
                    }
                    .chartXScale(domain: 0...100)
                    .chartXAxis {
                        AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                            AxisValueLabel {
                                if let v = value.as(Double.self) {
                                    Text("\(Int(v))%").font(AppFonts.mono(9)).foregroundStyle(AppColors.inkFaint)
                                }
                            }
                            AxisGridLine().foregroundStyle(AppColors.borderWeak)
                        }
                    }
                    .chartYAxis {
                        AxisMarks { value in
                            AxisValueLabel {
                                if let s = value.as(String.self) {
                                    Text(s).font(AppFonts.mono(10)).foregroundStyle(AppColors.inkMuted)
                                }
                            }
                        }
                    }
                    .frame(height: 200)
                    .chartBackground { _ in AppColors.bg }
                }
            }
            .chartContainer

            // Activity heatmap
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("12-WEEK ACTIVITY")
                ActivityHeatmap(recordsByDay: stats.recordsByDay)
            }
            .chartContainer

            // Category breakdown
            if !byCategory.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader("BY CATEGORY")
                    CategoryBreakdown(data: byCategory)
                }
                .chartContainer
            }

            Spacer(minLength: 40)
        }
        .padding(.bottom, 32)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .eyebrow()
    }

    private var noDataLabel: some View {
        Text("No data yet")
            .font(AppFonts.mono(12))
            .foregroundColor(AppColors.inkFaint)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 24)
    }

    private func shortDate(_ key: String) -> String {
        let d = date(from: key)
        let f = DateFormatter(); f.dateFormat = "M/d"
        return f.string(from: d)
    }
}

// MARK: - Activity Heatmap (12 weeks × 7 days)

private struct ActivityHeatmap: View {
    let recordsByDay: [String: [TaskRecord]]
    @State private var hoveredKey: String? = nil

    private var weeks: [[String]] {
        var cal = Calendar.current
        cal.firstWeekday = 2
        let today = cal.startOfDay(for: Date())
        // Find the Monday 11 weeks ago
        let todayWeekday = cal.component(.weekday, from: today)
        let daysFromMon = (todayWeekday - 2 + 7) % 7
        guard let thisMonday = cal.date(byAdding: .day, value: -daysFromMon, to: today),
              let startMonday = cal.date(byAdding: .weekOfYear, value: -11, to: thisMonday)
        else { return [] }

        return (0..<12).map { weekOffset in
            (0..<7).compactMap { dayOffset -> String? in
                let base = cal.date(byAdding: .weekOfYear, value: weekOffset, to: startMonday)
                return base.flatMap { cal.date(byAdding: .day, value: dayOffset, to: $0) }
                    .map { dateKey(from: $0) }
            }
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            // Weekday labels
            VStack(spacing: 4) {
                ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { label in
                    Text(label)
                        .font(AppFonts.mono(9))
                        .foregroundColor(AppColors.inkFaint)
                        .frame(width: 12, height: 14)
                }
            }
            // Week columns
            HStack(alignment: .top, spacing: 4) {
                ForEach(weeks.indices, id: \.self) { wi in
                    VStack(spacing: 4) {
                        ForEach(weeks[wi], id: \.self) { key in
                            heatCell(for: key)
                        }
                    }
                }
            }
        }
    }

    private func heatCell(for key: String) -> some View {
        let tasks = recordsByDay[key] ?? []
        let rate: Double = tasks.isEmpty ? 0 : Double(tasks.filter(\.done).count) / Double(tasks.count)
        let cellColor: Color = tasks.isEmpty ? AppColors.borderWeak :
            (rate >= 1.0 ? AppColors.ink :
             rate >= 0.5 ? AppColors.inkMuted.opacity(0.5) :
             AppColors.inkFaint.opacity(0.3))

        return Rectangle()
            .fill(key == todayKey() ? AppColors.accent : cellColor)
            .frame(width: 14, height: 14)
            .clipShape(RoundedRectangle(cornerRadius: 2))
            .help(tasks.isEmpty
                  ? key
                  : "\(key): \(tasks.filter(\.done).count)/\(tasks.count) done")
    }
}

// MARK: - Category Breakdown

private struct CategoryBreakdown: View {
    let data: [(category: String, done: Int, total: Int)]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(data.prefix(8), id: \.category) { item in
                HStack(spacing: 10) {
                    Text(item.category)
                        .font(AppFonts.mono(11))
                        .foregroundColor(AppColors.inkMuted)
                        .frame(width: 100, alignment: .leading)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(AppColors.borderWeak)
                                .frame(height: 12)
                                .clipShape(RoundedRectangle(cornerRadius: 2))
                            Rectangle()
                                .fill(AppColors.ink)
                                .frame(width: item.total == 0 ? 0 : CGFloat(item.done) / CGFloat(item.total) * geo.size.width, height: 12)
                                .clipShape(RoundedRectangle(cornerRadius: 2))
                        }
                    }
                    .frame(height: 12)

                    Text("\(item.done)/\(item.total)")
                        .font(AppFonts.mono(10))
                        .foregroundColor(AppColors.inkFaint)
                        .frame(width: 50, alignment: .trailing)
                }
            }
        }
    }
}

// MARK: - Chart container modifier

private extension View {
    var chartContainer: some View {
        self
            .padding(20)
            .background(AppColors.surface)
            .overlay(RoundedRectangle(cornerRadius: 0).stroke(AppColors.borderMid, lineWidth: 1))
    }
}
