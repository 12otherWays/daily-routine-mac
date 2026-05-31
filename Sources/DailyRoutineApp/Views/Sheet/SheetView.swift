import SwiftUI

struct SheetView: View {
    @EnvironmentObject var store: AppStore

    private var tasks: [RoutineTask] {
        store.tasks(for: store.activeDay)
    }

    var body: some View {
        VStack(spacing: 0) {
            columnHeader
            taskRows
            addRowFooter
        }
        .background(AppColors.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(AppColors.ink, lineWidth: 1)
        )
        .hardShadow()
        .padding(.bottom, 32)
    }

    // MARK: - Column header row

    private var columnHeader: some View {
        HStack(spacing: 0) {
            // Checkbox col
            Color.clear.frame(width: 44)
            divider

            // Task name
            Text("TASK")
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            divider

            // Priority
            Text("PRIORITY")
                .frame(width: 100, alignment: .center)
            divider

            // Category
            Text("CATEGORY")
                .padding(.horizontal, 12)
                .frame(width: 130, alignment: .leading)
            divider

            // Actions
            Color.clear.frame(width: 72)
        }
        .font(AppFonts.mono(9))
        .kerning(1.5)
        .foregroundColor(AppColors.inkMuted)
        .frame(height: 36)
        .background(AppColors.bg)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppColors.borderStrong).frame(height: 1)
        }
    }

    // MARK: - Task rows

    private var taskRows: some View {
        Group {
            if tasks.isEmpty {
                emptyState
            } else {
                ForEach(tasks) { task in
                    TaskRowView(task: task, dayKey: store.activeDay)
                    if task.id != tasks.last?.id {
                        Rectangle()
                            .fill(AppColors.borderWeak)
                            .frame(height: 1)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("No tasks yet")
                .font(AppFonts.displayItalic(20))
                .foregroundColor(AppColors.inkMuted)
            Text("Add from a template or create a blank task below")
                .font(AppFonts.mono(11))
                .foregroundColor(AppColors.inkFaint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    // MARK: - Add row footer

    private var addRowFooter: some View {
        HStack(spacing: 12) {
            Button {
                store.templatePickerOpen = true
            } label: {
                Label("From template", systemImage: "doc.on.doc")
                    .font(AppFonts.monoBold(10))
                    .kerning(1)
                    .textCase(.uppercase)
                    .foregroundColor(AppColors.inkMuted)
            }
            .buttonStyle(.plain)

            Rectangle().fill(AppColors.borderWeak).frame(width: 1, height: 16)

            Button {
                store.addBlankTask(to: store.activeDay)
            } label: {
                Label("Blank task", systemImage: "plus")
                    .font(AppFonts.monoBold(10))
                    .kerning(1)
                    .textCase(.uppercase)
                    .foregroundColor(AppColors.inkMuted)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(AppColors.bg)
        .overlay(alignment: .top) {
            Rectangle().fill(AppColors.borderMid).frame(height: 1)
        }
    }

    private var divider: some View {
        Rectangle().fill(AppColors.borderWeak).frame(width: 1)
    }
}
