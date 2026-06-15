import SwiftUI
import Combine
import UserNotifications
import Supabase

struct AppSettingsScreen: View {
    @State private var notificationsEnabled = AppSettingsStore.shared.notificationsEnabled
    @State private var appLanguage = AppSettingsStore.shared.appLanguage
    @StateObject private var aiConsentManager = AIDataConsentManager.shared
    /// Observed so the "Captain Voice" row's subtitle updates live when the
    /// user grants or revokes cloud-voice consent from `VoiceSettingsScreen`.
    @StateObject private var voiceConsent = CaptainVoiceConsent.shared
    /// Body-photo consent observer. Drives the subtitle of `bodyPhotoRow`
    /// so the user can tell at a glance whether the dedicated cloud-vision
    /// path for plan tailoring is opted in.
    @StateObject private var bodyPhotoConsent = BodyPhotoConsent.shared
    @State private var showLogoutConfirmation = false
    @State private var showDeleteAccountConfirmation = false
    @State private var isDeletingAccount = false
    @State private var deleteAccountErrorMessage: String?
    @State private var showAcknowledgements = false
    @State private var showPrivacyPolicy = false
    @State private var showTermsOfService = false
    #if DEBUG
    @State private var showOnDeviceLab = false
    @AppStorage("debug.forceFreeTier") private var forceFreeTier = false
    #endif
    @AppStorage("notificationLanguage") private var notificationLanguage = CoachNotificationLanguage.arabic.rawValue

