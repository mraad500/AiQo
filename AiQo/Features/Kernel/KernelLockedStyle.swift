import SwiftUI

// MARK: - Kernel "shield is down" card — iOS 26 Liquid Glass on the AiQo identity
//
// Native iOS 26 Liquid Glass (`.glassEffect`) tinted with the app's accent — depth
// and translucency, not flat fills. Local to the Kernel feature.

/// A clean heraldic shield/badge silhouette — a gently curved top crest, straight
/// upper sides, curving down to a centered point. Used for the big unlock card.
struct ShieldShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let inset = w * 0.04
        var p = Path()
        p.move(to: CGPoint(x: inset, y: h * 0.05))
        p.addQuadCurve(to: CGPoint(x: w - inset, y: h * 0.05), control: CGPoint(x: w * 0.5, y: 0))
        p.addLine(to: CGPoint(x: w, y: h * 0.30))
        p.addCurve(to: CGPoint(x: w * 0.5, y: h),
                   control1: CGPoint(x: w, y: h * 0.70),
                   control2: CGPoint(x: w * 0.72, y: h * 0.90))
        p.addCurve(to: CGPoint(x: 0, y: h * 0.30),
                   control1: CGPoint(x: w * 0.28, y: h * 0.90),
                   control2: CGPoint(x: 0, y: h * 0.70))
        p.addLine(to: CGPoint(x: inset, y: h * 0.05))
        p.closeSubpath()
        return p
    }
}

/// The hero of the locked state: a big shield-shaped **Liquid Glass** card (iOS 26),
/// tinted with the AiQo accent. A tap opens the unlock challenge.
struct KernelUnlockShieldCard: View {
    let stepTarget: Int
    let isArabic: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: AiQoSpacing.md) {
            Text(isArabic ? "فكّ الدرع" : "Unlock the shield")
                .font(AiQoTheme.Typography.sectionTitle)
                .foregroundStyle(AiQoTheme.Colors.textPrimary)

            Button(action: onTap) {
                ZStack(alignment: .top) {
                    Color.clear
                        .glassEffect(
                            .regular.tint(AiQoTheme.Colors.accent.opacity(0.28)).interactive(),
                            in: ShieldShape()
                        )
                    VStack(spacing: AiQoSpacing.xs) {
                        Image(systemName: "bolt.shield.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(AiQoTheme.Colors.accent)
                        Text(isArabic ? "\(stepTarget) خطوة" : "\(stepTarget) steps")
                            .font(.system(size: 22, design: .rounded).weight(.bold))
                            .foregroundStyle(AiQoTheme.Colors.textPrimary)
                        Text(isArabic ? "اضغط لبدء التحدي" : "Tap to start the challenge")
                            .font(AiQoTheme.Typography.caption)
                            .foregroundStyle(AiQoTheme.Colors.textSecondary)
                    }
                    .padding(.top, 34)
                }
                .frame(width: 168, height: 196)
            }
            .buttonStyle(.plain)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isArabic ? "فكّ الدرع — \(stepTarget) خطوة" : "Unlock the shield — \(stepTarget) steps")
    }
}
