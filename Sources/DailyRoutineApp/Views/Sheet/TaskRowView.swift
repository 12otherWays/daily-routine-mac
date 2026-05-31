import SwiftUI

struct TaskRowView: View {
    @EnvironmentObject var store: AppStore
    let task: RoutineTask
    let dayKey: String

    @State private var isHovered = false
    @State private var editingName = false
    @State private var nameText: String = ""

    var body: some View {
        HStack(spacing: 0) {
            // Checkbox
            checkboxCell

            divider

            // Task name
            nameCell
                .frame(maxWidth: .infinity, alignment: .leading)

            divider

            // Priority
            priorityCell
                .frame(width: 100, alignment: .center)

            divider

            // Category
            categoryCell
                .frame(width: 130, alignment: .leading)

            divider

            // Actions
            actionCell
                .frame(width: 72)
        }
        .frame(height: 48)
        .background(
            task.done ? AppColors.bg.opacity(0.6) :
                (isHovered ? AppColors.borderWeak : AppColors.surface)
        )
        .onHover { isHovered = $0 }
    }

    // MARK: - Cells

    private var checkboxCell: some View {
        Button {
            store.toggleDone(task.id, for: dayKey)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(task.done ? AppColors.ink : Color.clear)
                    .frame(width: 20, height: 20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(task.done ? AppColors.ink : AppColors.borderStrong, lineWidth: 1.5)
                    )
                if task.done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AppColors.bg)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(width: 44)
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
                    .foregroundColor(task.name.isEmpty ? AppColors.inkFaint : (task.done ? AppColors.inkMuted : AppColors.ink))
                    .strikethrough(task.done, color: AppColors.inkMuted)
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
                .pill(color: task.priority.color)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
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
            // Open drawer
            Button {
                store.drawerTaskId = task.id == store.drawerTaskId ? nil : task.id
            } label: {
                Image(systemName: "doc.text")
                    .font(.system(size: 13))
                    .foregroundColor(store.drawerTaskId == task.id ? AppColors.ink : AppColors.inkFaint)
            }
            .buttonStyle(.plain)
            .help("Edit description")

            // Delete
            Button {
                store.deleteTask(task.id, from: dayKey)
                if store.drawerTaskId == task.id { store.drawerTaskId = nil }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundColor(isHovered ? AppColors.high : AppColors.inkFaint)
            }
            .buttonStyle(.plain)
            .help("Delete task")
        }
        .padding(.horizontal, 12)
        .opacity(isHovered || store.drawerTaskId == task.id ? 1 : 0.3)
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
