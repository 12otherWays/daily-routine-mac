import SwiftUI

struct TemplatesEditor: View {
    @EnvironmentObject var store: AppStore
    @State private var newTemplateName = ""
    @State private var expandedId: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            createSection

            Divider()

            if store.templates.isEmpty {
                Text("No templates yet. Create one above.")
                    .font(AppFonts.mono(12))
                    .foregroundColor(AppColors.inkFaint)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 8) {
                    ForEach(store.templates) { template in
                        TemplateGroupRow(
                            template: template,
                            isExpanded: expandedId == template.id,
                            onToggle: {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                    expandedId = expandedId == template.id ? nil : template.id
                                }
                            },
                            onDelete: {
                                store.deleteTemplate(id: template.id)
                                if expandedId == template.id { expandedId = nil }
                            },
                            onAddTask: { task in
                                var updated = template
                                updated.tasks.append(task)
                                store.updateTemplate(updated)
                            },
                            onRemoveTask: { taskId in
                                var updated = template
                                updated.tasks.removeAll { $0.id == taskId }
                                store.updateTemplate(updated)
                            }
                        )
                    }
                }
            }
        }
    }

    private var createSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("NEW TEMPLATE").eyebrow()
            HStack(spacing: 8) {
                TextField("Template name, e.g. \"Morning Routine\"", text: $newTemplateName)
                    .font(AppFonts.mono(13))
                    .appField()
                    .onSubmit { createTemplate() }
                Button("Create") { createTemplate() }
                    .buttonStyle(AppPrimaryButtonStyle())
                    .disabled(newTemplateName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            Text("After creating, expand the template to add tasks.")
                .font(AppFonts.mono(10))
                .foregroundColor(AppColors.inkFaint)
        }
    }

    private func createTemplate() {
        let trimmed = newTemplateName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let t = RoutineTemplate(name: trimmed)
        store.addTemplate(t)
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            expandedId = t.id
        }
        newTemplateName = ""
    }
}

// MARK: - Template Group Row

private struct TemplateGroupRow: View {
    let template: RoutineTemplate
    let isExpanded: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onAddTask: (TemplateTask) -> Void
    let onRemoveTask: (String) -> Void

    @EnvironmentObject var store: AppStore
    @State private var newName = ""
    @State private var newPriority: Priority = .med
    @State private var newCategory = ""
    @State private var deleteHovered = false

    var body: some View {
        VStack(spacing: 0) {
            headerRow
            if isExpanded {
                expandedContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(AppColors.surface)
        .overlay(
            Rectangle()
                .stroke(AppColors.borderMid, lineWidth: 1)
        )
    }

    private var headerRow: some View {
        HStack(spacing: 8) {
            Button(action: onToggle) {
                HStack(spacing: 8) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppColors.inkMuted)
                        .frame(width: 12)
                    Text(template.name.isEmpty ? "Untitled Template" : template.name)
                        .font(AppFonts.monoBold(13))
                        .foregroundColor(AppColors.ink)
                    Spacer()
                    Text("\(template.tasks.count) task\(template.tasks.count == 1 ? "" : "s")")
                        .font(AppFonts.mono(10))
                        .foregroundColor(AppColors.inkFaint)
                }
            }
            .buttonStyle(.plain)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundColor(deleteHovered ? AppColors.high : AppColors.inkMuted)
            }
            .buttonStyle(.plain)
            .onHover { deleteHovered = $0 }
            .help("Delete template")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var expandedContent: some View {
        VStack(spacing: 0) {
            Rectangle().fill(AppColors.borderMid).frame(height: 1)

            if template.tasks.isEmpty {
                Text("No tasks yet — add one below")
                    .font(AppFonts.mono(10))
                    .foregroundColor(AppColors.inkFaint)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.bg)
            } else {
                ForEach(template.tasks) { task in
                    taskRow(task)
                    Rectangle().fill(AppColors.borderWeak).frame(height: 1)
                }
            }

            addTaskForm
        }
    }

    private func taskRow(_ task: TemplateTask) -> some View {
        HStack(spacing: 8) {
            Text(task.priority.label)
                .pill(color: task.priority.color)
            Text(task.name.isEmpty ? "Untitled" : task.name)
                .font(AppFonts.mono(11))
                .foregroundColor(AppColors.ink)
                .lineLimit(1)
            if !task.category.isEmpty {
                Text(task.category)
                    .font(AppFonts.mono(9))
                    .foregroundColor(AppColors.inkMuted)
            }
            Spacer()
            Button { onRemoveTask(task.id) } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(AppColors.inkMuted)
            }
            .buttonStyle(.plain)
            .help("Remove task")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(AppColors.bg)
    }

    private var addTaskForm: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Task name", text: $newName)
                .font(AppFonts.mono(12))
                .appField()
                .onSubmit { commitAddTask() }

            HStack(spacing: 6) {
                Menu {
                    ForEach(Priority.allCases, id: \.self) { p in
                        Button(p.label) { newPriority = p }
                    }
                } label: {
                    Text(newPriority.label)
                        .pill(color: newPriority.color)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()

                Menu {
                    Button("None") { newCategory = "" }
                    Divider()
                    ForEach(store.categories, id: \.self) { cat in
                        Button(cat) { newCategory = cat }
                    }
                } label: {
                    Text(newCategory.isEmpty ? "Category" : newCategory)
                        .font(AppFonts.mono(10))
                        .foregroundColor(AppColors.inkMuted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppColors.bg)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(AppColors.borderMid))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()

                Spacer()

                Button("Add task") { commitAddTask() }
                    .buttonStyle(AppPrimaryButtonStyle())
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(10)
        .background(AppColors.bg.opacity(0.6))
        .overlay(alignment: .top) {
            Rectangle().fill(AppColors.borderMid).frame(height: 1)
        }
    }

    private func commitAddTask() {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        onAddTask(TemplateTask(name: trimmed, priority: newPriority, category: newCategory))
        newName = ""
        newPriority = .med
        newCategory = ""
    }
}
