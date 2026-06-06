import SwiftUI

struct StatCard: View {
    let label: String
    let value: String
    var unit: String = ""
    var primary: Bool = false  // filled/inverted style for gamification milestones
    var systemImage: String = ""
    var iconColors: [Color] = [Color(hex: "fb923c"), Color(hex: "ef4444")]  // top → bottom gradient

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(AppFonts.mono(8))
                .kerning(1.2)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundColor(primary ? AppColors.bg.opacity(0.7) : AppColors.inkMuted)

            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value)
                    .font(AppFonts.monoMedium(28))
                    .foregroundColor(primary ? AppColors.bg : AppColors.ink)
                if !unit.isEmpty {
                    Text(unit)
                        .font(AppFonts.mono(12))
                        .foregroundColor(primary ? AppColors.bg.opacity(0.7) : AppColors.inkMuted)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .overlay(alignment: .topTrailing) {
            if !systemImage.isEmpty {
                Image(systemName: systemImage)
                    .font(.system(size: 15))
                    .foregroundStyle(
                        LinearGradient(
                            colors: iconColors,
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .padding(14)
            }
        }
        .background(primary ? AppColors.ink : AppColors.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(primary ? AppColors.ink : AppColors.borderMid, lineWidth: 1)
        )
        .hardShadow(x: 3, y: 3)
    }
}
