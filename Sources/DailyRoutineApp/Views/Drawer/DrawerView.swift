import SwiftUI

struct DrawerView: View {
    @EnvironmentObject var store: AppStore

    private var task: RoutineTask? {
        guard let id = store.drawerTaskId else { return nil }
        return store.tasks(for: store.activeDay).first { $0.id == id }
    }

    @State private var editingName = ""
    @State private var editingDesc = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            drawerHeader
            Divider().background(AppColors.borderStrong)

            if let t = task {
                ScrollView {
                    drawerBody(task: t)
                }
            } else {
                Spacer()
                Text("Task not found")
                    .font(AppFonts.mono(12))
                    .foregroundColor(AppColors.inkFaint)
                    .frame(maxWidth: .infinity)
                Spacer()
            }
        }
        .frame(width: 380, alignment: .top)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(AppColors.surface)
        .overlay(alignment: .leading) {
            Rectangle().fill(AppColors.borderStrong).frame(width: 1)
        }
        .overlay(alignment: .top) {
            Rectangle().fill(AppColors.borderStrong).frame(height: 1)
        }
        .onAppear {
            if let t = task {
                editingName = t.name
                editingDesc = t.description
            }
        }
        .onChange(of: store.drawerTaskId) { _, _ in
            if let t = task {
                editingName = t.name
                editingDesc = t.description
            }
        }
    }

    // MARK: - Subviews

    private var drawerHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("TASK DETAIL")
                    .eyebrow()
                if let t = task {
                    Text(t.priority.label)
                        .pill(color: t.priority.color)
                }
            }
            Spacer()
            Button {
                store.drawerTaskId = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColors.inkMuted)
                    .frame(width: 30, height: 30)
                    .background(AppColors.borderWeak)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .help("Close")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }

    private func drawerBody(task t: RoutineTask) -> some View {
        VStack(alignment: .leading, spacing: 24) {

            // Name field
            VStack(alignment: .leading, spacing: 6) {
                Text("NAME")
                    .eyebrow()
                TextField("Task name", text: $editingName)
                    .font(AppFonts.displayItalic(22))
                    .foregroundColor(AppColors.ink)
                    .textFieldStyle(.plain)
                    .onSubmit { commitName() }
                    .onDisappear { commitName() }
            }

            // Description field — bordered container + placeholder so an empty
            // note reads as an editable field rather than a blank void.
            VStack(alignment: .leading, spacing: 6) {
                Text("DESCRIPTION")
                    .eyebrow()
                ZStack(alignment: .topLeading) {
                    if editingDesc.isEmpty {
                        Text("Add notes or details…")
                            .font(AppFonts.mono(12))
                            .foregroundColor(AppColors.inkFaint)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 12)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $editingDesc)
                        .font(AppFonts.mono(12))
                        .foregroundColor(AppColors.ink)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 7)
                        .frame(minHeight: 96)
                        .onDisappear { commitDesc() }
                }
                .background(AppColors.bg)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(AppColors.borderMid, lineWidth: 1)
                )
            }

            // Meta
            VStack(alignment: .leading, spacing: 6) {
                Text("PRIORITY")
                    .eyebrow()
                HStack(spacing: 8) {
                    ForEach(Priority.allCases, id: \.self) { p in
                        Button {
                            var updated = t
                            updated.priority = p
                            store.updateTask(updated, for: store.activeDay)
                        } label: {
                            Text(p.label)
                                .pill(color: t.priority == p ? p.color : AppColors.inkFaint)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("CATEGORY")
                    .eyebrow()
                Menu {
                    Button("None") {
                        var updated = t; updated.category = ""
                        store.updateTask(updated, for: store.activeDay)
                    }
                    Divider()
                    ForEach(store.categories, id: \.self) { cat in
                        Button(cat) {
                            var updated = t; updated.category = cat
                            store.updateTask(updated, for: store.activeDay)
                        }
                    }
                } label: {
                    HStack {
                        Text(t.category.isEmpty ? "No category" : t.category)
                            .font(AppFonts.mono(12))
                            .foregroundColor(t.category.isEmpty ? AppColors.inkFaint : AppColors.ink)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.inkFaint)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(AppColors.bg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(AppColors.borderMid, lineWidth: 1)
                    )
                }
                .menuStyle(.borderlessButton)
            }

            // Done toggle
            Toggle(isOn: Binding(
                get: { t.done },
                set: { _ in store.toggleDone(t.id, for: store.activeDay) }
            )) {
                Text("Mark as done")
                    .font(AppFonts.mono(12))
                    .foregroundColor(AppColors.ink)
            }
            .toggleStyle(.checkbox)
        }
        .padding(24)
    }

    // MARK: - Commit helpers

    private func commitName() {
        guard let t = task else { return }
        var updated = t; updated.name = editingName
        store.updateTask(updated, for: store.activeDay)
    }

    private func commitDesc() {
        guard let t = task else { return }
        var updated = t; updated.description = editingDesc
        store.updateTask(updated, for: store.activeDay)
    }
}
