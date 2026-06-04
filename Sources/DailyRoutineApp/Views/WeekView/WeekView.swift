import SwiftUI

struct WeekView: View {
    @EnvironmentObject var store: AppStore

    private var weekDays: [String] { getWeekDays(for: store.activeDay) }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(weekDays.enumerated()), id: \.element) { idx, key in
                WeekDayColumn(dayKey: key)
                if idx < weekDays.count - 1 {
                    Rectangle().fill(AppColors.borderWeak).frame(width: 1)
                }
            }
        }
        .frame(minHeight: 360, alignment: .top)
        .background(AppColors.surface)
        .overlay(RoundedRectangle(cornerRadius: 0).stroke(AppColors.ink, lineWidth: 1))
        .hardShadow()
        .padding(.bottom, 32)
    }
}

private struct WeekDayColumn: View {
    @EnvironmentObject var store: AppStore
    let dayKey: String

    private var tasks: [RoutineTask] { store.tasks(for: dayKey) }
    private var done: Int { tasks.filter { $0.done }.count }
    private var isToday: Bool { dayKey == todayKey() }

    private var weekdayLabel: String {
        let d = date(from: dayKey)
        let f = DateFormatter(); f.dateFormat = "EEE"
        return f.string(from: d).uppercased()
    }
    private var dayNum: String {
        let d = date(from: dayKey)
        let f = DateFormatter(); f.dateFormat = "d"
        return f.string(from: d)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Day header — fixed height so every column's header aligns.
            VStack(spacing: 2) {
                Text(weekdayLabel)
                    .font(AppFonts.mono(9)).kerning(1)
                    .foregroundColor(isToday ? AppColors.accent : AppColors.inkMuted)
                Text(dayNum)
                    .font(AppFonts.monoBold(18))
                    .foregroundColor(isToday ? AppColors.accent : AppColors.ink)
                // Always rendered to keep header height constant; hidden when empty.
                Text("\(done)/\(tasks.count)")
                    .font(AppFonts.mono(9))
                    .foregroundColor(AppColors.inkMuted)
                    .opacity(tasks.isEmpty ? 0 : 1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 68)
            .background(isToday ? AppColors.accentBg : AppColors.bg)
            .overlay(alignment: .bottom) {
                Rectangle().fill(AppColors.borderWeak).frame(height: 1)
            }

            // Tasks
            if tasks.isEmpty {
                Button {
                    store.activeDay = dayKey
                    store.addBlankTask(to: dayKey)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.inkFaint)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 16)
                .help("Add task")
            } else {
                VStack(spacing: 0) {
                    ForEach(tasks) { task in
                        WeekTaskRow(task: task, dayKey: dayKey)
                        Rectangle().fill(AppColors.borderWeak).frame(height: 1)
                    }
                    Spacer(minLength: 0)
                    Button {
                        store.activeDay = dayKey
                        store.viewMode = .day
                    } label: {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.inkFaint)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .help("Open day view")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .contentShape(Rectangle())
        .onTapGesture {
            store.activeDay = dayKey
            store.viewMode = .day
        }
    }
}

private struct WeekTaskRow: View {
    @EnvironmentObject var store: AppStore
    let task: RoutineTask
    let dayKey: String
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            // Mini checkbox
            Button {
                store.toggleDone(task.id, for: dayKey)
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(task.done ? AppColors.ink : Color.clear)
                        .frame(width: 14, height: 14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(task.done ? AppColors.ink : AppColors.borderStrong, lineWidth: 1.5)
                        )
                    if task.done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(AppColors.bg)
                    }
                }
            }
            .buttonStyle(.plain)

            Text(task.name.isEmpty ? "Untitled" : task.name)
                .font(AppFonts.mono(10))
                .foregroundColor(task.done ? AppColors.inkFaint : AppColors.ink)
                .strikethrough(task.done, color: AppColors.inkFaint)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isHovered ? AppColors.borderWeak : Color.clear)
        .onHover { isHovered = $0 }
        .contentShape(Rectangle())
    }
}
