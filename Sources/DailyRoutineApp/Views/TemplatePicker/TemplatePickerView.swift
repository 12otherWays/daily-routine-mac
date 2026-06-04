import SwiftUI

struct TemplatePickerView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var saveTemplateName = ""
    @State private var showSaveField = false

    private var todayTasks: [RoutineTask] { store.tasks(for: store.activeDay) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()

            if store.templates.isEmpty {
                emptyState
            } else {
                templateGrid
            }

            Divider()

            footer
        }
        .frame(width: 580, height: 500)
        .background(AppColors.surface)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("TEMPLATES")
                    .eyebrow()
                Text("Add tasks for \(formatKeyShort(store.activeDay))")
                    .font(AppFonts.displayItalic(22))
                    .foregroundColor(AppColors.ink)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColors.inkMuted)
                    .frame(width: 30, height: 30)
                    .background(AppColors.borderWeak)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 28)
        .padding(.top, 28)
        .padding(.bottom, 20)
    }

    // MARK: - Template grid

    private var templateGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(store.templates) { template in
                    TemplateCard(template: template) {
                        store.addTasksFromTemplate(template, to: store.activeDay)
                        dismiss()
                    }
                }
            }
            .padding(28)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("No templates yet")
                .font(AppFonts.displayItalic(18))
                .foregroundColor(AppColors.inkMuted)
            Text("Create templates in Settings → Templates")
                .font(AppFonts.mono(11))
                .foregroundColor(AppColors.inkFaint)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 0) {
            if showSaveField {
                saveAsTemplateRow
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                Divider()
            }

            HStack(spacing: 16) {
                Button("Manage templates") {
                    dismiss()
                    store.settingsTab = .templates
                }
                .buttonStyle(.plain)
                .font(AppFonts.mono(11))
                .foregroundColor(AppColors.inkMuted)

                if !todayTasks.isEmpty {
                    Rectangle().fill(AppColors.borderWeak).frame(width: 1, height: 14)

                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            showSaveField.toggle()
                        }
                    } label: {
                        Label(
                            showSaveField ? "Cancel" : "Save today's \(todayTasks.count) tasks as template",
                            systemImage: showSaveField ? "xmark" : "square.and.arrow.down"
                        )
                        .font(AppFonts.mono(11))
                        .foregroundColor(AppColors.accent)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .font(AppFonts.monoBold(11))
                    .kerning(1)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
        }
    }

    private var saveAsTemplateRow: some View {
        HStack(spacing: 8) {
            Text("TEMPLATE NAME")
                .eyebrow()
                .frame(width: 110, alignment: .leading)
            TextField("e.g. \"My Daily Routine\"", text: $saveTemplateName)
                .textFieldStyle(.roundedBorder)
                .font(AppFonts.mono(12))
                .onSubmit { commitSave() }
            Button("Save") { commitSave() }
                .buttonStyle(.borderedProminent)
                .font(AppFonts.monoBold(10))
                .disabled(saveTemplateName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 12)
        .background(AppColors.bg)
    }

    private func commitSave() {
        let trimmed = saveTemplateName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        store.saveCurrentDayAsTemplate(name: trimmed)
        saveTemplateName = ""
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            showSaveField = false
        }
    }
}

// MARK: - Template Card

private struct TemplateCard: View {
    let template: RoutineTemplate
    let onPick: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onPick) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    Text(template.name.isEmpty ? "Untitled" : template.name)
                        .font(AppFonts.monoBold(13))
                        .foregroundColor(AppColors.ink)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("\(template.tasks.count)")
                        .font(AppFonts.monoBold(10))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(AppColors.ink)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                if template.tasks.isEmpty {
                    Text("No tasks")
                        .font(AppFonts.mono(10))
                        .foregroundColor(AppColors.inkFaint)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(template.tasks.prefix(3)) { task in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(task.priority.color)
                                    .frame(width: 5, height: 5)
                                Text(task.name.isEmpty ? "Untitled" : task.name)
                                    .font(AppFonts.mono(10))
                                    .foregroundColor(AppColors.inkMuted)
                                    .lineLimit(1)
                            }
                        }
                        if template.tasks.count > 3 {
                            Text("+\(template.tasks.count - 3) more")
                                .font(AppFonts.mono(9))
                                .foregroundColor(AppColors.inkFaint)
                                .padding(.leading, 11)
                        }
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isHovered ? AppColors.bg : AppColors.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isHovered ? AppColors.ink : AppColors.borderMid, lineWidth: isHovered ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
