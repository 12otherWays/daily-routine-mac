import SwiftUI

// MARK: - Calendar Drawer

struct CalendarDrawerView: View {
    @EnvironmentObject var store: AppStore
    @State private var mode: CalendarDrawerMode = .month
    @State private var hoveredMode: CalendarDrawerMode? = nil
    @State private var anchorMonth: Date = {
        let comps = Calendar.current.dateComponents([.year, .month], from: Date())
        return Calendar.current.date(from: comps) ?? Date()
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            drawerHeader
            Divider().background(AppColors.borderStrong)
            modeSelector
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            Divider().background(AppColors.borderWeak)
            ScrollView {
                calendarContent
                    .padding(16)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(AppColors.surface)
        .overlay(alignment: .leading) {
            Rectangle().fill(AppColors.borderStrong).frame(width: 1)
        }
        .overlay(alignment: .top) {
            Rectangle().fill(AppColors.borderStrong).frame(height: 1)
        }
    }

    // MARK: - Header

    private var periodTitle: String {
        switch mode {
        case .month:
            let f = DateFormatter(); f.dateFormat = "MMMM yyyy"
            return f.string(from: anchorMonth).uppercased()
        case .threeMonths:
            let cal = Calendar.current
            let end = cal.date(byAdding: .month, value: 2, to: anchorMonth) ?? anchorMonth
            let fs = DateFormatter(); fs.dateFormat = "MMM"
            let fe = DateFormatter(); fe.dateFormat = "MMM yyyy"
            return "\(fs.string(from: anchorMonth).uppercased()) – \(fe.string(from: end).uppercased())"
        case .year:
            let f = DateFormatter(); f.dateFormat = "yyyy"
            return f.string(from: anchorMonth)
        }
    }

    private var drawerHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("CALENDAR")
                    .eyebrow()
                Text(periodTitle)
                    .font(AppFonts.monoBold(13))
                    .kerning(0.5)
                    .foregroundColor(AppColors.ink)
            }
            Spacer()
            HStack(spacing: 4) {
                navArrow(image: "chevron.left")  { shift(by: -1) }
                navArrow(image: "chevron.right") { shift(by:  1) }
            }
            Button { store.calendarDrawerOpen = false } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.inkMuted)
                    .frame(width: 30, height: 30)
                    .background(AppColors.borderWeak)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .help("Close")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private func navArrow(image: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: image)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(AppColors.inkMuted)
                .frame(width: 26, height: 26)
                .background(AppColors.borderWeak)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Mode Selector

    private var modeSelector: some View {
        HStack(spacing: 2) {
            ForEach(CalendarDrawerMode.allCases, id: \.self) { m in
                Button { mode = m } label: {
                    Text(m.label)
                        .font(AppFonts.monoBold(10))
                        .kerning(1)
                        .foregroundColor(
                            mode == m ? AppColors.bg :
                            hoveredMode == m ? AppColors.ink : AppColors.inkMuted
                        )
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(mode == m ? AppColors.ink :
                                      hoveredMode == m ? AppColors.borderMid : Color.clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { hoveredMode = $0 ? m : nil }
            }
        }
        .padding(3)
        .background(AppColors.borderWeak)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeInOut(duration: 0.15), value: mode)
        .animation(.easeInOut(duration: 0.1), value: hoveredMode)
    }

    // MARK: - Calendar Content

    @ViewBuilder
    private var calendarContent: some View {
        // Single cheap fetch of the active-day set, shared across all rendered
        // months. Avoids hitting the repository per-cell.
        let activeDays = store.daysWithTasks()
        switch mode {
        case .month:
            CalendarMonthGrid(
                anchorDate: anchorMonth,
                daysWithTasks: activeDays,
                activeDay: store.activeDay,
                onSelect: selectDay
            )

        case .threeMonths:
            VStack(spacing: 20) {
                ForEach(0..<3, id: \.self) { offset in
                    let m = Calendar.current.date(byAdding: .month, value: offset, to: anchorMonth) ?? anchorMonth
                    CalendarMonthGrid(
                        anchorDate: m,
                        daysWithTasks: activeDays,
                        activeDay: store.activeDay,
                        onSelect: selectDay
                    )
                    if offset < 2 {
                        Rectangle().fill(AppColors.borderWeak).frame(height: 1)
                    }
                }
            }

        case .year:
            let year = Calendar.current.component(.year, from: anchorMonth)
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
                spacing: 18
            ) {
                ForEach(1...12, id: \.self) { month in
                    MiniMonthView(
                        year: year,
                        month: month,
                        daysWithTasks: activeDays,
                        activeDay: store.activeDay,
                        onSelect: selectDay
                    )
                }
            }
        }
    }

    // MARK: - Actions

    private func selectDay(_ key: String) {
        store.activeDay = key
        store.viewMode = .day
        store.calendarDrawerOpen = false
    }

    private func shift(by amount: Int) {
        let cal = Calendar.current
        switch mode {
        case .month:
            anchorMonth = cal.date(byAdding: .month, value: amount, to: anchorMonth) ?? anchorMonth
        case .threeMonths:
            anchorMonth = cal.date(byAdding: .month, value: amount * 3, to: anchorMonth) ?? anchorMonth
        case .year:
            anchorMonth = cal.date(byAdding: .year, value: amount, to: anchorMonth) ?? anchorMonth
        }
    }
}

// MARK: - Mode Enum

