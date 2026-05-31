import SwiftUI

struct TemplatePickerView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TEMPLATES")
                        .eyebrow()
                    Text("Pick tasks for \(formatKeyShort(store.activeDay))")
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

            Divider()

            if store.templates.isEmpty {
                emptyState
            } else {
                templateGrid
            }

            Divider()

            // Footer actions
            HStack(spacing: 16) {
                Button("Manage templates") {
                    dismiss()
                    store.settingsTab = .templates
                }
                .buttonStyle(.plain)
                .font(AppFonts.mono(11))
                .foregroundColor(AppColors.inkMuted)

                Spacer()

                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .font(AppFonts.monoBold(11))
                    .kerning(1)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
        }
        .frame(width: 560, height: 460)
        .background(AppColors.surface)
    }

    private var templateGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(store.templates) { template in
                    TemplateCard(template: template) {
                        store.addTaskFromTemplate(template, to: store.activeDay)
                        dismiss()
                    }
                }
            }
            .padding(28)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("No templates yet")
                .font(AppFonts.displayItalic(18))
                .foregroundColor(AppColors.inkMuted)
            Text("Add templates in Settings")
                .font(AppFonts.mono(11))
                .foregroundColor(AppColors.inkFaint)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Template Card

private struct TemplateCard: View {
    let template: RoutineTemplate
    let onPick: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onPick) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(template.priority.label)
                        .pill(color: template.priority.color)
                    Spacer()
                    if !template.category.isEmpty {
                        Text(template.category)
                            .font(AppFonts.mono(9))
                            .foregroundColor(AppColors.inkMuted)
                    }
                }

                Text(template.name.isEmpty ? "Untitled" : template.name)
                    .font(AppFonts.mono(13))
                    .foregroundColor(AppColors.ink)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !template.description.isEmpty {
                    Text(template.description)
                        .font(AppFonts.display(12))
                        .foregroundColor(AppColors.inkMuted)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(14)
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
