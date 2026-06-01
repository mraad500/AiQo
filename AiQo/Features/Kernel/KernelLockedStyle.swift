import SwiftUI

// MARK: - Kernel "shield is down" styling — on the AiQo identity
//
// Soft, premium treatment for the Kernel's locked state, built ENTIRELY from the
// app's pastel mint/sand DesignSystem — frosted glass, mint→sand gradients, gentle
// accent shadows, rounded corners. Calm and brand-consistent (no neon). Local to
// the Kernel feature.

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

/// A soft, on-brand frame marking the locked state — a thin mint→sand gradient
/// border with a gentle accent shadow. Calm, never neon. Non-interactive overlay.
struct KernelLockedFrame: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 44, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [AiQoTheme.Colors.accent.opacity(0.85), AiQoColors.sandSoft.opacity(0.85)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                lineWidth: 2.5
            )
            .shadow(color: AiQoTheme.Colors.accent.opacity(0.16), radius: 8)
            .padding(7)
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }
}

extension View {
    /// Overlay the soft on-brand "shield is down" frame when `active`.
    @ViewBuilder
    func kernelLockedFrame(active: Bool) -> some View {
        overlay { if active { KernelLockedFrame() } }
    }
}

// MARK: - Big shield-shaped unlock card

/// The hero of the locked state: a big shield-shaped card a tap opens the unlock
/// challenge. Frosted glass + a soft mint→sand gradient + a gentle accent glow +
/// the real step target — matching the hub's charge-ring aesthetic. Fully on the
/// AiQo identity.
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
                ZStack {
                    ShieldShape().fill(.ultraThinMaterial)
                    ShieldShape().fill(
                        LinearGradient(
                            colors: [AiQoColors.mint.opacity(0.55), AiQoColors.beige.opacity(0.40)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    ShieldShape().stroke(
                        LinearGradient(
                            colors: [AiQoTheme.Colors.accent, AiQoColors.sandSoft],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 2.5
                    )

                    VStack(spacing: AiQoSpacing.sm) {
                        Image(systemName: "bolt.shield.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(AiQoTheme.Colors.accent)
                        Text(isArabic ? "\(stepTarget) خطوة" : "\(stepTarget) steps")
                            .font(.system(size: 28, design: .rounded).weight(.bold))
                            .foregroundStyle(AiQoTheme.Colors.textPrimary)
                        Text(isArabic ? "اضغط لبدء التحدي" : "Tap to start the challenge")
                            .font(AiQoTheme.Typography.caption)
                            .foregroundStyle(AiQoTheme.Colors.textSecondary)
                    }
                    .padding(.top, AiQoSpacing.lg)
                }
                .frame(width: 240, height: 282)
                .shadow(color: AiQoTheme.Colors.accent.opacity(0.20), radius: 16, y: 6)
            }
            .buttonStyle(.plain)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isArabic ? "فكّ الدرع — \(stepTarget) خطوة" : "Unlock the shield — \(stepTarget) steps")
    }
}
