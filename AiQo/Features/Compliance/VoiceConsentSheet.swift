import SwiftUI

/// First-run consent sheet for the MiniMax cloud voice tier. Presented the
/// first time the user triggers a premium-voice action (chat speaker icon,
/// workout summary replay) while `CaptainVoiceConsent.isGranted` is still
/// `false`.
///
/// Apple 5.1.2(II) compliance: the sheet is dedicated to the cloud-voice
/// decision — no bundling with general AI Data Use consent. The copy is
/// bilingual (auto-detected from `AppSettingsStore.shared.appLanguage`) and
/// RTL-first. Dismissal is gesture-locked (`.interactiveDismissDisabled`)
/// so the user has to make an explicit grant / keep-local choice; that
/// choice is the whole point of the sheet.
struct VoiceConsentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var consent = CaptainVoiceConsent.shared
    @State private var showPrivacyPolicy = false

    /// Called after the user grants consent. Lets the presenter re-kick the
    /// pending speak attempt that triggered the sheet.
    var onGranted: () -> Void = {}

    private var isArabic: Bool {
        AppSettingsStore.shared.appLanguage == .arabic
    }

    private var layoutDirection: LayoutDirection {
        isArabic ? .rightToLeft : .leftToRight
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                header
                rows
                privacyPolicyLink
                Spacer(minLength: 12)
                primaryCTA
                secondaryCTA
            }
            .padding(24)
        }
        .background(.ultraThinMaterial)
        .environment(\.layoutDirection, layoutDirection)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .interactiveDismissDisabled(true)
        .sheet(isPresented: $showPrivacyPolicy) {
            LegalView(type: .privacyPolicy)
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "waveform")
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(AiQoColors.mintSoft)
                .padding(.bottom, 4)
                .accessibilityHidden(true)

            Text(isArabic ? "صوت الكابتن المحسّن" : "Enhanced Captain Voice")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text(isArabic
                 ? "وافق مرّة واحدة لتفعيل الصوت السحابي على ردود كابتن حمودي. تقدر تلغي الموافقة أي وقت من الإعدادات."
                 : "Grant once to enable cloud voice on Captain Hamoudi's replies. You can revoke consent anytime from Settings.")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: 14) {
            consentRow(
                icon: "waveform",
                title: isArabic ? "ما يُرسل" : "What's sent",
                body: isArabic
                    ? "نص الرد فقط — بعد التنقيح من الأسماء الشخصية."
                    : "The response text only — after personal names are stripped."
            )
            consentRow(
                icon: "lock.shield",
                title: isArabic ? "ما لا يُرسل" : "What's NOT sent",
                body: isArabic
                    ? "بيانات الصحة، الاسم، الموقع، أو أي معرّفات شخصية."
                    : "Health data, your name, location, or any personal identifiers."
            )
            consentRow(
                icon: "arrow.triangle.2.circlepath",
                title: isArabic ? "تخزين مؤقت" : "Local cache",
                body: isArabic
                    ? "يُحفظ الصوت مؤقتاً على جهازك لتوفير الإنترنت عند إعادة التشغيل."
                    : "Audio is cached locally to save bandwidth on replays."
            )
            consentRow(
                icon: "hand.raised",
                title: isArabic ? "الإيقاف" : "Revoke anytime",
                body: isArabic
                    ? "الإعدادات › صوت الكابتن. يُمسح التخزين المؤقت تلقائياً عند الإلغاء."
                    : "Settings › Captain Voice. The cache is wiped automatically on revoke."
            )
        }
    }

    private func consentRow(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AiQoColors.mintSoft)
                .frame(width: 24, height: 24)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text(body)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var privacyPolicyLink: some View {
        Button {
            showPrivacyPolicy = true
        } label: {
            Text(isArabic
                 ? "اقرأ سياسة الخصوصية لمعرفة التفاصيل"
                 : "Read the full Privacy Policy for details")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(AiQoColors.mintSoft)
                .underline()
        }
        .buttonStyle(.plain)
        .accessibilityHint(isArabic
                           ? "يفتح سياسة الخصوصية الكاملة"
                           : "Opens the full privacy policy")
    }

    private var primaryCTA: some View {
        Button {
            consent.grant()
            onGranted()
            dismiss()
        } label: {
            Text(isArabic ? "تفعيل الصوت السحابي" : "Enable cloud voice")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(AiQoColors.mintSoft.opacity(0.85))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isArabic
                            ? "تفعيل الصوت السحابي"
                            : "Enable cloud voice")
        .accessibilityHint(isArabic
                           ? "يُفعّل صوت الكابتن المحسّن من خلال خدمة MiniMax."
                           : "Turns on enhanced Captain voice via the MiniMax service.")
    }

    private var secondaryCTA: some View {
        Button {
            dismiss()
        } label: {
            Text(isArabic ? "الاكتفاء بالصوت المحلي" : "Keep local voice")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .accessibilityHint(isArabic
                           ? "يُغلق الشاشة ويحتفظ بالصوت المحلي من Apple."
                           : "Dismisses the sheet and keeps Apple's on-device voice.")
    }
}
