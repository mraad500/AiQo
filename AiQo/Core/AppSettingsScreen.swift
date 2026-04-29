import SwiftUI
import UserNotifications
import Supabase

struct AppSettingsScreen: View {
    @State private var notificationsEnabled = AppSettingsStore.shared.notificationsEnabled
    @State private var appLanguage = AppSettingsStore.shared.appLanguage
    @StateObject private var aiConsentManager = AIDataConsentManager.shared
    /// Observed so the "Captain Voice" row's subtitle updates live when the
    /// user grants or revokes cloud-voice consent from `VoiceSettingsScreen`.
    @StateObject private var voiceConsent = CaptainVoiceConsent.shared
    @State private var showDeveloperPanel = false
    @State private var showLogoutConfirmation = false
    @State private var showDeleteAccountConfirmation = false
    @State private var isDeletingAccount = false
    @State private var showAcknowledgements = false
    @AppStorage("notificationLanguage") private var notificationLanguage = CoachNotificationLanguage.arabic.rawValue
    #if DEBUG
    @State private var isPreparingTestWhisper = false
    @State private var testWhisperStatus: String?
    #endif

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
                LegalLinksView()
                    .padding(.vertical, 4)
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
            Section("debug.preview.navigation".localized) {
                Button {
                    showDeveloperPanel = true
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("debug.preview.navigation".localized)
                                .foregroundStyle(.primary)

                            Text("debug.preview.settingsHint".localized)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "hammer.fill")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)

                Button {
                    triggerTestCoachNudge()
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Trigger Test Spiritual Whisper")
                                .foregroundStyle(.primary)

                            Text("Queues an Iraqi Arabic coach nudge and fires it 5 seconds after backgrounding.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if isPreparingTestWhisper {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "bell.and.waves.left.and.right.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .disabled(isPreparingTestWhisper)

                if let testWhisperStatus {
                    Text(testWhisperStatus)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
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
        .sheet(isPresented: $showDeveloperPanel) {
            DeveloperPanelView()
        }
        .sheet(isPresented: $showAcknowledgements) {
            LegalView(type: .acknowledgements)
        }
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
                // Even if the server-side deletion fails, sign out locally.
                // The user can contact support if server-side cleanup is needed.
                #if DEBUG
                print("Account deletion RPC failed:", error)
                #endif
            }

            await MainActor.run {
                isDeletingAccount = false
                AppFlowController.shared.logout()
            }
        }
    }

    #if DEBUG
    private func triggerTestCoachNudge() {
        guard !isPreparingTestWhisper else { return }

        isPreparingTestWhisper = true
        testWhisperStatus = "Preparing test coach nudge..."

        Task {
            let didQueue = await SmartNotificationScheduler.shared.queueDeveloperTestCoachNudge()

            await MainActor.run {
                isPreparingTestWhisper = false
                testWhisperStatus = didQueue
                    ? "Ready. Send the app to the background to receive it in 5 seconds."
                    : "Notification permission is unavailable. Enable notifications for AiQo first."
            }
        }
    }
    #endif
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
}

#Preview {
    NavigationStack {
        AppSettingsScreen()
    }
}