    var body: some View {
        Form {
            Section(
                NSLocalizedString(
                    "settings.section.notifications",
                    value: "Notifications",
                    comment: ""
                )
            ) {
                Toggle(
                    isOn: $notificationsEnabled,
                    label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(
                                NSLocalizedString(
                                    "settings.notifications.title",
                                    value: "Notifications",
                                    comment: ""
                                )
                            )
                            Text(
                                NSLocalizedString(
                                    "settings.notifications.subtitle",
                                    value: "Daily activity reminders",
                                    comment: ""
                                )
                            )
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        }
                    }
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text(
                        NSLocalizedString(
                            "settings.coachLanguage",
                            value: "Coach Language / لغة الكابتن",
                            comment: ""
                        )
                    )
                    .font(.subheadline.weight(.semibold))

                    Picker(NSLocalizedString("settings.coachLanguage", value: "Coach Language / لغة الكابتن", comment: ""), selection: $notificationLanguage) {
                        Text(NSLocalizedString("settings.coachLang.arabic", comment: ""))
                            .tag(CoachNotificationLanguage.arabic.rawValue)
                        Text(NSLocalizedString("settings.coachLang.english", comment: ""))
                            .tag(CoachNotificationLanguage.english.rawValue)
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.vertical, 4)
            }

            Section(
                NSLocalizedString(
                    "settings.section.language",
                    value: "Language",
                    comment: ""
                )
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(
                        NSLocalizedString(
                            "settings.language.title",
                            value: "App Language",
                            comment: ""
                        )
                    )

                    Picker(
                        NSLocalizedString(
                            "settings.language.title",
                            value: "App Language",
                            comment: ""
                        ),
                        selection: $appLanguage
                    ) {
                        Text(
                            NSLocalizedString(
                                "settings.language.ar",
                                value: "Arabic",
                                comment: ""
                            )
                        )
                        .tag(AppLanguage.arabic)

                        Text(
                            NSLocalizedString(
                                "settings.language.en",
                                value: "English",
                                comment: ""
                            )
                        )
                        .tag(AppLanguage.english)
                    }
                    .pickerStyle(.segmented)

                    Text(
                        NSLocalizedString(
                            "settings.language.subtitle",
                            value: "Arabic / English",
                            comment: ""
                        )
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section(
                NSLocalizedString("settings.section.captain", value: "كابتن حمّودي", comment: "Captain section")
            ) {
                NavigationLink {
                    CaptainMemorySettingsView()
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(NSLocalizedString("settings.captainMemory", value: "ذاكرة الكابتن 🧠", comment: "Captain memory title"))
                                .foregroundStyle(.primary)

                            Text(NSLocalizedString("settings.captainMemory.subtitle", value: "المعلومات اللي يتذكرها الكابتن عشان يساعدك أحسن", comment: "Captain memory subtitle"))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "brain")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }

            Section(
                NSLocalizedString(
                    "settings.section.privacyAI",
                    value: "Privacy & AI Data",
                    comment: "Privacy and AI data settings section"
                )
            ) {
                NavigationLink {
                    MedicalDisclaimerDetailView(mode: .settings)
                } label: {
                    let isArabic = AppSettingsStore.shared.appLanguage == .arabic
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(isArabic ? "الإخلاء الطبي" : "Medical disclaimer")
                                .foregroundStyle(.primary)

                            Text(isArabic
                                 ? "AiQo ليس جهازاً طبياً — راجع التنبيه الكامل"
                                 : "AiQo is not a medical device — review the full notice")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "heart.text.square")
                            .foregroundStyle(Color(red: 0.718, green: 0.898, blue: 0.824))
                    }
                    .padding(.vertical, 4)
                }

                NavigationLink {
                    AIDataPrivacySettingsView()
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(
                                NSLocalizedString(
                                    "settings.privacyAI.title",
                                    value: "AI Data Use",
                                    comment: "AI data use settings title"
                                )
                            )
                            .foregroundStyle(.primary)

                            Text(aiConsentStatusSubtitle)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "lock.shield")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                captainVoiceRow
                bodyPhotoRow

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(
                            NSLocalizedString(
                                "settings.privacy.learningVerification.title",
                                value: "تحقق كابتن حمودي",
                                comment: "Captain Hamoudi on-device certificate verification toggle"
                            )
                        )
                        .foregroundStyle(.primary)

                        Text(
                            NSLocalizedString(
                                "settings.privacy.learningVerification.subtitle",
                                value: "تحليل شهادات الكورسات يصير مباشرة على جهازك، الصورة ما تغادر الهاتف.",
                                comment: "On-device learning verification explanation"
                            )
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle(
                        "",
                        isOn: Binding(
                            get: { OnDeviceVerificationConsent.hasConsented },
                            set: { newValue in
                                if newValue {
                                    OnDeviceVerificationConsent.grant()
                                } else {
                                    OnDeviceVerificationConsent.revoke()
                                }
                            }
                        )
                    )
                    .labelsHidden()
                }
                .padding(.vertical, 4)
            }

            Section("referral.section".localized) {
                ReferralSettingsRow()
            }

            Section(
                NSLocalizedString(
                    "settings.section.account",
                    value: "Account",
                    comment: "Settings account section"
                )
            ) {
                Button {
                    showLogoutConfirmation = true
                } label: {
                    HStack {
                        Text(
                            NSLocalizedString(
                                "settings.logout",
                                value: "Log Out",
                                comment: "Logout button"
                            )
                        )
                        .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)

                Button {
                    showDeleteAccountConfirmation = true
                } label: {
                    HStack {
                        Text(
                            NSLocalizedString(
                                "settings.deleteAccount",
                                value: "Delete Account",
                                comment: "Delete account button"
                            )
                        )
                        .foregroundStyle(.red)
                        Spacer()
                        if isDeletingAccount {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .disabled(isDeletingAccount)
            }

            Section("legal.section".localized) {
                Button {
                    showPrivacyPolicy = true
                } label: {
                    HStack(spacing: 12) {
                        Text("legal.privacy.title".localized)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "lock.shield")
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)

                Button {
                    showTermsOfService = true
                } label: {
                    HStack(spacing: 12) {
                        Text("legal.terms.title".localized)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "doc.text")
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)

                Button {
                    showAcknowledgements = true
                } label: {
                    HStack {
                        Text("settings.legal.acknowledgements".localized)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }

            #if DEBUG
            Section("🧪 Developer") {
                Toggle("فرض الوضع المجاني (Captain على الجهاز)", isOn: $forceFreeTier)
                    .onChange(of: forceFreeTier) { _, _ in
                        // The flag persists in UserDefaults and TierGate reads it
                        // live; nudge the entitlement publisher so the Captain
                        // avatar / tier-gated views re-render now, not next launch.
                        EntitlementStore.shared.objectWillChange.send()
                    }
                Button {
                    showOnDeviceLab = true
                } label: {
                    HStack {
                        Text("مختبر حمودي على الجهاز")
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "flask")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
            #endif
        }
        .navigationTitle(
            NSLocalizedString(
                "settings.title",
                value: "App Settings",
                comment: ""
            )
        )
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if UserDefaults.standard.string(forKey: "notificationLanguage") == nil {
                let inferred = NotificationPreferencesStore.shared.language == .english
                    ? CoachNotificationLanguage.english
                    : CoachNotificationLanguage.arabic
                notificationLanguage = inferred.rawValue
            }
        }
        .onChange(of: notificationsEnabled) { _, enabled in
            AppSettingsStore.shared.notificationsEnabled = enabled

            if enabled {
                NotificationService.shared.requestPermissions()
                SmartNotificationScheduler.shared.refreshAutomationState()
            } else {
                SmartNotificationScheduler.shared.cancelScheduledBackgroundTasks()
                UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                UNUserNotificationCenter.current().removeAllDeliveredNotifications()
            }
        }
        .onChange(of: appLanguage) { _, language in
            LocalizationManager.shared.setLanguage(language)

            if notificationsEnabled {
                SmartNotificationScheduler.shared.refreshAutomationState()
            }

            if UserDefaults.standard.string(forKey: "notificationLanguage") == nil {
                notificationLanguage = language == .english
                    ? CoachNotificationLanguage.english.rawValue
                    : CoachNotificationLanguage.arabic.rawValue
            }
        }
        .onChange(of: notificationLanguage) { _, language in
            let normalized = CoachNotificationLanguage(rawValue: language) ?? .arabic
            NotificationPreferencesStore.shared.language = normalized == .english ? .english : .arabic
            if notificationsEnabled {
                SmartNotificationScheduler.shared.refreshAutomationState()
            }
        }
        .alert(
            NSLocalizedString("settings.logout.title", value: "Log Out", comment: ""),
            isPresented: $showLogoutConfirmation
        ) {
            Button(NSLocalizedString("settings.logout.confirm", value: "Log Out", comment: ""), role: .destructive) {
                AppFlowController.shared.logout()
            }
            Button(NSLocalizedString("settings.cancel", value: "Cancel", comment: ""), role: .cancel) { }
        } message: {
            Text(
                NSLocalizedString(
                    "settings.logout.message",
                    value: "Are you sure you want to log out?",
                    comment: ""
                )
            )
        }
        .alert(
            NSLocalizedString("settings.deleteAccount.title", value: "Delete Account", comment: ""),
            isPresented: $showDeleteAccountConfirmation
        ) {
            Button(NSLocalizedString("settings.deleteAccount.confirm", value: "Delete", comment: ""), role: .destructive) {
                deleteAccount()
            }
            Button(NSLocalizedString("settings.cancel", value: "Cancel", comment: ""), role: .cancel) { }
        } message: {
            Text(
                NSLocalizedString(
                    "settings.deleteAccount.message",
                    value: "This will permanently delete your account and all associated data. This action cannot be undone.",
                    comment: ""
                )
            )
        }
        .alert(
            NSLocalizedString("settings.deleteAccount.error.title", value: "Couldn't delete account", comment: ""),
            isPresented: Binding(
                get: { deleteAccountErrorMessage != nil },
                set: { if !$0 { deleteAccountErrorMessage = nil } }
            )
        ) {
            Button(NSLocalizedString("settings.ok", value: "OK", comment: ""), role: .cancel) {
                deleteAccountErrorMessage = nil
            }
        } message: {
            Text(deleteAccountErrorMessage ?? "")
        }
        .sheet(isPresented: $showAcknowledgements) {
            LegalView(type: .acknowledgements)
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            LegalView(type: .privacyPolicy)
        }
        .sheet(isPresented: $showTermsOfService) {
            LegalView(type: .termsOfService)
        }
        #if DEBUG
        .sheet(isPresented: $showOnDeviceLab) {
            OnDeviceCaptainLabView()
        }
        #endif
    }

    private func deleteAccount() {
        isDeletingAccount = true

        Task {
            do {
                // Call Supabase RPC to delete user data and mark account for deletion
                try await SupabaseService.shared.client
                    .rpc("delete_user_account")
                    .execute()
            } catch {
                #if DEBUG
                print("Account deletion RPC failed:", error)
                #endif
                // The confirmation promised PERMANENT deletion. If the server
                // call fails we must NOT sign the user out and imply success —
                // their data still exists. Surface the failure so they can retry
                // (App Store Guideline 5.1.1(v): deletion must actually work).
                await MainActor.run {
                    isDeletingAccount = false
                    deleteAccountErrorMessage = NSLocalizedString(
                        "settings.deleteAccount.error.message",
                        value: "We couldn't delete your account right now. Please check your connection and try again, or contact support if this keeps happening.",
                        comment: "Account deletion failure"
                    )
                }
                return
            }

            await MainActor.run {
                isDeletingAccount = false
                AppFlowController.shared.logout()
            }
        }
    }

}

private extension AppSettingsScreen {
    var aiConsentStatusSubtitle: String {
        if let acceptedAt = aiConsentManager.acceptedAt {
            return String(
                format: NSLocalizedString(
                    "settings.privacyAI.acceptedAt",
                    value: "Consent active since %@",
                    comment: "AI consent accepted status"
                ),
                acceptedAt.formatted(date: .abbreviated, time: .shortened)
            )
        }

        return NSLocalizedString(
            "settings.privacyAI.notAccepted",
            value: "Review what is shared before using cloud AI features",
            comment: "AI consent missing status"
        )
    }

    /// Dedicated "Captain Voice" row under Privacy & AI Data. The subtitle
    /// reflects live state from `CaptainVoiceConsent` so the user can tell
    /// at a glance whether cloud voice is active, local-only, or gated off
    /// by the `CAPTAIN_VOICE_CLOUD_ENABLED` feature flag.
    @ViewBuilder
    var captainVoiceRow: some View {
        NavigationLink {
            VoiceSettingsScreen()
        } label: {
            let isArabic = AppSettingsStore.shared.appLanguage == .arabic
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isArabic ? "صوت الكابتن" : "Captain Voice")
                        .foregroundStyle(.primary)

                    Text(captainVoiceSubtitle(isArabic: isArabic))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "waveform")
                    .foregroundStyle(AiQoColors.mintSoft)
            }
            .padding(.vertical, 4)
        }
    }

    func captainVoiceSubtitle(isArabic: Bool) -> String {
        if !FeatureFlags.captainVoiceCloudEnabled {
            return isArabic ? "قريباً" : "Coming soon"
        }
        if voiceConsent.isGranted {
            return isArabic ? "الصوت المحسّن مفعّل" : "Enhanced voice on"
        }
        return isArabic ? "الصوت المحلي فقط" : "Local voice only"
    }

    /// Dedicated row for the body-photo consent (Plan tailoring via Gemini
    /// vision). Sibling of `captainVoiceRow` under Privacy & AI Data; the
    /// subtitle reflects live `BodyPhotoConsent` state.
    @ViewBuilder
    var bodyPhotoRow: some View {
        NavigationLink {
            BodyPhotoSettingsScreen()
        } label: {
            let isArabic = AppSettingsStore.shared.appLanguage == .arabic
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isArabic ? "صورة الجسم (الخطة)" : "Body photo (Plan)")
                        .foregroundStyle(.primary)

                    Text(bodyPhotoSubtitle(isArabic: isArabic))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "person.crop.rectangle.stack")
                    .foregroundStyle(AiQoColors.mintSoft)
            }
            .padding(.vertical, 4)
        }
    }

    func bodyPhotoSubtitle(isArabic: Bool) -> String {
        if bodyPhotoConsent.isGranted {
            return isArabic ? "إرسال صورة الجسم مفعّل" : "Body photo sending on"
        }
        return isArabic ? "الخطط بدون صورة" : "Plans without a photo"
    }
}

#Preview {
    NavigationStack {
        AppSettingsScreen()
    }
}
