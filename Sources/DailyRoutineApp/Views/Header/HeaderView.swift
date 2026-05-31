import SwiftUI

struct HeaderView: View {
    @EnvironmentObject var store: AppStore
    let done: Int
    let total: Int
    let pct: Int

    private var streak: Int { computeStreak(store.statsInput()) }
    private var isToday: Bool { store.activeDay == todayKey() }

    var body: some View {
        HStack(alignment: .bottom, spacing: 24) {
            // Left: title + eyebrow
            VStack(alignment: .leading, spacing: 8) {
                eyebrowRow
                titleText
            }

            Spacer()

            // Right: stats/controls + gear
            HStack(alignment: .bottom, spacing: 16) {
                if store.viewMode == .stats {
                    statsModeControl
                } else {
                    normalControls
                }
                gearButton
            }
        }
        .padding(.bottom, 20)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppColors.borderStrong)
                .frame(height: 1)
        }
    }

    // MARK: - Subviews

    private var eyebrowRow: some View {
        HStack(spacing: 8) {
            Text("DAILY · ROUTINE")
                .eyebrow()

            if store.viewMode == .day {
                if isToday {
                    badge("TODAY", bg: AppColors.ink, fg: AppColors.bg)
                } else if store.activeDay < todayKey() {
                    badge("PAST", bg: AppColors.borderWeak, fg: AppColors.inkMuted)
                } else {
                    badge("UPCOMING", bg: AppColors.accentBg, fg: AppColors.accent)
                }
            } else if store.viewMode == .week {
                badge("WEEK", bg: AppColors.accentBg, fg: AppColors.accent)
            } else if store.viewMode == .month {
                badge("MONTH", bg: AppColors.accentBg, fg: AppColors.accent)
            } else if store.viewMode == .stats {
                badge("STATS", bg: AppColors.accentBg, fg: AppColors.accent)
            }
        }
    }

    private var titleText: some View {
        Text(headerTitle(for: store.activeDay, viewMode: store.viewMode))
            .font(AppFonts.displayItalic(26))
            .foregroundColor(AppColors.ink)
            .lineLimit(1)
    }

    @State private var backHovered = false

    private var statsModeControl: some View {
        HStack(spacing: 2) {
            Button {
                store.viewMode = .day
            } label: {
                Label("DAY", systemImage: "chevron.left")
                    .labelStyle(.titleAndIcon)
                    .font(AppFonts.monoBold(10))
                    .kerning(1)
                    .foregroundColor(backHovered ? AppColors.ink : AppColors.inkMuted)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(backHovered ? AppColors.borderMid : Color.clear)
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { backHovered = $0 }

            HStack(spacing: 5) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text("STATS")
                    .font(AppFonts.monoBold(10))
                    .kerning(1)
            }
            .foregroundColor(AppColors.bg)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 4).fill(AppColors.ink))
        }
        .padding(3)
        .background(AppColors.borderWeak)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .animation(.easeInOut(duration: 0.1), value: backHovered)
    }

    // Stats + ViewToggle
    private var normalControls: some View {
        HStack(alignment: .bottom, spacing: 24) {
            statItem(label: store.viewMode == .day ? "Done" : "Total done",
                     value: "\(done)/\(total)")
            statItem(label: "Progress", value: "\(pct)%")
            streakItem
            ViewToggle(mode: store.viewMode) { store.viewMode = $0 }
        }
    }

    private func statItem(label: String, value: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(label.uppercased())
                .font(AppFonts.mono(9))
                .kerning(1.5)
                .foregroundColor(AppColors.inkMuted)
                .lineLimit(1)
            Text(value)
                .font(AppFonts.monoMedium(22))
                .foregroundColor(AppColors.ink)
                .lineLimit(1)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var streakItem: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("STREAK")
                .font(AppFonts.mono(9))
                .kerning(1.5)
                .foregroundColor(AppColors.inkMuted)
                .lineLimit(1)
            HStack(spacing: 4) {
                if streak > 0 {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 14))
                }
                Text("\(streak)")
                    .font(AppFonts.monoMedium(22))
                    .foregroundColor(AppColors.ink)
                    .lineLimit(1)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var gearButton: some View {
        Button {
            store.settingsTab = store.settingsTab == nil ? .templates : nil
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(AppColors.ink)
                .padding(7)
        }
        .buttonStyle(.plain)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(AppColors.borderStrong, lineWidth: 1)
        )
        .help("Settings")
    }

    private func badge(_ text: String, bg: Color, fg: Color) -> some View {
        Text(text)
            .font(AppFonts.mono(9))
            .kerning(1.5)
            .foregroundColor(fg)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - ViewToggle (segmented control for Day/Week/Month/Stats)

struct ViewToggle: View {
    let mode: ViewMode
    let onChange: (ViewMode) -> Void
    @State private var hoveredMode: ViewMode? = nil

    var body: some View {
        HStack(spacing: 2) {
            ForEach(ViewMode.allCases, id: \.self) { m in
                Button {
                    onChange(m)
                } label: {
                    Group {
                        if m == .stats {
                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: 11, weight: .semibold))
                        } else {
                            Text(m.label.uppercased())
                                .font(AppFonts.monoBold(10))
                                .kerning(1)
                                .lineLimit(1)
                        }
                    }
                    .foregroundColor(
                        mode == m ? AppColors.bg :
                        hoveredMode == m ? AppColors.ink : AppColors.inkMuted
                    )
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                mode == m ? AppColors.ink :
                                hoveredMode == m ? AppColors.borderMid : Color.clear
                            )
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { hoveredMode = $0 ? m : nil }
            }
        }
        .padding(3)
        .background(AppColors.borderWeak)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        // Lock the toggle to its intrinsic width so the title (which already
        // has `minimumScaleFactor`) shrinks first when the window is narrow.
        .fixedSize(horizontal: true, vertical: false)
        .animation(.easeInOut(duration: 0.15), value: mode)
        .animation(.easeInOut(duration: 0.1), value: hoveredMode)
    }
}
