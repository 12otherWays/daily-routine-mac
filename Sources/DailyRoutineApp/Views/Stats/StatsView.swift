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
                StatCard(label: "Best streak", value: "\(longest)", unit: longest == 1 ? "day" : "days",
                         systemImage: "trophy.fill",
                         iconColors: [Color(hex: "fbbf24"), Color(hex: "d97706")])
                StatCard(label: "Perfect days", value: "\(perfect)",
                         systemImage: "star.fill",
                         iconColors: [Color(hex: "a78bfa"), Color(hex: "7c3aed")])
                StatCard(label: "Completion rate", value: "\(Int(rate * 100))", unit: "%",
                         systemImage: "chart.pie.fill",
                         iconColors: [Color(hex: "34d399"), Color(hex: "059669")])
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
                    // Domain padded a touch past 100 so the top "100%" label
                    // renders fully below the top edge instead of being clipped.
                    .chartYScale(domain: 0...106)
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
                        AxisMarks(position: .leading, values: [0, 25, 50, 75, 100]) { value in
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

            // Activity heatmap
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader("ACTIVITY")
                ContributionHeatmap(stats: stats, categories: store.categories)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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

// MARK: - Contribution Heatmap (rolling 12-month grid + filters)

private struct ContributionHeatmap: View {
    let stats: StatsInput
    let categories: [String]

    // Date whose week anchors the right edge of the grid. Defaults to today;
    // arrows shift it ±12 months (one full window).
    @State private var endDate: Date = Date()
    @State private var category: String? = nil          // nil = all categories
    @State private var stateFilter: HeatStateFilter = .all
    @State private var availableWidth: CGFloat = 0      // measured card inner width

    private let weekCount = 52               // ~12 months; cells size to fill the grid column
    private let gap: CGFloat = 6
    private let labelW: CGFloat = 34
    private let weekdayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    // Square cell sized so the weekday-label gutter + columns exactly fill the
    // measured width. Card height follows from this (7 · cell + gaps).
    private var cell: CGFloat {
        guard availableWidth > 0 else { return 16 }
        let columnGaps = gap * CGFloat(weekCount - 1)
        let avail = availableWidth - labelW - gap - columnGaps
        return max(8, avail / CGFloat(weekCount))
    }

    private var weeks: [[HeatCell]] {
        heatmapWeeks(stats, endDate: endDate, weeks: weekCount,
                     category: category, stateFilter: stateFilter)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            topBar

            // Grid spans the full card width; its measured width drives cell size.
            grid
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: HeatWidthKey.self, value: geo.size.width)
                    }
                )
                .onPreferenceChange(HeatWidthKey.self) { availableWidth = $0 }
        }
    }

    // MARK: Top control bar — legend (left) · filters + range/nav (right), one line

    private var topBar: some View {
        HStack(alignment: .center, spacing: 16) {
            // Legend on top, laid out horizontally
            HStack(spacing: 14) {
                legendItem(color(for: .empty), "No tasks")
                legendItem(color(for: .partial), "Tasks added")
                legendItem(color(for: .done), "All done")
            }

            Spacer(minLength: 16)

            // Category + state filters
            Menu {
                Button("All categories") { category = nil }
                Divider()
                ForEach(categories, id: \.self) { cat in
                    Button(cat) { category = cat }
                }
            } label: {
                filterLabel(text: category ?? "All categories", icon: "tag")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()

            Menu {
                ForEach(HeatStateFilter.allCases, id: \.self) { f in
                    Button(f.rawValue) { stateFilter = f }
                }
            } label: {
                filterLabel(text: stateFilter.rawValue, icon: "line.3.horizontal.decrease")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()

            // Range label + prev/next, all on the same line
            Text(rangeLabel)
                .font(AppFonts.monoBold(11))
                .foregroundColor(AppColors.ink)
                .fixedSize()
            HStack(spacing: 8) {
                navButton("chevron.left") { shiftMonths(-12) }
                navButton("chevron.right", disabled: atPresent) { shiftMonths(12) }
            }
        }
    }

    private func navButton(_ icon: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(disabled ? AppColors.inkFaint : AppColors.inkMuted)
                .frame(width: 22, height: 22)
                .background(AppColors.bg)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(AppColors.borderMid))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    private func filterLabel(text: String, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 9))
            Text(text).font(AppFonts.mono(10)).kerning(0.3)
        }
        .foregroundColor(AppColors.ink)
        .padding(.horizontal, 10)
        .frame(height: 22)
        .background(AppColors.bg)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(AppColors.borderMid))
    }

    // MARK: Grid

    private var grid: some View {
        VStack(alignment: .leading, spacing: gap) {
            monthLabels
            HStack(alignment: .top, spacing: gap) {
                // Weekday labels — all 7 rows, three-letter names
                VStack(spacing: gap) {
                    ForEach(weekdayNames, id: \.self) { label in
                        Text(label)
                            .font(AppFonts.mono(8))
                            .foregroundColor(AppColors.inkFaint)
                            .frame(width: labelW, height: cell, alignment: .trailing)
                    }
                }
                ForEach(weeks.indices, id: \.self) { wi in
                    VStack(spacing: gap) {
                        ForEach(weeks[wi], id: \.key) { c in
                            heatCell(c)
                        }
                    }
                }
            }
        }
    }

    private var monthLabels: some View {
        HStack(spacing: gap) {
            Color.clear.frame(width: labelW, height: 10)
            ForEach(weeks.indices, id: \.self) { wi in
                Text(monthLabel(at: wi))
                    .font(AppFonts.mono(8))
                    .foregroundColor(AppColors.inkFaint)
                    .frame(width: cell, height: 10, alignment: .leading)
                    .fixedSize()
            }
        }
    }

    private func monthLabel(at wi: Int) -> String {
        guard let key = weeks[wi].first?.key, !key.isEmpty else { return "" }
        let cal = Calendar.current
        let month = cal.component(.month, from: date(from: key))
        // Show the month name only on the first column of each new month.
        if wi == 0 { return shortMonth(month) }
        if let prevKey = weeks[wi - 1].first?.key,
           cal.component(.month, from: date(from: prevKey)) == month {
            return ""
        }
        return shortMonth(month)
    }

    private func heatCell(_ c: HeatCell) -> some View {
        let isToday = c.key == todayKey()
        return RoundedRectangle(cornerRadius: 3)
            .fill(color(for: c.state))
            .frame(width: cell, height: cell)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(isToday ? AppColors.accent : Color.clear, lineWidth: 1.5)
            )
            .help(c.total == 0 ? c.key : "\(c.key) · \(c.done)/\(c.total) done")
    }

    private func color(for state: HeatState) -> Color {
        switch state {
        case .empty:   AppColors.borderWeak        // grey — a day with no tasks
        case .partial: AppColors.inkFaint          // light grey — tasks written
        case .done:    AppColors.ink               // dark grey — all completed
        }
    }

    // MARK: Legend

    private func legendItem(_ c: Color, _ label: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3).fill(c).frame(width: 11, height: 11)
            Text(label).font(AppFonts.mono(9)).foregroundColor(AppColors.inkMuted)
        }
    }

    // MARK: Window math

    private var atPresent: Bool {
        Calendar.current.isDate(endDate, equalTo: Date(), toGranularity: .day) ||
        endDate > Date()
    }

    private func shiftMonths(_ months: Int) {
        let cal = Calendar.current
        guard let shifted = cal.date(byAdding: .month, value: months, to: endDate) else { return }
        endDate = min(shifted, cal.startOfDay(for: Date()).addingTimeInterval(86_399))
    }

    private var rangeLabel: String {
        guard let first = weeks.first?.first?.key, !first.isEmpty,
              let last = weeks.last?.last?.key, !last.isEmpty else { return "" }
        let f = DateFormatter(); f.dateFormat = "MMM yyyy"
        let start = f.string(from: date(from: first))
        let end = f.string(from: date(from: last))
        return start == end ? start : "\(start) – \(end)"
    }

    private func shortMonth(_ m: Int) -> String {
        let names = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
        return (1...12).contains(m) ? names[m - 1] : ""
    }
}

// Measures the heatmap card's inner width so cells can be sized to fill it.
private struct HeatWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
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
