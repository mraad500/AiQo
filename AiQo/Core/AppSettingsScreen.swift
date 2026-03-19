import SwiftUI
import UserNotifications

struct AppSettingsScreen: View {
    @State private var notificationsEnabled = AppSettingsStore.shared.notificationsEnabled
    @State private var appLanguage = AppSettingsStore.shared.appLanguage
    @State private var showTribeFlow = false
    @State private var showDeveloperPanel = false
    @AppStorage("notificationLanguage") private var notificationLanguage = CoachNotificationLanguage.arabic.rawValue
    @AppStorage(TribeScreenshotMode.key) private var screenshotModeEnabled = false
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
                    Text("Coach Language / لغة الكابتن")
                        .font(.subheadline.weight(.semibold))

                    Picker("Coach Language / لغة الكابتن", selection: $notificationLanguage) {
                        Text("Arabic")
                            .tag(CoachNotificationLanguage.arabic.rawValue)
                        Text("English")
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

            Section("كابتن حمّودي") {
                NavigationLink {
                    CaptainMemorySettingsView()
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ذاكرة الكابتن 🧠")
                                .foregroundStyle(.primary)

                            Text("المعلومات اللي يتذكرها الكابتن عشان يساعدك أحسن")
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

            Section("Community") {
                Button {
                    showTribeFlow = true
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("AiQo Tribe")
                                .foregroundStyle(.primary)

                            Text("VIP community previews, rituals, and future member spaces.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "sparkles")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)

                #if DEBUG
                Toggle("Screenshot Mode", isOn: $screenshotModeEnabled)
                #endif
            }

            Section("referral.section".localized) {
                ReferralSettingsRow()
            }

            Section("legal.section".localized) {
                LegalLinksView()
                    .padding(.vertical, 4)
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
                    triggerTestSpiritualWhisper()
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Trigger Test Spiritual Whisper")
                                .foregroundStyle(.primary)

                            Text("Queues an Iraqi Arabic whisper and fires it 5 seconds after backgrounding.")
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
                rescheduleNotifications(language: appLanguage)
                NotificationIntelligenceManager.shared.scheduleBackgroundTasksIfNeeded()
            } else {
                NotificationIntelligenceManager.shared.cancelScheduledBackgroundTasks()
                UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                UNUserNotificationCenter.current().removeAllDeliveredNotifications()
            }
        }
        .onChange(of: appLanguage) { _, language in
            LocalizationManager.shared.setLanguage(language)

            if notificationsEnabled {
                rescheduleNotifications(language: language)
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
        }
        .sheet(isPresented: $showTribeFlow) {
            TribeExperienceFlowView(source: .settings)
        }
        .sheet(isPresented: $showDeveloperPanel) {
            DeveloperPanelView()
        }
    }

    private func rescheduleNotifications(language: AppLanguage) {
        ActivityNotificationEngine.shared.forceReschedule(
            gender: NotificationPreferencesStore.shared.gender,
            language: language == .english ? .english : .arabic
        )
    }

    #if DEBUG
    private func triggerTestSpiritualWhisper() {
        guard !isPreparingTestWhisper else { return }

        isPreparingTestWhisper = true
        testWhisperStatus = "Preparing test whisper..."

        Task {
            let didQueue = await NotificationIntelligenceManager.shared.queueDeveloperTestSpiritualWhisper()

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

#Preview {
    NavigationStack {
        AppSettingsScreen()
    }
}
