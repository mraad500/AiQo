import SwiftUI

/// Settings surface for the dedicated cloud-voice consent. Reached via the
/// "Captain Voice" row under "Privacy & AI Data" in `AppSettingsScreen`.
/// Shows live state, surfaces the grant/revoke flow, and — when the
/// feature flag is off — presents a "coming soon" variant so the row
/// stays discoverable without exposing a non-functional toggle.
struct VoiceSettingsScreen: View {
    @ObservedObject private var consent = CaptainVoiceConsent.shared
    @State private var showConsentSheet = false
    @State private var showRevokeConfirmation = false
    @State private var showPrivacyPolicy = false

    private var isArabic: Bool {
        AppSettingsStore.shared.appLanguage == .arabic
    }

    private var layoutDirection: LayoutDirection {
        isArabic ? .rightToLeft : .leftToRight
    }

    private var featureFlagEnabled: Bool {
        FeatureFlags.captainVoiceCloudEnabled
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                statusCard
                explainerCard
                if featureFlagEnabled {
                    actionButton
                } else {
                    comingSoonBanner
                }
                privacyPolicyLink
            }
            .padding(20)
        }
        .environment(\.layoutDirection, layoutDirection)
        .navigationTitle(isArabic ? "صوت الكابتن" : "Captain Voice")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showConsentSheet) {
            VoiceConsentSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            LegalView(type: .privacyPolicy)
        }
        .confirmationDialog(
            isArabic ? "إلغاء الصوت السحابي؟" : "Disable cloud voice?",
            isPresented: $showRevokeConfirmation,
            titleVisibility: .visible
        ) {
            Button(
                isArabic ? "إلغاء الصوت السحابي" : "Disable cloud voice",
                role: .destructive
            ) {
                consent.revoke()
            }
            Button(isArabic ? "تراجع" : "Cancel", role: .cancel) {}
        } message: {
            Text(isArabic
                 ? "سيتم مسح الصوت المؤقت من جهازك والعودة إلى الصوت المحلي فوراً."
                 : "The cached audio will be wiped and playback will fall back to the local voice immediately.")
        }
    }

    // MARK: - Status card

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: statusIcon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(statusTint)
                Text(statusTitle)
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

    private var statusIcon: String {
        if !featureFlagEnabled { return "clock.badge" }
        return consent.isGranted ? "checkmark.circle.fill" : "speaker.wave.2"
    }

    private var statusTint: Color {
        if !featureFlagEnabled { return .secondary }
        return consent.isGranted ? AiQoColors.mintSoft : .secondary
    }

    private var statusTitle: String {
        if !featureFlagEnabled {
            return isArabic ? "قريباً" : "Coming soon"
        }
        return consent.isGranted
            ? (isArabic ? "الصوت السحابي مفعّل" : "Cloud voice enabled")
            : (isArabic ? "الصوت المحلي فقط" : "Local voice only")
    }

    private var statusBody: String {
        if !featureFlagEnabled {
            return isArabic
                ? "هذه الميزة غير مفعّلة في هذا الإصدار. ستظهر هنا عند إطلاقها."
                : "This feature is gated off in the current build and will appear here when enabled."
        }
        if consent.isGranted {
            return isArabic
                ? "ردود كابتن حمودي تُقرأ بالصوت المحسّن (MiniMax). النص فقط يُرسل للخدمة، ويُخزن الصوت مؤقتاً على جهازك."
                : "Captain Hamoudi's replies play with the enhanced MiniMax voice. Only the text is sent to the service, and audio is cached locally."
        }
        return isArabic
            ? "يُستخدم صوت Apple المحلي على الجهاز. لا يُرسل أي شيء إلى الإنترنت من أجل الصوت."
            : "Apple's on-device voice is used. Nothing is sent to the internet for voice playback."
    }

    private var statusTimestamp: String? {
        guard featureFlagEnabled else { return nil }
        let formatter: (Date) -> String = { date in
            date.formatted(date: .abbreviated, time: .shortened)
        }
        if consent.isGranted, let granted = consent.grantedAt {
            return isArabic
                ? "تم التفعيل: \(formatter(granted))"
                : "Enabled on \(formatter(granted))"
        }
        if let revoked = consent.revokedAt {
            return isArabic
                ? "تم الإلغاء: \(formatter(revoked))"
                : "Revoked on \(formatter(revoked))"
        }
        return nil
    }

    // MARK: - Explainer

    private var explainerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            explainerRow(
                icon: "waveform",
                title: isArabic ? "ما يُرسل" : "What's sent",
                body: isArabic ? "نص الرد فقط، بعد التنقيح." : "Only the sanitized response text."
            )
            explainerRow(
                icon: "lock.shield",
                title: isArabic ? "ما لا يُرسل" : "What's NOT sent",
                body: isArabic
                    ? "بيانات الصحة، الاسم، الموقع، أو أي معرّفات شخصية."
                    : "Health data, your name, location, or any personal identifiers."
            )
            explainerRow(
                icon: "arrow.triangle.2.circlepath",
                title: isArabic ? "تخزين مؤقت" : "Local cache",
                body: isArabic
                    ? "يُحفظ الصوت مؤقتاً على جهازك. يُمسح تلقائياً عند الإلغاء أو تسجيل الخروج."
                    : "Audio is cached locally. Wiped automatically on revoke or sign-out."
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
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AiQoColors.mintSoft)
                .frame(width: 24, height: 24)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Text(body)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Action

    @ViewBuilder
    private var actionButton: some View {
        if consent.isGranted {
            Button {
                showRevokeConfirmation = true
            } label: {
                Text(isArabic ? "إلغاء الصوت السحابي" : "Disable cloud voice")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.red.opacity(0.10))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityHint(isArabic
                               ? "يُظهر تأكيد الإلغاء."
                               : "Shows a confirmation to disable cloud voice.")
        } else {
            Button {
                showConsentSheet = true
            } label: {
                Text(isArabic ? "تفعيل الصوت السحابي" : "Enable cloud voice")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AiQoColors.mintSoft.opacity(0.85))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityHint(isArabic
                               ? "يفتح شاشة الموافقة على الصوت السحابي."
                               : "Opens the cloud-voice consent sheet.")
        }
    }

    private var comingSoonBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.badge")
                .foregroundStyle(.secondary)
            Text(isArabic
                 ? "ستتوفر ميزة الصوت السحابي في إصدار قادم."
                 : "Cloud voice will become available in a future release.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.tertiarySystemBackground))
        )
    }

    private var privacyPolicyLink: some View {
        Button {
            showPrivacyPolicy = true
        } label: {
            Text(isArabic ? "سياسة الخصوصية" : "Privacy Policy")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(AiQoColors.mintSoft)
        }
        .buttonStyle(.plain)
    }
}
