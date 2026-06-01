import SwiftUI
import Combine

/// Turning the Kernel OFF takes one quiet minute of breathing.
///
/// The point of the feature — and the subscription behind it — is to guard the
/// user's focus, so disabling isn't a reflex: a 60-second guided breath, with calm
/// coaching that surfaces one line at a time, lets the impulse pass and reminds the
/// user what their time is really worth. After the minute the off switch arms.
///
/// APPLE COMPLIANCE: a self-imposed restriction must always stay removable — this is
/// a deliberate pause, never a trap. "Keep my commitment" is the easy, encouraged
/// path, and the user can always turn off once the minute ends.
struct KernelDisableConfirmView: View {
    let onConfirmDisable: () -> Void
    @Environment(\.dismiss) private var dismiss

    private let totalSeconds = 60
    @State private var remaining = 60
    @State private var breatheIn = false
    @State private var messageIndex = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var isArabic: Bool { AppSettingsStore.shared.appLanguage == .arabic }
    private var canDisable: Bool { remaining <= 0 }

    /// World-class, calm coaching — surfaced ONE line at a time across the minute.
    private var messages: [String] {
        isArabic
            ? [
                "خذ نفس عميق… الوقت اللي تنطيه لنفسك هسه أثمن من أي شي بهديك التطبيقات.",
                "عقلك أغلى من أن يضيع بالتمرير — خلّيه يرتاح ويصفّى.",
                "إنجازاتك الكبيرة تبدأ بلحظة هدوء مثل هاي.",
                "تخيّل وين توصل لو حوّلت هالدقايق لشي تبنيه.",
                "إنت اخترت الحماية لسبب — ثق بنفسك، إنت أقوى من العادة."
            ]
            : [
                "Breathe deep… the time you give yourself now is worth more than anything those apps offer.",
                "Your mind is too valuable to lose to the scroll — let it rest and clear.",
                "Great things start with a calm moment like this.",
                "Imagine where you'd be if you turned these minutes into something you build.",
                "You chose protection for a reason — trust yourself, you're stronger than the habit."
            ]
    }
    private var currentMessage: String { messages[min(messageIndex, messages.count - 1)] }

    var body: some View {
        VStack(spacing: AiQoSpacing.lg) {
            Spacer(minLength: 0)

            ZStack {
                Circle()
                    .fill(AiQoColors.mintSoft.opacity(0.45))
                    .frame(width: breatheIn ? 230 : 140, height: breatheIn ? 230 : 140)
                    .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: breatheIn)
                VStack(spacing: 2) {
                    Text("\(remaining)")
                        .font(.system(size: 52, design: .rounded).weight(.bold).monospacedDigit())
                        .foregroundStyle(AiQoTheme.Colors.textPrimary)
                    Text(isArabic ? "ثانية" : "sec")
                        .font(AiQoTheme.Typography.caption).foregroundStyle(AiQoTheme.Colors.textSecondary)
                }
            }
            .frame(height: 244)

            Text(isArabic ? "خذ دقيقة لنفسك" : "Take a minute for yourself")
                .font(AiQoTheme.Typography.screenTitle)
                .foregroundStyle(AiQoTheme.Colors.textPrimary)

            Text(currentMessage)
                .font(AiQoTheme.Typography.body)
                .foregroundStyle(AiQoTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AiQoSpacing.md)
                .frame(minHeight: 64)
                .id(messageIndex)
                .transition(.opacity)

            Spacer(minLength: 0)

            VStack(spacing: AiQoSpacing.sm) {
                Button { dismiss() } label: {
                    Label(isArabic ? "أكمّل التزامي 💪" : "Keep my commitment 💪", systemImage: "shield.lefthalf.filled")
                        .font(AiQoTheme.Typography.cta)
                        .frame(maxWidth: .infinity).padding(.vertical, AiQoSpacing.sm)
                }
                .buttonStyle(.glassProminent).tint(AiQoTheme.Colors.accent)

                Button(role: .destructive) {
                    onConfirmDisable(); dismiss()
                } label: {
                    Text(canDisable
                         ? (isArabic ? "أطفئ الحماية وفُكّ الدروع" : "Turn off & lift the shields")
                         : (isArabic ? "تگدر تطفّي بعد \(remaining) ثانية" : "Available in \(remaining)s"))
                        .font(AiQoTheme.Typography.body)
                        .frame(maxWidth: .infinity).padding(.vertical, AiQoSpacing.sm)
                }
                .buttonStyle(.glass).tint(.red)
                .disabled(!canDisable)
            }
        }
        .padding(AiQoSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AiQoTheme.Colors.primaryBackground.ignoresSafeArea())
        .environment(\.layoutDirection, isArabic ? .rightToLeft : .leftToRight)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear { breatheIn = true }
        .onReceive(timer) { _ in
            if remaining > 0 { remaining -= 1 }
            let elapsed = totalSeconds - remaining
            let perMessage = max(1, totalSeconds / messages.count)
            let idx = min(messages.count - 1, elapsed / perMessage)
            if idx != messageIndex { withAnimation(.easeInOut(duration: 0.5)) { messageIndex = idx } }
        }
    }
}
