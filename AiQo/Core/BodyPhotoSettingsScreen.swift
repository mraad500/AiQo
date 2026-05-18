import SwiftUI

/// Settings surface for the dedicated body-photo consent. Reached via the
/// "Body photo (Plan)" row under "Privacy & AI Data" in `AppSettingsScreen`.
/// Mirrors `VoiceSettingsScreen` so the privacy story stays uniform across
/// the three per-purpose consents (AI Data, Voice, Body Photo).
struct BodyPhotoSettingsScreen: View {
    @ObservedObject private var consent = BodyPhotoConsent.shared
    @State private var showConsentSheet = false
    @State private var showRevokeConfirmation = false
    @State private var showPrivacyPolicy = false

    private var isArabic: Bool {
        AppSettingsStore.shared.appLanguage == .arabic
    }

    private var layoutDirection: LayoutDirection {
        isArabic ? .rightToLeft : .leftToRight
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                statusCard
                explainerCard
                actionButton
                privacyPolicyLink
            }
            .padding(20)
        }
        .environment(\.layoutDirection, layoutDirection)
        .navigationTitle(isArabic ? "صورة الجسم (الخطة)" : "Body photo (Plan)")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showConsentSheet) {
            BodyPhotoConsentSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            LegalView(type: .privacyPolicy)
        }
        .confirmationDialog(
            isArabic ? "إلغاء إرسال صورة الجسم؟" : "Disable body-photo sending?",
            isPresented: $showRevokeConfirmation,
            titleVisibility: .visible
        ) {
            Button(
                isArabic ? "إلغاء الموافقة" : "Revoke consent",
                role: .destructive
            ) {
                consent.revoke()
            }
            Button(isArabic ? "تراجع" : "Cancel", role: .cancel) {}
        } message: {
            Text(isArabic
                 ? "راح تكمل الخطط من دون صورة. لو رجعت تختار صورة بالمستقبل راح نسألك مرّة ثانية."
                 : "Future plans will continue without a photo. If you attach one again, we'll re-ask for consent.")
        }
    }

    // MARK: - Status card

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: consent.isGranted ? "checkmark.circle.fill" : "person.crop.rectangle.stack")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(consent.isGranted ? AiQoColors.mintSoft : .secondary)
                Text(consent.isGranted
                     ? (isArabic ? "الموافقة مفعّلة" : "Consent granted")
                     : (isArabic ? "بدون موافقة" : "Not granted"))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            }

            Text(statusBody)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let stamp = statusTimestamp {
                Text(stamp)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private var statusBody: String {
        if consent.isGranted {
            return isArabic
                ? "تكدر ترفق صورة جسم اختيارية مع طلب الخطة. الصورة تنرسل لـ Google Gemini مرّة واحدة، تنصغّر وتنزع منها بيانات GPS قبل الإرسال، وما تنحفظ على جهازك."
                : "You can attach an optional body photo when requesting a plan. It is downsized, EXIF/GPS-stripped, sent to Google Gemini once, and not stored locally."
        }
        return isArabic
            ? "ما عندك موافقة مفعّلة. الخطط راح تنبني بدون صورة. لو رفقت صورة بطلب خطة جديد، راح نطلب موافقتك."
            : "No active consent. Plans will be built without a photo. If you attach one in a future request, we'll ask for consent."
    }

    private var statusTimestamp: String? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: isArabic ? "ar" : "en")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        if consent.isGranted, let granted = consent.grantedAt {
            let label = isArabic ? "تمت الموافقة:" : "Granted:"
            return "\(label) \(formatter.string(from: granted))"
        }
        if let revoked = consent.revokedAt {
            let label = isArabic ? "تم الإلغاء:" : "Revoked:"
            return "\(label) \(formatter.string(from: revoked))"
        }
        return nil
    }

    // MARK: - Explainer

    private var explainerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            explainerRow(
                icon: "photo.on.rectangle.angled",
                title: isArabic ? "ما يُرسل" : "What's sent",
                body: isArabic
                    ? "الصورة فقط، مصغّرة وبدون بيانات EXIF أو GPS."
                    : "Just the photo — downsized and EXIF/GPS-stripped."
            )
            explainerRow(
                icon: "lock.shield",
                title: isArabic ? "ما لا يُرسل" : "What's NOT sent",
                body: isArabic
                    ? "الاسم، الموقع، أو أي معرّفات صحية مع الصورة."
                    : "Your name, location, or health identifiers tied to the photo."
            )
            explainerRow(
                icon: "internaldrive",
                title: isArabic ? "لا تُحفظ" : "Not stored",
                body: isArabic
                    ? "الصورة بالذاكرة فقط أثناء الطلب. لا على جهازك، ولا على سيرفر AiQo."
                    : "The photo lives in memory during the request. Not on disk, not on AiQo servers."
            )
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private func explainerRow(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AiQoColors.mintSoft)
                .frame(width: 22, height: 22)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(body)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Action

    private var actionButton: some View {
        Group {
            if consent.isGranted {
                Button(role: .destructive) {
                    showRevokeConfirmation = true
                } label: {
                    Text(isArabic ? "إلغاء الموافقة" : "Revoke consent")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .fill(Color.red.opacity(0.12))
                        )
                        .foregroundStyle(Color.red)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    showConsentSheet = true
                } label: {
                    Text(isArabic ? "تفعيل الموافقة" : "Grant consent")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .fill(AiQoColors.mintSoft.opacity(0.85))
                        )
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var privacyPolicyLink: some View {
        Button {
            showPrivacyPolicy = true
        } label: {
            Text(isArabic
                 ? "اقرأ سياسة الخصوصية الكاملة"
                 : "Read the full Privacy Policy")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(AiQoColors.mintSoft)
                .underline()
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }
}
