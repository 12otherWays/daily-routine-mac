import SwiftUI

struct TemplatesEditor: View {
    @EnvironmentObject var store: AppStore

    @State private var newName = ""
    @State private var newDesc = ""
    @State private var newPriority: Priority = .med
    @State private var newCategory = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Add new template form
            VStack(alignment: .leading, spacing: 10) {
                Text("NEW TEMPLATE")
                    .eyebrow()

                TextField("Template name", text: $newName)
                    .textFieldStyle(.roundedBorder)
                    .font(AppFonts.mono(13))

                TextField("Description (optional)", text: $newDesc)
                    .textFieldStyle(.roundedBorder)
                    .font(AppFonts.mono(12))

                HStack(spacing: 8) {
                    Menu {
                        ForEach(Priority.allCases, id: \.self) { p in
                            Button(p.label) { newPriority = p }
                        }
                    } label: {
                        Text(newPriority.label)
                            .pill(color: newPriority.color)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()

                    Menu {
                        Button("None") { newCategory = "" }
                        Divider()
                        ForEach(store.categories, id: \.self) { cat in
                            Button(cat) { newCategory = cat }
                        }
                    } label: {
                        Text(newCategory.isEmpty ? "Category" : newCategory)
                            .font(AppFonts.mono(11))
                            .foregroundColor(AppColors.inkMuted)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppColors.bg)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(AppColors.borderMid))
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()

                    Spacer()

                    Button("Add") {
                        guard !newName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        store.addTemplate(RoutineTemplate(
                            name: newName.trimmingCharacters(in: .whitespaces),
                            description: newDesc,
                            priority: newPriority,
                            category: newCategory
                        ))
                        newName = ""; newDesc = ""; newPriority = .med; newCategory = ""
                    }
                    .buttonStyle(.borderedProminent)
                    .font(AppFonts.monoBold(11))
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            Divider()

            // Existing templates list
            if store.templates.isEmpty {
                Text("No templates yet. Add one above.")
                    .font(AppFonts.mono(12))
                    .foregroundColor(AppColors.inkFaint)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 1) {
                    ForEach(store.templates) { template in
                        templateRow(template)
                    }
                }
                .background(AppColors.borderWeak)
                .overlay(RoundedRectangle(cornerRadius: 0).stroke(AppColors.borderMid))
            }
        }
    }

    private func templateRow(_ t: RoutineTemplate) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(t.name.isEmpty ? "Untitled" : t.name)
                    .font(AppFonts.mono(13))
                    .foregroundColor(AppColors.ink)
                if !t.description.isEmpty {
                    Text(t.description)
                        .font(AppFonts.mono(10))
                        .foregroundColor(AppColors.inkMuted)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text(t.priority.label).pill(color: t.priority.color)
            if !t.category.isEmpty {
                Text(t.category)
                    .font(AppFonts.mono(10))
                    .foregroundColor(AppColors.inkMuted)
            }
            Button {
                store.deleteTemplate(id: t.id)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.high)
            }
            .buttonStyle(.plain)
            .help("Delete template")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppColors.surface)
    }
}
