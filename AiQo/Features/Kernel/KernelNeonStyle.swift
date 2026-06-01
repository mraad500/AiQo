import SwiftUI

// MARK: - Kernel "shield is down" neon identity
//
// A deliberate visual MODE for when a Kernel shield is active: the app's pastel
// green + beige pushed to a glowing neon, framing the screen edge, plus a big
// shield-shaped "unlock" card. These are LOCAL to the Kernel locked state (the
// user explicitly asked for this neon look) — NOT global DesignSystem tokens.

enum KernelNeon {
    /// Neon take on the app's pastel mint.
    static let green = Color(red: 0.20, green: 1.00, blue: 0.56)
    /// Neon take on the app's beige/sand.
    static let beige = Color(red: 1.00, green: 0.85, blue: 0.42)
}

// MARK: - Shield silhouette

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

// MARK: - Neon screen frame

/// Glowing neon frame around the whole screen edge — an outer beige strip + an
/// inner green frame, both with a soft neon glow + a gentle breathing pulse
/// (opacity-only, so it stays cheap). Non-interactive overlay.
struct KernelNeonFrame: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 54, style: .continuous)
                .strokeBorder(KernelNeon.beige, lineWidth: 9)
                .shadow(color: KernelNeon.beige.opacity(0.6), radius: 10)
            RoundedRectangle(cornerRadius: 47, style: .continuous)
                .strokeBorder(KernelNeon.green, lineWidth: 5)
                .shadow(color: KernelNeon.green.opacity(0.85), radius: 14)
                .padding(8)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .opacity(pulse ? 1.0 : 0.68)
        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulse)
        .onAppear { pulse = true }
    }
}

extension View {
    /// Overlay the neon "shield is down" frame when `active`.
    @ViewBuilder
    func kernelNeonFrame(active: Bool) -> some View {
        overlay { if active { KernelNeonFrame() } }
    }
}

// MARK: - Big shield-shaped unlock card

/// The hero of the locked state: a BIG shield-shaped card a tap opens the unlock
/// challenge. World-class treatment — frosted glass, neon edge + glow, a soft
/// breathing pulse, and the real step target inside.
struct KernelUnlockShieldCard: View {
    let stepTarget: Int
    let isArabic: Bool
    let onTap: () -> Void

    @State private var glow = false

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
                            colors: [KernelNeon.green.opacity(0.28), KernelNeon.beige.opacity(0.20)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    ShieldShape().stroke(KernelNeon.green, lineWidth: 3)

                    VStack(spacing: AiQoSpacing.sm) {
                        Image(systemName: "bolt.shield.fill")
                            .font(.system(size: 54))
                            .foregroundStyle(KernelNeon.green)
                            .shadow(color: KernelNeon.green.opacity(0.7), radius: 10)
                        Text(isArabic ? "\(stepTarget) خطوة" : "\(stepTarget) steps")
                            .font(.system(size: 28, design: .rounded).weight(.bold))
                            .foregroundStyle(AiQoTheme.Colors.textPrimary)
                        Text(isArabic ? "اضغط لبدء التحدي" : "Tap to start the challenge")
                            .font(AiQoTheme.Typography.caption)
                            .foregroundStyle(AiQoTheme.Colors.textSecondary)
                    }
                    .padding(.top, AiQoSpacing.lg)
                }
                .frame(width: 244, height: 286)
                .shadow(color: KernelNeon.green.opacity(glow ? 0.85 : 0.45), radius: glow ? 26 : 15)
            }
            .buttonStyle(.plain)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { glow = true }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isArabic ? "فكّ الدرع — \(stepTarget) خطوة" : "Unlock the shield — \(stepTarget) steps")
    }
}
