import SwiftUI
import UserNotifications

struct AppSettingsScreen: View {
    @State private var notificationsEnabled = AppSettingsStore.shared.notificationsEnabled
    @State private var appLanguage = AppSettingsStore.shared.appLanguage
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
            } else {
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
    }

    private func rescheduleNotifications(language: AppLanguage) {
        ActivityNotificationEngine.shared.forceReschedule(
            gender: NotificationPreferencesStore.shared.gender,
            language: language == .english ? .english : .arabic
        )
    }
}

#Preview {
    NavigationStack {
        AppSettingsScreen()
    }
}
