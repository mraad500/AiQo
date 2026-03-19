import SwiftUI

// MARK: - Accessibility View Modifiers

/// يضيف VoiceOver labels ومعلومات إمكانية وصول للعناصر المشتركة
extension View {

    /// يضيف label وhint للأزرار التفاعلية
    func accessibleButton(label: String, hint: String? = nil) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(.isButton)
    }

    /// يضيف label لعناصر المعلومات الثابتة
    func accessibleInfo(label: String) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isStaticText)
    }

    /// يجعل العنصر header بالنسبة لـ VoiceOver
    func accessibleHeader(_ label: String) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isHeader)
    }

    /// يجمع عدة عناصر ببطاقة واحدة لـ VoiceOver
    func accessibleCard(label: String) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label)
    }

    /// يخفي العنصر من VoiceOver (للزخارف والأيقونات الديكورية)
    func accessibilityDecorative() -> some View {
        self
            .accessibilityHidden(true)
    }
}

// MARK: - Dynamic Type Support

/// Modifier يضمن إن النص يتكيف مع Dynamic Type
struct ScaledFontModifier: ViewModifier {
    let size: CGFloat
    let weight: Font.Weight
    let design: Font.Design

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        content
            .font(.system(size: scaledSize, weight: weight, design: design))
    }

    private var scaledSize: CGFloat {
        switch dynamicTypeSize {
        case .xSmall: return size * 0.8
        case .small: return size * 0.9
        case .medium: return size
        case .large: return size
        case .xLarge: return size * 1.1
        case .xxLarge: return size * 1.2
        case .xxxLarge: return size * 1.3
        case .accessibility1: return size * 1.4
        case .accessibility2: return size * 1.5
        case .accessibility3: return size * 1.6
        case .accessibility4: return size * 1.7
        case .accessibility5: return size * 1.8
        @unknown default: return size
        }
    }
}

extension View {
    /// فونت يتكيف مع إعدادات Dynamic Type
    func scaledFont(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .rounded) -> some View {
        modifier(ScaledFontModifier(size: size, weight: weight, design: design))
    }
}

// MARK: - Reduce Motion Support

extension View {
    /// يستبدل الأنيميشن بأخرى بسيطة لما Reduce Motion مفعّل
    func respectsReduceMotion() -> some View {
        self.transaction { transaction in
            if UIAccessibility.isReduceMotionEnabled {
                transaction.animation = nil
            }
        }
    }
}
