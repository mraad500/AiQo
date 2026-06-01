import SwiftUI

/// Consent + onboarding sheet for the Kernel. Explains the feature and that it uses
/// Family Controls (to block the user's own chosen apps) and Health (steps/heart,
/// on-device) — with explicit, revocable consent — before requesting Family
/// Controls authorization. Bilingual (ar/en) on the AiQo DesignSystem.
struct KernelConsentView: View {
    /// Called when the user explicitly agrees (then the caller requests authorization).
    var onAgree: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var isAr: Bool { AppSettingsStore.shared.appLanguage == .arabic }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AiQoSpacing.lg) {
                Image(systemName: "bolt.shield.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(AiQoTheme.Colors.accent)

                Text(isAr ? "النواة" : "Kernel")
                    .font(AiQoTheme.Typography.screenTitle)
                    .foregroundStyle(AiQoTheme.Colors.textPrimary)

                Text(isAr ? "اقفل تطبيقاتك، وافتحها بحركتك." : "Lock your apps, open them with your movement.")
                    .font(AiQoTheme.Typography.body)
                    .foregroundStyle(AiQoTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: AiQoSpacing.md) {
                    point("apps.iphone", isAr ? "تستخدم Family Controls لحجب التطبيقات التي تختارها أنت فقط."
                                              : "Uses Family Controls to block only the apps you choose.")
                    point("heart.text.square", isAr ? "تقرأ خطواتك ونبضك من Health لتفتح بالحركة — تبقى على جهازك."
                                                    : "Reads your steps and heart rate from Health to open with movement — stays on your device.")
                    point("hand.raised", isAr ? "أنت تتحكم: فعّل أو أوقف في أي وقت."
                                              : "You're in control: enable or turn off anytime.")
                }
                .padding(AiQoSpacing.lg)
                .frame(maxWidth: .infinity)
                .glassEffect(.regular, in: .rect(cornerRadius: AiQoRadius.card))

                Button {
                    onAgree()
                    dismiss()
                } label: {
                    Text(isAr ? "موافق، فعّل" : "Agree & enable")
                        .font(AiQoTheme.Typography.cta)
                        .frame(maxWidth: .infinity).padding(.vertical, AiQoSpacing.sm)
                }
                .buttonStyle(.glassProminent)
                .tint(AiQoTheme.Colors.accent)

                Button {
                    dismiss()
                } label: {
                    Text(isAr ? "ليس الآن" : "Not now")
                        .font(AiQoTheme.Typography.body)
                        .foregroundStyle(AiQoTheme.Colors.textSecondary)
                }
            }
            .padding(AiQoSpacing.lg)
        }
        .environment(\.layoutDirection, isAr ? .rightToLeft : .leftToRight)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func point(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: AiQoSpacing.sm) {
            Image(systemName: symbol)
                .font(.system(size: 18))
                .foregroundStyle(AiQoTheme.Colors.accent)
                .frame(width: 26)
            Text(text)
                .font(AiQoTheme.Typography.body)
                .foregroundStyle(AiQoTheme.Colors.textPrimary)
            Spacer(minLength: 0)
        }
    }
}
