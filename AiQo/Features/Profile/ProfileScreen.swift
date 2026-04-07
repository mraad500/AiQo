import SwiftUI
import PhotosUI
import UIKit

struct ProfileScreen: View {
    @State var profile: UserProfile = UserProfileStore.shared.current
    @State var healthBioMetrics: HealthKitManager.BioMetrics = .empty
    @State var levelSummary = ProfileLevelSummary.load()

    @State var avatarImage: UIImage? = UserProfileStore.shared.loadAvatar()
    @State var selectedPhoto: PhotosPickerItem?

    @State var showingEditAlert = false
    @State var currentEditField: ProfileEditField = .name
    @State var editText = ""

    @State var showSettingsSheet = false
    @State var showMailComposer = false
    @State var showLevelInfo = false
    @State var showBioMetricsSheet = false
    @State var showWeeklyReport = false
    @State var showProgressPhotos = false

    // Privacy
    @State var isProfilePublic: Bool = UserProfileStore.shared.tribePrivacyMode == .public
    @State var isSyncingPrivacy = false
    @State var privacySyncFailed = false

    var body: some View {
        ZStack {
            ProfileBackdrop()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ProfileHeroCard(
                        selectedPhoto: $selectedPhoto,
                        avatarImage: avatarImage,
                        displayName: displayName,
                        displayUsername: displayUsername,
                        subtitle: NSLocalizedString(
                            "screen.profile.subtitle",
                            value: "Let’s optimize your body & mind",
                            comment: ""
                        ),
                        levelSummary: levelSummary,
                        lineScoreText: formattedLineScore,
                        onEditName: { beginEdit(.name) },
                        onLevelTap: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showLevelInfo = true
                        }
                    )

                    profileSection(
                        title: NSLocalizedString(
                            "screen.profile.section.body",
                            value: "Your Body Data",
                            comment: ""
                        )
                    ) {
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                MetricCard(
                                    title: NSLocalizedString("screen.profile.metric.age", value: "Age", comment: ""),
                                    value: ageText,
                                    symbol: "calendar",
                                    tone: .mint
                                ) {
                                    beginEdit(.age)
                                }

                                MetricCard(
                                    title: NSLocalizedString("screen.profile.metric.height", value: "Height", comment: ""),
                                    value: heightText,
                                    symbol: "ruler",
                                    tone: .mint
                                ) {
                                    beginEdit(.height)
                                }
                            }

                            HStack(spacing: 12) {
                                MetricCard(
                                    title: NSLocalizedString("screen.profile.metric.weight", value: "Weight", comment: ""),
                                    value: weightText,
                                    symbol: "scalemass",
                                    tone: .mint
                                ) {
                                    beginEdit(.weight)
                                }

                                MetricCard(
                                    title: NSLocalizedString("gender", value: "Gender", comment: ""),
                                    value: genderDisplayText,
                                    symbol: "figure.arms.open",
                                    tone: .mint
                                ) {
                                    genderBinding.wrappedValue = genderBinding.wrappedValue == .male ? .female : .male
                                }
                            }
                        }
                    }

                    profileSection(
                        title: NSLocalizedString(
                            "screen.profile.section.app",
                            value: "AiQo",
                            comment: ""
                        )
                    ) {
                        VStack(spacing: 10) {
                            AppActionRow(
                                icon: "chart.bar.doc.horizontal.fill",
                                iconFill: Color.blue.opacity(0.2),
                                title: NSLocalizedString(
                                    "screen.profile.weeklyReport.title",
                                    value: "Weekly Report",
                                    comment: ""
                                ),
                                subtitle: NSLocalizedString(
                                    "screen.profile.weeklyReport.subtitle",
                                    value: "Your weekly activity summary",
                                    comment: ""
                                )
                            ) {
                                showWeeklyReport = true
                            }

                            AppActionRow(
                                icon: "camera.viewfinder",
                                iconFill: ProfilePalette.mint.opacity(0.3),
                                title: NSLocalizedString(
                                    "screen.profile.progressPhotos.title",
                                    value: "Progress Photos",
                                    comment: ""
                                ),
                                subtitle: NSLocalizedString(
                                    "screen.profile.progressPhotos.subtitle",
                                    value: "Track your body transformation",
                                    comment: ""
                                ),
                                tone: .mint
                            ) {
                                showProgressPhotos = true
                            }

                            AppActionRow(
                                icon: "gearshape.fill",
                                iconFill: ProfilePalette.mint.opacity(0.34),
                                title: NSLocalizedString(
                                    "screen.profile.app.settings.title",
                                    value: "App Settings",
                                    comment: ""
                                ),
                                subtitle: NSLocalizedString(
                                    "screen.profile.app.settings.subtitle",
                                    value: "Notifications, units, language",
                                    comment: ""
                                )
                            ) {
                                showSettingsSheet = true
                            }

                            AppActionRow(
                                icon: "message.fill",
                                iconFill: ProfilePalette.sand.opacity(0.36),
                                title: NSLocalizedString(
                                    "screen.profile.app.support.title",
                                    value: "Contact Support",
                                    comment: ""
                                ),
                                subtitle: NSLocalizedString(
                                    "screen.profile.app.support.subtitle",
                                    value: "We’re here to help you",
                                    comment: ""
                                )
                            ) {
                                contactSupport()
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
        }
        .onAppear {
            refreshProfileState()
            refreshLevelSummary()
            HealthKitManager.shared.fetchSteps()
        }
        .task {
            await loadBioMetrics()
        }
        .onReceive(NotificationCenter.default.publisher(for: .userProfileDidChange)) { _ in
            refreshProfileState()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("XPUpdated"))) { _ in
            refreshLevelSummary()
        }
        .onReceive(NotificationCenter.default.publisher(for: .levelStoreDidChange)) { _ in
            refreshLevelSummary()
        }
        .onChange(of: selectedPhoto) { _, newItem in
            guard let newItem else { return }

            Task {
                guard let data = try? await newItem.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }

                await MainActor.run {
                    avatarImage = image
                    UserProfileStore.shared.saveAvatar(image)
                }
            }
        }
        .alert(currentEditField.title, isPresented: $showingEditAlert) {
            TextField(currentEditField.placeholder, text: $editText)
                .keyboardType(currentEditField.keyboardType)

            Button(
                NSLocalizedString("action.cancel", value: "Cancel", comment: ""),
                role: .cancel
            ) {
                editText = ""
            }

            Button(NSLocalizedString("action.save", value: "Save", comment: "")) {
                applyEditValue()
            }
        } message: {
            Text(currentEditField.message)
        }
        .alert(
            NSLocalizedString("screen.profile.level.title", value: "Level Info", comment: ""),
            isPresented: $showLevelInfo
        ) {
            Button(NSLocalizedString("action.ok", value: "OK", comment: ""), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("screen.profile.level.message", value: "Keep pushing!", comment: ""))
        }
        .sheet(isPresented: $showBioMetricsSheet) {
            BioMetricsSheet(
                currentWeight: currentWeightDisplay,
                metrics: bioMetricDetails,
                onEditWeight: {
                    showBioMetricsSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        beginEdit(.weight)
                    }
                }
            )
            .presentationDetents([.medium, .large])
            .presentationBackground(.ultraThinMaterial)
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showWeeklyReport) {
            WeeklyReportView()
                .aiQoSheetStyle()
        }
        .sheet(isPresented: $showProgressPhotos) {
            ProgressPhotosView()
                .aiQoSheetStyle()
        }
        .sheet(isPresented: $showSettingsSheet) {
            NavigationStack {
                AppSettingsScreen()
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
            .presentationBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $showMailComposer) {
            SupportMailComposer(
                to: "AppAiQo5@gmail.com",
                subject: NSLocalizedString("screen.profile.support.subject", value: "AiQo Support", comment: "")
            )
        }
    }
}

#Preview("Profile") {
    NavigationStack {
        ProfileScreen()
    }
}

#Preview("Profile RTL") {
    NavigationStack {
        ProfileScreen()
    }
    .environment(\.layoutDirection, .rightToLeft)
}
