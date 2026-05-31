import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SETTINGS")
                            .eyebrow()
                        Text(store.settingsTab?.label ?? "Settings")
                            .font(AppFonts.displayItalic(24))
                            .foregroundColor(AppColors.ink)
                    }
                    Spacer()
                    Button {
                        store.settingsTab = nil
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
                .padding(.horizontal, 28)
                .padding(.top, 28)
                .padding(.bottom, 20)

                // Tab switcher
                HStack(spacing: 0) {
                    ForEach(SettingsTab.allCases) { tab in
                        Button {
                            store.settingsTab = tab
                        } label: {
                            Text(tab.label.uppercased())
                                .font(AppFonts.monoBold(10))
                                .kerning(1)
                                .foregroundColor(store.settingsTab == tab ? AppColors.bg : AppColors.inkMuted)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(store.settingsTab == tab ? AppColors.ink : Color.clear)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(AppColors.borderStrong, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .padding(.horizontal, 28)
                .padding(.bottom, 20)

                Divider()

                // Tab content
                ScrollView {
                    switch store.settingsTab {
                    case .templates:
                        TemplatesEditor()
                            .padding(28)
                    case .categories:
                        CategoriesEditor()
                            .padding(28)
                    case .none:
                        EmptyView()
                    }
                }
            }
            .frame(width: 420, alignment: .top)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(AppColors.surface)
            .overlay(alignment: .leading) {
                Rectangle().fill(AppColors.borderStrong).frame(width: 1)
            }
    }
}
