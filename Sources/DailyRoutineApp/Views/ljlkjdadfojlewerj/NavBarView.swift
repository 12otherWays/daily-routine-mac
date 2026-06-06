import SwiftUI

struct NavBarView: View {
    @EnvironmentObject var store: AppStore

    private var tabs: [String] { buildDayTabs() }
    private var today: String  { todayKey() }

    var body: some View {
        HStack(spacing: 0) {
            navButton(systemImage: "chevron.left") { store.goPrev() }
                .help("Previous \(store.viewMode.label)")

            if store.viewMode == .day {
                dayTabs
            } else {
                periodLabel
            }

            navButton(systemImage: "chevron.right") { store.goNext() }
                .help("Next \(store.viewMode.label)")

            if store.activeDay != today {
                todayButton
            }

            calendarButton
        }
        .frame(height: 44)
        .background(AppColors.bg)
        .overlay(alignment: .top) {
            Rectangle().fill(AppColors.borderStrong).frame(height: 1)
        }
    }

    // MARK: - Day tabs (shown only in day view)

    private var dayTabs: some View {
        // Batch the 8 tab counts into a single dictionary so each tab doesn't
        // trigger its own cache lookup.
        let counts = store.taskCounts(forDays: tabs)
        return HStack(spacing: 0) {
            ForEach(tabs, id: \.self) { key in
                DayTab(
                    dayKey: key,
                    isActive: key == store.activeDay,
                    isToday: key == today,
                    taskCount: counts[key]?.total ?? 0
                )
                .onTapGesture { store.activeDay = key }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var periodLabel: some View {
        Text(periodLabelText)
            .font(AppFonts.mono(11))
            .kerning(1.2)
            .foregroundColor(AppColors.inkMuted)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .leading) {
                Rectangle().fill(AppColors.borderWeak).frame(width: 1)
            }
            .overlay(alignment: .trailing) {
                Rectangle().fill(AppColors.borderWeak).frame(width: 1)
            }
    }

    private var periodLabelText: String {
        switch store.viewMode {
        case .week:
            let days = getWeekDays(for: store.activeDay)
            guard days.count == 7 else { return "This Week" }
            let f = DateFormatter(); f.dateFormat = "MMM d"
            let start = date(from: days[0]); let end = date(from: days[6])
            return "\(f.string(from: start)) – \(f.string(from: end))"
        case .month:
            let d = date(from: store.activeDay)
            let f = DateFormatter(); f.dateFormat = "MMMM yyyy"
            return f.string(from: d)
        default: return ""
        }
    }

    private var todayButton: some View {
        Button("Today") { store.activeDay = today }
            .buttonStyle(.plain)
            .font(AppFonts.monoBold(10))
            .kerning(1.5)
            .foregroundColor(AppColors.accent)
            .padding(.horizontal, 14)
            .frame(height: 44)
            .overlay(alignment: .leading) {
                Rectangle().fill(AppColors.accent.opacity(0.25)).frame(width: 1)
            }
    }

    private var calendarButton: some View {
        Button {
            store.calendarDrawerOpen.toggle()
        } label: {
            Image(systemName: "calendar")
                .font(.system(size: 14))
                .foregroundColor(store.calendarDrawerOpen ? AppColors.ink : AppColors.inkMuted)
                .frame(width: 40, height: 44)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .leading) {
            Rectangle().fill(AppColors.borderWeak).frame(width: 1)
        }
        .help("Calendar")
    }

    private func navButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12))
                .foregroundColor(AppColors.inkMuted)
                .frame(width: 36, height: 44)
                // Without this, only the tiny chevron glyph is clickable — the
                // surrounding frame is dead space. Makes the full 36×44 tappable.
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .trailing) {
            Rectangle().fill(AppColors.borderWeak).frame(width: 1)
        }
    }
}

// MARK: - DayTab

private struct DayTab: View {
    let dayKey: String
    let isActive: Bool
    let isToday: Bool
    let taskCount: Int

    private var d: Date { date(from: dayKey) }
    private var weekday: String {
        let f = DateFormatter(); f.dateFormat = "EEE"
        return f.string(from: d).uppercased()
    }
    private var dayNum: String {
        let f = DateFormatter(); f.dateFormat = "d"
        return f.string(from: d)
    }
    private var month: String {
        let f = DateFormatter(); f.dateFormat = "MMM"
        return f.string(from: d).uppercased()
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 1) {
                Text(weekday)
                    .font(AppFonts.mono(8))
                    .kerning(1)
                    .foregroundColor(isActive ? AppColors.ink : AppColors.inkMuted)
                Text(dayNum)
                    .font(AppFonts.monoBold(16))
                    .foregroundColor(isActive ? AppColors.ink : AppColors.inkMuted)
                Text(month)
                    .font(AppFonts.mono(8))
                    .kerning(1)
                    .foregroundColor(isActive ? AppColors.inkMuted : AppColors.inkFaint)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(isActive ? AppColors.bg : Color.clear)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(isActive ? AppColors.ink : (isToday ? AppColors.accent : Color.clear))
                    .frame(height: isActive ? 3 : 1)
            }

            if taskCount > 0 {
                Text("\(taskCount)")
                    .font(AppFonts.mono(7))
                    .foregroundColor(AppColors.bg)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(AppColors.ink)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .padding(.top, 3)
                    .padding(.trailing, 4)
            }
        }
        .frame(height: 44)
        .contentShape(Rectangle())
        .overlay(alignment: .trailing) {
            Rectangle().fill(AppColors.borderWeak).frame(width: 1)
        }
    }
}