enum CalendarDrawerMode: String, CaseIterable {
    case month, threeMonths, year
    var label: String {
        switch self {
        case .month:       "MONTH"
        case .threeMonths: "3 MONTHS"
        case .year:        "YEAR"
        }
    }
}

// MARK: - Full Month Grid (Month & 3-Month modes)

struct CalendarMonthGrid: View {
    let anchorDate: Date
    let daysWithTasks: Set<String>
    let activeDay: String
    let onSelect: (String) -> Void

    private let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]

    private var monthTitle: String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"
        return f.string(from: anchorDate).uppercased()
    }

    private var weeks: [[String?]] {
        let cal = Calendar.current
        return calendarWeeks(
            year: cal.component(.year, from: anchorDate),
            month: cal.component(.month, from: anchorDate)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(monthTitle)
                .font(AppFonts.monoBold(11))
                .kerning(1.2)
                .foregroundColor(AppColors.ink)
                .padding(.bottom, 2)

            HStack(spacing: 0) {
                ForEach(dayLabels.indices, id: \.self) { i in
                    Text(dayLabels[i])
                        .font(AppFonts.mono(9))
                        .kerning(0.5)
                        .foregroundColor(AppColors.inkFaint)
                        .frame(maxWidth: .infinity)
                }
            }

            ForEach(weeks.indices, id: \.self) { w in
                HStack(spacing: 0) {
                    ForEach(weeks[w].indices, id: \.self) { d in
                        CalDayCell(
                            dayKey:    weeks[w][d],
                            hasTasks:  weeks[w][d].map { daysWithTasks.contains($0) } ?? false,
                            isActive:  weeks[w][d] == activeDay,
                            isToday:   weeks[w][d] == todayKey(),
                            height:    34,
                            fontSize:  11,
                            dotSize:   5,
                            radius:    4,
                            onSelect:  onSelect
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Mini Month (Year mode)

struct MiniMonthView: View {
    let year: Int
    let month: Int
    let daysWithTasks: Set<String>
    let activeDay: String
    let onSelect: (String) -> Void

    private let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]

    private var monthName: String {
        let f = DateFormatter(); f.dateFormat = "MMM"
        var c = DateComponents(); c.year = year; c.month = month; c.day = 1
        return f.string(from: Calendar.current.date(from: c) ?? Date()).uppercased()
    }

    private var weeks: [[String?]] { calendarWeeks(year: year, month: month) }

    var body: some View {
        VStack(spacing: 2) {
            Text(monthName)
                .font(AppFonts.monoBold(9))
                .kerning(1)
                .foregroundColor(AppColors.ink)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 0) {
                ForEach(dayLabels.indices, id: \.self) { i in
                    Text(String(dayLabels[i]))
                        .font(AppFonts.mono(7))
                        .foregroundColor(AppColors.inkFaint)
                        .frame(maxWidth: .infinity)
                }
            }

            ForEach(weeks.indices, id: \.self) { w in
                HStack(spacing: 0) {
                    ForEach(weeks[w].indices, id: \.self) { d in
                        CalDayCell(
                            dayKey:   weeks[w][d],
                            hasTasks: weeks[w][d].map { daysWithTasks.contains($0) } ?? false,
                            isActive: weeks[w][d] == activeDay,
                            isToday:  weeks[w][d] == todayKey(),
                            height:   16,
                            fontSize: 8,
                            dotSize:  3,
                            radius:   2,
                            onSelect: onSelect
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Day Cell

struct CalDayCell: View {
    let dayKey: String?
    let hasTasks: Bool
    let isActive: Bool
    let isToday: Bool
    let height: CGFloat
    let fontSize: CGFloat
    let dotSize: CGFloat
    let radius: CGFloat
    let onSelect: (String) -> Void

    @State private var isHovered = false

    private var label: String {
        guard let key = dayKey else { return "" }
        let f = DateFormatter(); f.dateFormat = "d"
        return f.string(from: date(from: key))
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let key = dayKey {
                Button { onSelect(key) } label: {
                    Text(label)
                        .font(isActive
                            ? Font.custom("JetBrains Mono", size: fontSize).weight(.semibold)
                            : Font.custom("JetBrains Mono", size: fontSize))
                        .foregroundColor(
                            isActive  ? AppColors.bg :
                            isHovered ? AppColors.ink :
                            isToday   ? AppColors.accent : AppColors.inkMuted
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: radius)
                                .fill(isActive  ? AppColors.ink :
                                      isHovered ? AppColors.borderWeak : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .onHover { isHovered = $0 }

                if hasTasks {
                    Circle()
                        .fill(isActive ? AppColors.bg.opacity(0.8) : Color(hex: "dc2626"))
                        .frame(width: dotSize, height: dotSize)
                        .padding(.top,      dotSize * 0.5)
                        .padding(.trailing, dotSize * 0.5)
                }
            } else {
                Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
    }
}

// MARK: - Shared week-builder

private func calendarWeeks(year: Int, month: Int) -> [[String?]] {
    var cal = Calendar.current
    cal.firstWeekday = 2
    var comps = DateComponents(); comps.year = year; comps.month = month
    guard let first = cal.date(from: comps),
          let range = cal.range(of: .day, in: .month, for: first) else { return [] }
    let leadingBlanks = (cal.component(.weekday, from: first) - 2 + 7) % 7
    var cells: [String?] = Array(repeating: nil, count: leadingBlanks)
    for day in range {
        var c = comps; c.day = day
        if let d = cal.date(from: c) { cells.append(dateKey(from: d)) }
    }
    while cells.count % 7 != 0 { cells.append(nil) }
    return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<$0+7]) }
}
