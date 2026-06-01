import SwiftUI
import Combine

/// Intentional-friction confirmation for turning the Kernel OFF.
///
/// The whole point of the feature — and the subscription behind it — is to guard the
/// user's focus. So disabling isn't a single reflexive tap: a short MANDATORY pause +
/// a reflection let the impulse settle (the same "one sec" friction pattern proven in
/// digital-wellbeing apps). Crucially, the user can ALWAYS complete it once the pause
/// ends — Apple requires self-imposed restrictions to stay removable — but "keep my
/// commitment" is the easy, encouraged path, and swiping the sheet away keeps
/// protection on. We add friction; we never trap.
struct KernelDisableConfirmView: View {
    let onConfirmDisable: () -> Void
    @Environment(\.dismiss) private var dismiss

    /// Seconds the user must sit with the decision before the off switch arms.
    private let pauseSeconds = 20
    @State private var remaining = 20
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var isArabic: Bool { AppSettingsStore.shared.appLanguage == .arabic }
    private var canDisable: Bool { remaining <= 0 }

    var body: some View {
        VStack(spacing: AiQoSpacing.lg) {
            Spacer(minLength: 0)

            ZStack {
                Circle().stroke(AiQoColors.mintSoft.opacity(0.25), lineWidth: 9)
                Circle()
                    .trim(from: 0, to: CGFloat(pauseSeconds - remaining) / CGFloat(pauseSeconds))
                    .stroke(AiQoTheme.Colors.accent, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: remaining)
                if canDisable {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 40)).foregroundStyle(AiQoTheme.Colors.accent)
                } else {
                    Text("\(remaining)")
                        .font(.system(size: 42, design: .rounded).weight(.bold).monospacedDigit())
                        .foregroundStyle(AiQoTheme.Colors.textPrimary)
                }
            }
            .frame(width: 132, height: 132)

            Text(isArabic ? "راح تكسر التزامك اليوم" : "You're about to break today's commitment")
                .font(AiQoTheme.Typography.screenTitle)
                .foregroundStyle(AiQoTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)

            Text(isArabic
                 ? "توقّف لحظة — هاي بالضبط اللحظة اللي النواة موجودة عشانها. تنفّس وفكّر: تستاهل تكسر التزامك؟ كل الدروع راح تنفك."
                 : "Pause for a moment — this is exactly the moment the Kernel exists for. Breathe, and ask: is it worth breaking your commitment? Every shield will be lifted.")
                .font(AiQoTheme.Typography.body)
                .foregroundStyle(AiQoTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AiQoSpacing.md)

            Spacer(minLength: 0)

            VStack(spacing: AiQoSpacing.sm) {
                Button { dismiss() } label: {
                    Label(isArabic ? "لا، أكمّل التزامي 💪" : "No, keep my commitment 💪",
                          systemImage: "shield.lefthalf.filled")
                        .font(AiQoTheme.Typography.cta)
                        .frame(maxWidth: .infinity).padding(.vertical, AiQoSpacing.sm)
                }
                .buttonStyle(.glassProminent)
                .tint(AiQoTheme.Colors.accent)

                Button(role: .destructive) {
                    onConfirmDisable()
                    dismiss()
                } label: {
                    Text(canDisable
                         ? (isArabic ? "أطفئ الحماية وفُكّ الدروع" : "Turn off & lift the shields")
                         : (isArabic ? "تگدر تطفّي بعد \(remaining) ثانية" : "Available in \(remaining)s"))
                        .font(AiQoTheme.Typography.body)
                        .frame(maxWidth: .infinity).padding(.vertical, AiQoSpacing.sm)
                }
                .buttonStyle(.glass)
                .tint(.red)
                .disabled(!canDisable)
            }
        }
        .padding(AiQoSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AiQoTheme.Colors.primaryBackground.ignoresSafeArea())
        .environment(\.layoutDirection, .rightToLeft)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onReceive(timer) { _ in if remaining > 0 { remaining -= 1 } }
    }
}
