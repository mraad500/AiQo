import SwiftUI

/// First-time consent sheet shown before the user's body photo leaves the
/// device for the Captain plan flow.
///
/// Apple 5.1.2(II) requires per-purpose consent. This sheet is dedicated
/// to "send a body photo to Google Gemini for personalized plan
/// tailoring" — it is not bundled with the general AI Data consent or the
/// MiniMax voice consent. Gesture-locked dismissal so the user makes a
/// deliberate decision rather than swiping past.
struct BodyPhotoConsentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var consent = BodyPhotoConsent.shared
    @State private var showPrivacyPolicy = false

    /// Called after the user grants consent. Lets the presenter resume the
    /// pending plan-submission that triggered the sheet.
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
            Image(systemName: "person.crop.rectangle.stack")
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(AiQoColors.mintSoft)
                .padding(.bottom, 4)
                .accessibilityHidden(true)

            Text(isArabic ? "صورة جسم لتفصيل الخطة" : "Body photo for tailored plan")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text(isArabic
                 ? "وافق مرّة واحدة لإرسال صورتك لـ Google Gemini حتى يفصّل الكابتن خطة تناسب جسمك. تقدر تلغي الموافقة أي وقت من الإعدادات."
                 : "Grant once to send your photo to Google Gemini so Captain Hamoudi can tailor the plan to your build. You can revoke consent anytime from Settings.")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: 14) {
            consentRow(
                icon: "photo.on.rectangle.angled",
                title: isArabic ? "ما يُرسل" : "What's sent",
                body: isArabic
                    ? "صورة واحدة فقط — بعد تصغيرها وإزالة بياناتها الجغرافية. تُستخدم مرّة واحدة لتفصيل الخطة."
                    : "One photo only — downsized and stripped of EXIF/GPS metadata. Used once to tailor the plan."
            )
            consentRow(
                icon: "lock.shield",
                title: isArabic ? "ما لا يُرسل" : "What's NOT sent",
                body: isArabic
                    ? "الاسم، الموقع، أو أي بيانات صحية مرتبطة بالصورة."
                    : "Your name, location, or any health identifiers tied to the photo."
            )
            consentRow(
                icon: "internaldrive",
                title: isArabic ? "لا يُحفظ محلياً" : "Not stored locally",
                body: isArabic
                    ? "الصورة تعيش بالذاكرة فقط أثناء الطلب. ما تُحفظ على جهازك ولا على سيرفر AiQo."
                    : "The photo lives in memory only during the request. Not written to disk, not stored on AiQo servers."
            )
            consentRow(
                icon: "hand.raised",
                title: isArabic ? "الإيقاف" : "Revoke anytime",
                body: isArabic
                    ? "الإعدادات › صورة الجسم. ترجع الخطط بدون صورة، وتُحتفظ نفس قواعد الخصوصية."
                    : "Settings › Body photo. Future plans go without a photo and the same privacy rules apply."
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
            Text(isArabic ? "تفعيل وإرسال" : "Allow and send")
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
        .accessibilityLabel(isArabic ? "تفعيل وإرسال" : "Allow and send")
        .accessibilityHint(isArabic
                           ? "يفعّل إرسال صورة الجسم لـ Gemini لتفصيل الخطة."
                           : "Enables sending the body photo to Gemini for plan tailoring.")
    }

    private var secondaryCTA: some View {
        Button {
            dismiss()
        } label: {
            Text(isArabic ? "خطة بدون صورة" : "Continue without a photo")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .accessibilityHint(isArabic
                           ? "يلغي الموافقة ويُكمل الطلب بدون صورة."
                           : "Skips consent and proceeds without sending a photo.")
    }
}
