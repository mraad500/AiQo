import SwiftUI
import UserNotifications
import Supabase

struct AppSettingsScreen: View {
    @State private var notificationsEnabled = AppSettingsStore.shared.notificationsEnabled
    @State private var appLanguage = AppSettingsStore.shared.appLanguage
    @State private var showDeveloperPanel = false
    @State private var showLogoutConfirmation = false
    @State private var showDeleteAccountConfirmation = false
    @State private var isDeletingAccount = false
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
                    BriefingSettingsView()
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(appLanguage == .arabic ? "إشعارات الكابتن" : "Captain Notifications")
                                .foregroundStyle(.primary)

                            Text(appLanguage == .arabic ? "أربع رسائل تحفيزية باليوم" : "Up to 4 motivational messages daily")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "bell.badge")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

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
        .onChange(of: notificationsEnabled) { _, enabled in
            AppSettingsStore.shared.notificationsEnabled = enabled

            if !enabled {
                UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                UNUserNotificationCenter.current().removeAllDeliveredNotifications()
            }
        }
        .onChange(of: appLanguage) { _, language in
            LocalizationManager.shared.setLanguage(language)

            if UserDefaults.standard.string(forKey: "notificationLanguage") == nil {
                notificationLanguage = language == .english
                    ? CoachNotificationLanguage.english.rawValue
                    : CoachNotificationLanguage.arabic.rawValue
            }

            // Refresh notification categories and reschedule for new language
            WorkoutSummaryNotifier.shared.refreshCategoryForCurrentLanguage()
            Task { await CaptainBriefingScheduler.shared.rescheduleAll() }
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
}

#Preview {
    NavigationStack {
        AppSettingsScreen()
    }
}
