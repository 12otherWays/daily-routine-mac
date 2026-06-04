import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("DAILY · ROUTINE")
                        .eyebrow()
                    Text("Welcome")
                        .font(AppFonts.displayItalic(36))
                        .foregroundColor(AppColors.ink)
                    Text("Your personal daily habit tracker")
                        .font(AppFonts.mono(13))
                        .foregroundColor(AppColors.inkMuted)
                }
                .padding(.top, 40)
                .padding(.bottom, 32)

                Divider()

                VStack(spacing: 20) {
                    Text("How it works")
                        .eyebrow()
                        .padding(.top, 28)

                    HStack(alignment: .top, spacing: 24) {
                        onboardingPoint(icon: "list.bullet", title: "Daily tasks",
                                        desc: "Each day has its own task list. Check off what you complete.")
                        onboardingPoint(icon: "doc.on.doc", title: "Templates",
                                        desc: "Save reusable task templates and add them to any day.")
                        onboardingPoint(icon: "chart.bar", title: "Statistics",
                                        desc: "Track streaks, completion rates, and patterns over time.")
                    }
                    .padding(.horizontal, 32)
                }

                Spacer(minLength: 32)

                Divider()

                Button("Get started") {
                    store.prefs.onboarded = true
                    store.savePrefs()
                }
                .buttonStyle(.borderedProminent)
                .font(AppFonts.monoBold(12))
                .kerning(1.5)
                .controlSize(.large)
                .padding(.vertical, 24)
            }
            .frame(width: 560, height: 400)
            .background(AppColors.surface)
            .overlay(RoundedRectangle(cornerRadius: 0).stroke(AppColors.ink, lineWidth: 1))
            .hardShadow(x: 8, y: 8)
        }
        .preferredColorScheme(.light)
    }

    private func onboardingPoint(icon: String, title: String, desc: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(AppColors.ink)
            Text(title)
                .font(AppFonts.monoBold(12))
                .foregroundColor(AppColors.ink)
            Text(desc)
                .font(AppFonts.display(13))
                .foregroundColor(AppColors.inkMuted)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
