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
    static let high        = Color(hex: "dc2626")   // red
    static let med         = Color(hex: "ca8a04")   // yellow
    static let low         = Color(hex: "16a34a")   // green
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

// Neo-brutalist text field: white fill, ink border, generous height.
// Height comes from vertical padding (not a fixed frame) so the AppKit
// field editor sizes naturally and typed text stays visible.
struct AppFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .foregroundColor(AppColors.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(AppColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(AppColors.borderStrong, lineWidth: 1)
                    )
            )
            // A `.plain` TextField only occupies its inner text glyph area, so the
            // surrounding padding/box added above are NOT focusable. Without this,
            // clicking in the padded margin fails to focus the field and typing
            // does nothing. `.contentShape` makes the full styled rect the hit
            // target so a click anywhere begins editing. (Same fix as the checkbox.)
            .contentShape(Rectangle())
    }
}

// Primary action button sized to match `.appField()` (same 12pt vertical
// padding → same height), so a button sitting next to a field lines up flush.
struct AppPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFonts.monoBold(11))
            .kerning(1)
            .foregroundColor(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isEnabled ? AppColors.accent : AppColors.inkFaint)
            )
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

extension View {
    func eyebrow() -> some View { modifier(EyebrowStyle()) }
    func pill(color: Color) -> some View { modifier(PillStyle(color: color)) }
    func appField() -> some View { modifier(AppFieldStyle()) }

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
