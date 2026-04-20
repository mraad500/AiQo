import SwiftUI
import UIKit

// MARK: - Accessibility View Modifiers

/// يضيف accessibility labels و hints للعناصر الشائعة بالتطبيق
extension View {

    /// يضيف accessibility لبطاقات الإحصائيات
    func accessibleMetricCard(title: String, value: String, unit: String, hint: String = "") -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title)، \(value) \(unit)")
            .accessibilityHint(hint.isEmpty ? "اضغط مرتين لعرض التفاصيل" : hint)
            .accessibilityAddTraits(.isButton)
    }

    /// يضيف accessibility لحلقات التقدم (Progress Rings)
    func accessibleProgressRing(label: String, value: Double, maxValue: Double, unit: String) -> some View {
        let percentage = Int((value / max(maxValue, 1)) * 100)
        return self
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(label)، \(String(format: "%.0f", value)) من \(String(format: "%.0f", maxValue)) \(unit)")
            .accessibilityValue("\(percentage) بالمية")
    }

    /// يضيف accessibility لأزرار التنقل
    func accessibleNavButton(label: String, hint: String = "") -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint)
            .accessibilityAddTraits(.isButton)
    }

    /// يجعل العنصر يدعم Dynamic Type بشكل أفضل
    func scaledFont(_ style: Font.TextStyle, size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> some View {
        self.font(.system(size: size, weight: weight, design: design))
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }
}

// MARK: - Accessibility Announcements

/// يرسل إعلانات VoiceOver للمستخدم
enum AiQoAccessibility {

    /// يعلن عن حدث مهم (تمرين انتهى، وجبة أُضيفت، إلخ)
    static func announce(_ message: String) {
        UIAccessibility.post(notification: .announcement, argument: message)
    }

    /// يعلن عن تغيير في الشاشة
    static func screenChanged(_ message: String? = nil) {
        UIAccessibility.post(notification: .screenChanged, argument: message)
    }

    /// يعلن عن تغيير في layout
    static func layoutChanged(_ element: Any? = nil) {
        UIAccessibility.post(notification: .layoutChanged, argument: element)
    }

    /// هل VoiceOver مفعّل؟
    static var isVoiceOverRunning: Bool {
        UIAccessibility.isVoiceOverRunning
    }

    /// هل المستخدم يفضل حركات مخففة؟
    static var prefersReducedMotion: Bool {
        UIAccessibility.isReduceMotionEnabled
    }
}

// MARK: - Glass / Liquid-Glass Background Helpers

extension View {
    /// Applies a Liquid-Glass background that collapses to an opaque colour when
    /// the user has enabled **Settings → Accessibility → Reduce Transparency**.
    /// Prefer this over raw `.background(.ultraThinMaterial)` in navigation and
    /// chrome layers. SwiftUI's `Material` already adapts in many contexts, but
    /// this modifier guarantees the contract and surfaces the intent at the
    /// call-site.
    func aiqoGlassBackground(
        _ material: Material = .ultraThinMaterial,
        fallback: Color = Color(UIColor.systemBackground),
        in shape: some Shape = Rectangle()
    ) -> some View {
        modifier(AiQoGlassBackgroundModifier(material: material, fallback: fallback, shape: AnyShape(shape)))
    }
}

private struct AiQoGlassBackgroundModifier: ViewModifier {
    let material: Material
    let fallback: Color
    let shape: AnyShape
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(fallback, in: shape)
        } else {
            content.background(material, in: shape)
        }
    }
}

// MARK: - Accessible Metric Summary (for VoiceOver)

/// يولّد نص ملخص للـ VoiceOver من بيانات اليوم
struct AccessibleDaySummary {

    static func text(
        steps: Int,
        calories: Int,
        sleepHours: Double,
        waterLiters: Double,
        distanceKm: Double
    ) -> String {
        var parts: [String] = []

        parts.append("مشيت \(steps) خطوة")

        if calories > 0 {
            parts.append("حرقت \(calories) سعرة")
        }

        if sleepHours > 0 {
            parts.append("نمت \(String(format: "%.1f", sleepHours)) ساعة")
        }

        if waterLiters > 0 {
            parts.append("شربت \(String(format: "%.1f", waterLiters)) لتر ماء")
        }

        if distanceKm > 0 {
            parts.append("مشيت \(String(format: "%.1f", distanceKm)) كيلومتر")
        }

        return parts.joined(separator: "، ")
    }
}
