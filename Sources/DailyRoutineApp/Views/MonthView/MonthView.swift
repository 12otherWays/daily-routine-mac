import SwiftUI

struct MonthView: View {
    @EnvironmentObject var store: AppStore

    private var monthDays: [String] { getMonthDays(for: store.activeDay) }
    private var monthTitle: String {
        let d = date(from: store.activeDay)
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"
        return f.string(from: d)
    }

    // Pad the grid to start on Monday
    private var paddedDays: [String?] {
        guard let first = monthDays.first else { return [] }
        var cal = Calendar.current; cal.firstWeekday = 2
        let firstDate = date(from: first)
        let weekday = cal.component(.weekday, from: firstDate)
        let leadingPad = (weekday - 2 + 7) % 7
        return Array(repeating: nil, count: leadingPad) + monthDays.map { Optional($0) }
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 1), count: 7)
    private let dayHeaders = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        VStack(spacing: 0) {
            // Weekday headers
            HStack(spacing: 0) {
                ForEach(dayHeaders, id: \.self) { h in
                    Text(h.uppercased())
                        .font(AppFonts.mono(9))
                        .kerning(1)
                        .foregroundColor(AppColors.inkMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
            }
            .background(AppColors.bg)
            .overlay(alignment: .bottom) {
                Rectangle().fill(AppColors.borderStrong).frame(height: 1)
            }

            // Calendar grid
            LazyVGrid(columns: columns, spacing: 1) {
                ForEach(Array(paddedDays.enumerated()), id: \.offset) { _, key in
                    if let key {
                        MonthDayCell(dayKey: key, isActive: key == store.activeDay) {
                            store.activeDay = key
                            store.viewMode = .day
                        }
                    } else {
                        Color.clear.frame(height: 80)
                    }
                }
            }
            .background(AppColors.borderWeak)
        }
        .background(AppColors.surface)
        .overlay(RoundedRectangle(cornerRadius: 0).stroke(AppColors.ink, lineWidth: 1))
        .hardShadow()
        .padding(.bottom, 32)
    }
}

private struct MonthDayCell: View {
    @EnvironmentObject var store: AppStore
    let dayKey: String
    let isActive: Bool
    let onTap: () -> Void

    @State private var isHovered = false

    private var tasks: [RoutineTask] { store.tasks(for: dayKey) }
    private var done: Int { tasks.filter { $0.done }.count }
    private var isToday: Bool { dayKey == todayKey() }
    private var isPast: Bool { dayKey < todayKey() }

    private var dayNum: String {
        let f = DateFormatter(); f.dateFormat = "d"
        return f.string(from: date(from: dayKey))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(dayNum)
                    .font(AppFonts.monoBold(14))
                    .foregroundColor(isToday ? AppColors.accent : (isPast ? AppColors.inkMuted : AppColors.ink))
                Spacer()
                if !tasks.isEmpty {
                    Text("\(done)/\(tasks.count)")
                        .font(AppFonts.mono(9))
                        .foregroundColor(done == tasks.count ? AppColors.ink : AppColors.inkFaint)
                }
            }

            if !tasks.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(tasks.prefix(3)) { task in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(task.done ? AppColors.ink : AppColors.borderMid)
                                .frame(width: 5, height: 5)
                            Text(task.name.isEmpty ? "Untitled" : task.name)
                                .font(AppFonts.mono(9))
                                .foregroundColor(task.done ? AppColors.inkFaint : AppColors.inkMuted)
                                .lineLimit(1)
                        }
                    }
                    if tasks.count > 3 {
                        Text("+\(tasks.count - 3) more")
                            .font(AppFonts.mono(9))
                            .foregroundColor(AppColors.inkFaint)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
        .background(
            isActive ? AppColors.accentBg :
            (isHovered ? AppColors.borderWeak : AppColors.surface)
        )
        .overlay(alignment: .top) {
            if isToday {
                Rectangle().fill(AppColors.accent).frame(height: 2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onHover { isHovered = $0 }
    }
}
