import SwiftUI

/// Consent + onboarding sheet for «النواة». Explains the feature and that it uses
/// Family Controls (to block the user's own chosen apps) and Health (steps/heart,
/// on-device) — with explicit, revocable consent — before requesting Family
/// Controls authorization. Styled on the AiQo DesignSystem / Compliance pattern.
struct KernelConsentView: View {
    /// Called when the user explicitly agrees (then the caller requests authorization).
    var onAgree: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AiQoSpacing.lg) {
                Image(systemName: "bolt.shield.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(AiQoTheme.Colors.accent)

                Text(L("kernel.consent.title", "النواة"))
                    .font(AiQoTheme.Typography.screenTitle)
                    .foregroundStyle(AiQoTheme.Colors.textPrimary)

                Text(L("kernel.consent.subtitle", "اقفل تطبيقاتك، وافتحها بحركتك."))
                    .font(AiQoTheme.Typography.body)
                    .foregroundStyle(AiQoTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: AiQoSpacing.md) {
                    point("apps.iphone", L("kernel.consent.point.familyControls",
                        "تستخدم Family Controls لحجب التطبيقات التي تختارها أنت فقط."))
                    point("heart.text.square", L("kernel.consent.point.health",
                        "تقرأ خطواتك ونبضك من Health لتفتح بالحركة — تبقى على جهازك."))
                    point("hand.raised", L("kernel.consent.point.control",
                        "أنت تتحكم: فعّل أو أوقف في أي وقت."))
                }
                .padding(AiQoSpacing.lg)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AiQoRadius.card, style: .continuous))

                Button {
                    onAgree()
                    dismiss()
                } label: {
                    Text(L("kernel.consent.agree", "موافق، فعّل"))
                        .font(AiQoTheme.Typography.cta)
                        .frame(maxWidth: .infinity).padding(.vertical, AiQoSpacing.md)
                }
                .background(AiQoTheme.Colors.accent, in: RoundedRectangle(cornerRadius: AiQoRadius.control, style: .continuous))
                .foregroundStyle(.white)

                Button {
                    dismiss()
                } label: {
                    Text(L("kernel.consent.later", "ليس الآن"))
                        .font(AiQoTheme.Typography.body)
                        .foregroundStyle(AiQoTheme.Colors.textSecondary)
                }
            }
            .padding(AiQoSpacing.lg)
        }
        .environment(\.layoutDirection, .rightToLeft)
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

    private func L(_ key: String, _ fallback: String) -> String {
        NSLocalizedString(key, value: fallback, comment: "")
    }
}
