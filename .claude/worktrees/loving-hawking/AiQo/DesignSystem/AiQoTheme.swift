import SwiftUI
import UIKit

enum AiQoTheme {
    enum Colors {
        static let primaryBackground = Color(light: Color(hex: "F5F7FB"), dark: Color(hex: "0B1016"))
        static let surface = Color(light: .white, dark: Color(hex: "121922"))
        static let surfaceSecondary = Color(light: Color(hex: "EEF2F7"), dark: Color(hex: "18212B"))
        static let textPrimary = Color(light: Color(hex: "0F1721"), dark: Color(hex: "F6F8FB"))
        static let textSecondary = Color(light: Color(hex: "5F6F80"), dark: Color(hex: "A3AFBC"))
        static let accent = Color(light: Color(hex: "5ECDB7"), dark: Color(hex: "8AE3D1"))
        static let border = Color(light: Color.black.opacity(0.08), dark: Color.white.opacity(0.08))
        static let borderStrong = Color(light: Color.black.opacity(0.12), dark: Color.white.opacity(0.12))
        static let iconBackground = Color(light: Color(hex: "F2F6FA"), dark: Color(hex: "1A2430"))
        static let ctaGradientLeading = Color(light: Color(hex: "7CE0D2"), dark: Color(hex: "90E6D6"))
        static let ctaGradientTrailing = Color(light: Color(hex: "A4C8FF"), dark: Color(hex: "C4D9FF"))
    }

    enum Typography {
        static let screenTitle = Font.system(.title2, design: .rounded).weight(.bold)
        static let sectionTitle = Font.system(.headline, design: .rounded).weight(.semibold)
        static let cardTitle = Font.system(.headline, design: .rounded).weight(.semibold)
        static let body = Font.system(.subheadline, design: .rounded)
        static let caption = Font.system(.caption, design: .rounded)
        static let cta = Font.system(.headline, design: .rounded).weight(.semibold)
    }
}

extension Color {
    init(light: Color, dark: Color) {
        self.init(
            uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
            }
        )
    }
}
