import SwiftUI

// MARK: - Colors

enum AppColors {
    static let bg          = Color(hex: "fafaf7")
    static let surface     = Color.white
    static let ink         = Color(hex: "0f172a")
    static let inkMuted    = Color(hex: "64748b")
    static let inkFaint    = Color(hex: "94a3b8")
    static let accent      = Color(hex: "0891b2")
    static let accentBg    = Color(hex: "e0f2fe")
    static let high        = Color(hex: "dc2626")
    static let med         = Color(hex: "d97706")
    static let low         = Color(hex: "0891b2")
    static let borderWeak  = Color(hex: "0f172a").opacity(0.08)
    static let borderMid   = Color(hex: "0f172a").opacity(0.12)
    static let borderStrong = Color(hex: "0f172a").opacity(0.20)
}

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var n: UInt64 = 0
        Scanner(string: h).scanHexInt64(&n)
        self.init(
            red:   Double((n & 0xFF0000) >> 16) / 255,
            green: Double((n & 0x00FF00) >> 8)  / 255,
            blue:  Double( n & 0x0000FF)         / 255
        )
    }
}

extension Priority {
    var color: Color {
        switch self {
        case .high: AppColors.high
        case .med:  AppColors.med
        case .low:  AppColors.low
        }
    }
    var bgColor: Color { color.opacity(0.08) }
    var borderColor: Color { color.opacity(0.25) }
}

// MARK: - Fonts
// Requires "Instrument Serif" and "JetBrains Mono" installed on the system
// or bundled in the Xcode project under Resources.

enum AppFonts {
    static func display(_ size: CGFloat) -> Font {
        Font.custom("Instrument Serif", size: size)
    }
    static func displayItalic(_ size: CGFloat) -> Font {
        Font.custom("Instrument Serif", size: size).italic()
    }
    static func mono(_ size: CGFloat) -> Font {
        Font.custom("JetBrains Mono", size: size)
    }
    static func monoMedium(_ size: CGFloat) -> Font {
        Font.custom("JetBrains Mono", size: size).weight(.medium)
    }
    static func monoBold(_ size: CGFloat) -> Font {
        Font.custom("JetBrains Mono", size: size).weight(.semibold)
    }
}

// MARK: - View Modifiers

struct EyebrowStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AppFonts.mono(10))
            .kerning(2)
            .foregroundColor(AppColors.inkMuted)
            .textCase(.uppercase)
    }
}

struct PillStyle: ViewModifier {
    var color: Color
    func body(content: Content) -> some View {
        content
            .font(AppFonts.monoBold(10))
            .kerning(0.8)
            .foregroundColor(.white)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(color.opacity(0.4), lineWidth: 1)
            )
    }
}

extension View {
    func eyebrow() -> some View { modifier(EyebrowStyle()) }
    func pill(color: Color) -> some View { modifier(PillStyle(color: color)) }

    // Hard offset shadow (neo-brutalist, no blur).
    // Uses an offset background rectangle instead of SwiftUI's .shadow(),
    // which would ghost all text content inside the view.
    func hardShadow(x: CGFloat = 4, y: CGFloat = 4) -> some View {
        self.background(
            Rectangle()
                .fill(AppColors.ink)
                .offset(x: x, y: y)
        )
    }
}
