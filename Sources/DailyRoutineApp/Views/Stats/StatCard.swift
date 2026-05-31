import SwiftUI

struct StatCard: View {
    let label: String
    let value: String
    var unit: String = ""
    var primary: Bool = false  // filled/inverted style for gamification milestones
    var systemImage: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !systemImage.isEmpty {
                Image(systemName: systemImage)
                    .font(.system(size: 16))
                    .foregroundColor(primary ? AppColors.bg : AppColors.inkMuted)
            }

            Text(label.uppercased())
                .font(AppFonts.mono(9))
                .kerning(1.5)
                .foregroundColor(primary ? AppColors.bg.opacity(0.7) : AppColors.inkMuted)

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(AppFonts.monoMedium(32))
                    .foregroundColor(primary ? AppColors.bg : AppColors.ink)
                if !unit.isEmpty {
                    Text(unit)
                        .font(AppFonts.mono(14))
                        .foregroundColor(primary ? AppColors.bg.opacity(0.7) : AppColors.inkMuted)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(primary ? AppColors.ink : AppColors.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(primary ? AppColors.ink : AppColors.borderMid, lineWidth: 1)
        )
        .hardShadow(x: 3, y: 3)
    }
}
