import SwiftUI

struct TaskRowView: View {
    @EnvironmentObject var store: AppStore
    let task: RoutineTask
    let dayKey: String

    @State private var isHovered = false
    @State private var editingName = false
    @State private var nameText: String = ""
    @State private var descHovered = false
    @State private var deleteHovered = false
    @State private var showDeleteConfirm = false

    // Read done state live from store so this view re-renders with fresh data
    // even when SwiftUI independently re-renders it before the parent passes
    // the updated `task` prop.
    private var isDone: Bool {
        store.tasks(for: dayKey).first(where: { $0.id == task.id })?.done ?? task.done
    }

    var body: some View {
        HStack(spacing: 0) {
            checkboxCell
            divider
            nameCell
                .frame(maxWidth: .infinity, alignment: .leading)
            divider
            priorityCell
                .frame(width: 100, alignment: .center)
            divider
            categoryCell
                .frame(width: 130, alignment: .leading)
            divider
            actionCell
                .frame(width: 72)
        }
        .frame(height: 48)
        .background(
            isDone ? AppColors.bg.opacity(0.6) :
                (isHovered ? AppColors.borderWeak : AppColors.surface)
        )
        .onHover { isHovered = $0 }
        .alert("Delete Task?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                store.deleteTask(task.id, from: dayKey)
                if store.drawerTaskId == task.id { store.drawerTaskId = nil }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\"\(task.name.isEmpty ? "Untitled Task" : task.name)\" will be permanently removed.")
        }
    }

    // MARK: - Cells

    private var checkboxCell: some View {
        ZStack {
            Color.white.opacity(0.001) // non-transparent so macOS hit-tests the full cell
            RoundedRectangle(cornerRadius: 4)
                .fill(isDone ? AppColors.ink : Color.clear)
                .frame(width: 20, height: 20)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isDone ? AppColors.ink : AppColors.borderStrong, lineWidth: 1.5)
                )
            if isDone {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppColors.bg)
            }
        }
        .frame(width: 44)
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            store.toggleDone(task.id, for: dayKey)
        }
    }

    private var nameCell: some View {
        Group {
            if editingName {
                TextField("Task name", text: $nameText)
                    .font(AppFonts.mono(13))
                    .foregroundColor(AppColors.ink)
                    .textFieldStyle(.plain)
                    .onSubmit { commitName() }
                    .onExitCommand { editingName = false; nameText = task.name }
                    .padding(.horizontal, 12)
            } else {
                Text(task.name.isEmpty ? "Untitled Task" : task.name)
                    .font(AppFonts.mono(13))
                    .foregroundColor(task.name.isEmpty ? AppColors.inkFaint : (isDone ? AppColors.inkMuted : AppColors.ink))
                    .strikethrough(isDone, color: AppColors.inkMuted)
                    .padding(.horizontal, 12)
                    .onTapGesture(count: 2) {
                        nameText = task.name
                        editingName = true
                    }
            }
        }
    }

    private var priorityCell: some View {
        Menu {
            ForEach(Priority.allCases, id: \.self) { p in
                Button {
                    var updated = task
                    updated.priority = p
                    store.updateTask(updated, for: dayKey)
                } label: {
                    Label(p.label, systemImage: task.priority == p ? "checkmark" : "")
                }
            }
        } label: {
            Text(task.priority.label)
                .font(AppFonts.monoBold(10))
                .kerning(0.8)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .frame(height: 20)
        .background(
            Capsule()
                .fill(task.priority.color)
        )
        .overlay(
            Capsule()
                .stroke(task.priority.color.opacity(0.4), lineWidth: 1)
        )
    }

    private var categoryCell: some View {
        Menu {
            Button("Clear") {
                var updated = task; updated.category = ""
                store.updateTask(updated, for: dayKey)
            }
            Divider()
            ForEach(store.categories, id: \.self) { cat in
                Button(cat) {
                    var updated = task; updated.category = cat
                    store.updateTask(updated, for: dayKey)
                }
            }
            Divider()
            Button("Manage categories…") {
                store.settingsTab = .categories
            }
        } label: {
            HStack(spacing: 4) {
                if task.category.isEmpty {
                    Text("—")
                        .font(AppFonts.mono(11))
                        .foregroundColor(AppColors.inkFaint)
                } else {
                    Text(task.category)
                        .font(AppFonts.mono(11))
                        .foregroundColor(AppColors.inkMuted)
                }
            }
            .padding(.horizontal, 12)
        }
        .menuStyle(.borderlessButton)
    }

    private var actionCell: some View {
        HStack(spacing: 8) {
            Button {
                store.drawerTaskId = task.id == store.drawerTaskId ? nil : task.id
            } label: {
                Image(systemName: "doc.text")
                    .font(.system(size: 13))
                    .foregroundColor(
                        store.drawerTaskId == task.id || descHovered
                            ? AppColors.ink
                            : AppColors.inkMuted
                    )
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .onHover { descHovered = $0 }
            .help("Edit description")

            Button {
                showDeleteConfirm = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundColor(deleteHovered ? AppColors.high : AppColors.inkMuted)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .onHover { deleteHovered = $0 }
            .help("Delete task")
        }
        .padding(.horizontal, 12)
    }

    private var divider: some View {
        Rectangle().fill(AppColors.borderWeak).frame(width: 1)
    }

    private func commitName() {
        var updated = task
        updated.name = nameText
        store.updateTask(updated, for: dayKey)
        editingName = false
    }
}
