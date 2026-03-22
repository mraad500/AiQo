import SwiftUI
import PhotosUI
import MessageUI
import UIKit

private enum ProfileEditField {
    case name
    case age
    case height
    case weight

    var title: String {
        switch self {
        case .name:
            return NSLocalizedString("screen.profile.editName.title", value: "Your Name", comment: "")
        case .age:
            return NSLocalizedString("screen.profile.editAge.title", value: "Update Age", comment: "")
        case .height:
            return NSLocalizedString("screen.profile.editHeight.title", value: "Update Height", comment: "")
        case .weight:
            return NSLocalizedString("screen.profile.editWeight.title", value: "Update Weight", comment: "")
        }
    }

    var message: String {
        switch self {
        case .name:
            return NSLocalizedString("screen.profile.editName.message", value: "Edit your display name", comment: "")
        case .age:
            return NSLocalizedString("screen.profile.editAge.message", value: "How old are you?", comment: "")
        case .height:
            return NSLocalizedString("screen.profile.editHeight.message", value: "Enter height in cm", comment: "")
        case .weight:
            return NSLocalizedString("screen.profile.editWeight.message", value: "Enter weight in kg", comment: "")
        }
    }

    var placeholder: String {
        switch self {
        case .name:
            return NSLocalizedString("screen.profile.editName.placeholder", value: "Name", comment: "")
        case .age:
            return NSLocalizedString("screen.profile.editAge.placeholder", value: "Years", comment: "")
        case .height:
            return NSLocalizedString("screen.profile.editHeight.placeholder", value: "CM", comment: "")
        case .weight:
            return NSLocalizedString("screen.profile.editWeight.placeholder", value: "KG", comment: "")
        }
    }

    var keyboardType: UIKeyboardType {
        switch self {
        case .name:
            return .default
        case .age, .height, .weight:
            return .numberPad
        }
    }
}

private struct BioMetricDetail: Identifiable {
    let id: String
    let title: String
    let value: String
    let unit: String
    let symbol: String
    let tone: ProfileSurfaceTone

    var valueText: String {
        [value, unit]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

private struct BioScanHighlight {
    let title: String
    let value: String
    let symbol: String
}

private struct ProfileLevelSummary {
    let level: Int
    let progress: CGFloat
    let lineScore: Int

    var clampedProgress: CGFloat {
        min(max(progress, 0), 1)
    }

    static func load() -> ProfileLevelSummary {
        let storedLevel = UserDefaults.standard.integer(forKey: LevelStorageKeys.currentLevel)
        let storedProgress = UserDefaults.standard.double(forKey: LevelStorageKeys.currentLevelProgress)
        let storedScore = UserDefaults.standard.integer(forKey: LevelStorageKeys.legacyTotalPoints)

        return ProfileLevelSummary(
            level: storedLevel == 0 ? 1 : storedLevel,
            progress: CGFloat(min(max(storedProgress, 0), 1)),
            lineScore: max(storedScore, 0)
        )
    }
}

private enum ProfilePalette {
    static let backgroundTop = Color(hex: "FEFCF8")
    static let backgroundBottom = Color(hex: "F3ECE1")
    static let mint = Color(hex: "B7E3CA")
    static let sand = Color(hex: "EBC793")
    static let pearl = Color(hex: "FFF8EF")
    static let textPrimary = Color.black.opacity(0.84)
    static let textSecondary = Color.black.opacity(0.58)
    static let textTertiary = Color.black.opacity(0.38)
    static let whiteGlass = ProfilePalette.pearl.opacity(0.92)
    static let whiteSoft = ProfilePalette.pearl.opacity(0.72)
    static let stroke = Color.white.opacity(0.66)
    static let shadow = Color.black.opacity(0.04)
    static let innerGlow = Color.white.opacity(0.72)
    static let innerShade = Color.black.opacity(0.028)
}

private enum ProfileSurfaceTone {
    case sand
    case mint
    case pearl

    var gradient: [Color] {
        switch self {
        case .sand:
            return [
                ProfilePalette.sand.opacity(0.99),
                Color(hex: "F3D7AF"),
                Color(hex: "FAEEDB")
            ]
        case .mint:
            return [
                ProfilePalette.mint.opacity(0.99),
                Color(hex: "D2EEDD"),
                Color(hex: "EDF8F1")
            ]
        case .pearl:
            return [
                Color(hex: "FFFBF6"),
                Color(hex: "FCF6EE"),
                Color(hex: "F7EFE5")
            ]
        }
    }

    var shadowTint: Color {
        switch self {
        case .sand:
            return ProfilePalette.sand.opacity(0.17)
        case .mint:
            return ProfilePalette.mint.opacity(0.15)
        case .pearl:
            return Color(hex: "E2D7C6").opacity(0.28)
        }
    }

    var topSheen: Color {
        switch self {
        case .sand:
            return Color.white.opacity(0.42)
        case .mint:
            return Color.white.opacity(0.38)
        case .pearl:
            return Color.white.opacity(0.46)
        }
    }

    var bottomTint: Color {
        switch self {
        case .sand:
            return ProfilePalette.sand.opacity(0.12)
        case .mint:
            return ProfilePalette.mint.opacity(0.12)
        case .pearl:
            return Color(hex: "EEE5D8").opacity(0.26)
        }
    }

    var rimStart: Color {
        switch self {
        case .sand, .mint:
            return Color.white.opacity(0.82)
        case .pearl:
            return Color.white.opacity(0.88)
        }
    }

    var rimEnd: Color {
        switch self {
        case .sand, .mint:
            return Color.white.opacity(0.26)
        case .pearl:
            return Color.white.opacity(0.34)
        }
    }

    var materialOpacity: Double {
        switch self {
        case .sand, .mint:
            return 0.04
        case .pearl:
            return 0.10
        }
    }
}

struct ProfileScreen: View {
    @State private var profile: UserProfile = UserProfileStore.shared.current
    @State private var healthBioMetrics: HealthKitManager.BioMetrics = .empty
    @State private var levelSummary = ProfileLevelSummary.load()

    @State private var avatarImage: UIImage? = UserProfileStore.shared.loadAvatar()
    @State private var selectedPhoto: PhotosPickerItem?

    @State private var showingEditAlert = false
    @State private var currentEditField: ProfileEditField = .name
    @State private var editText = ""

    @State private var showSettingsSheet = false
    @State private var showMailComposer = false
    @State private var showLevelInfo = false
    @State private var showBioMetricsSheet = false
    @State private var showWeeklyReport = false
    @State private var showProgressPhotos = false

    // Privacy
    @State private var isProfilePublic: Bool = UserProfileStore.shared.tribePrivacyMode == .public
    @State private var isSyncingPrivacy = false
    @State private var privacySyncFailed = false

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

                    // بطاقة الـ Streak
                    StreakDetailCard()
                        .padding(.bottom, 4)

                    profileSection(
                        title: NSLocalizedString(
                            "screen.profile.section.health",
                            value: "Bio-Scan",
                            comment: ""
                        )
                    ) {
                        BioScanSummaryCard(
                            weightValue: weightNumberText,
                            weightUnit: weightUnitText,
                            subtitle: NSLocalizedString(
                                "screen.profile.bio.subtitle",
                                value: "Latest body composition synced from HealthKit",
                                comment: ""
                            ),
                            highlight: bioScanHighlight
                        ) {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showBioMetricsSheet = true
                        }
                    }

                    profileSection(
                        title: NSLocalizedString(
                            "screen.profile.section.body",
                            value: "Your Body Data",
                            comment: ""
                        )
                    ) {
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
                                tone: .sand
                            ) {
                                beginEdit(.height)
                            }
                        }
                    }

                    profileSection(
                        title: NSLocalizedString(
                            "screen.profile.section.preferences",
                            value: "Preferences",
                            comment: ""
                        )
                    ) {
                        PreferenceSelectorCard(selection: genderBinding)
                    }

                    // MARK: - Privacy Visibility Card
                    ProfileVisibilityCard(
                        isPublic: $isProfilePublic,
                        isSyncing: isSyncingPrivacy,
                        syncFailed: privacySyncFailed
                    ) { newValue in
                        toggleVisibility(newValue)
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
                                iconFill: ProfilePalette.sand.opacity(0.3),
                                title: NSLocalizedString(
                                    "screen.profile.progressPhotos.title",
                                    value: "Progress Photos",
                                    comment: ""
                                ),
                                subtitle: NSLocalizedString(
                                    "screen.profile.progressPhotos.subtitle",
                                    value: "Track your body transformation",
                                    comment: ""
                                )
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

    @ViewBuilder
    private func profileSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ProfileSectionHeader(title: title)
            content()
        }
    }

    private var bioMetricDetails: [BioMetricDetail] {
        let bodyFatMetric = metricComponents(from: healthBioMetrics.bodyFatPercentage, fallbackUnit: "%")
        let leanBodyMassMetric = metricComponents(from: healthBioMetrics.leanBodyMass, fallbackUnit: defaultWeightUnitText)
        let waterMetric = metricComponents(from: nil, fallbackUnit: "%")
        let bmrMetric = metricComponents(from: nil, fallbackUnit: "kcal")

        return [
            BioMetricDetail(
                id: "body-fat",
                title: NSLocalizedString("screen.profile.bio.bodyFat", value: "Body Fat", comment: ""),
                value: bodyFatMetric.value,
                unit: bodyFatMetric.unit,
                symbol: "drop.fill",
                tone: .sand
            ),
            BioMetricDetail(
                id: "muscle-mass",
                title: NSLocalizedString("screen.profile.bio.muscleMass", value: "Muscle Mass", comment: ""),
                value: leanBodyMassMetric.value,
                unit: leanBodyMassMetric.unit,
                symbol: "figure.strengthtraining.traditional",
                tone: .mint
            ),
            BioMetricDetail(
                id: "water",
                title: NSLocalizedString("screen.profile.bio.water", value: "Water", comment: ""),
                value: waterMetric.value,
                unit: waterMetric.unit,
                symbol: "drop.circle.fill",
                tone: .mint
            ),
            BioMetricDetail(
                id: "bmr",
                title: NSLocalizedString(
                    "screen.profile.bio.bmr",
                    value: "Basal Metabolic Rate",
                    comment: ""
                ),
                value: bmrMetric.value,
                unit: bmrMetric.unit,
                symbol: "flame.circle.fill",
                tone: .sand
            )
        ]
    }

    private var bioScanHighlight: BioScanHighlight {
        if let preferredMetric = bioMetricDetails.first(where: { $0.value != "--" }) {
            return BioScanHighlight(
                title: preferredMetric.title,
                value: preferredMetric.valueText,
                symbol: preferredMetric.symbol
            )
        }

        return BioScanHighlight(
            title: NSLocalizedString(
                "screen.profile.bio.highlightFallback",
                value: "Health snapshot",
                comment: ""
            ),
            value: "HealthKit",
            symbol: "heart.text.square.fill"
        )
    }

    private var genderBinding: Binding<ActivityNotificationGender> {
        Binding(
            get: {
                profile.gender ?? NotificationPreferencesStore.shared.gender
            },
            set: { newGender in
                NotificationPreferencesStore.shared.gender = newGender
                updateProfile { current in
                    current.gender = newGender
                }
            }
        )
    }

    private var displayName: String {
        let fallback = NSLocalizedString("default_name", value: "Captain", comment: "")
        return profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback : profile.name
    }

    private var displayUsername: String {
        let username = profile.username?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return username.isEmpty ? "@--" : "@\(username)"
    }

    private var ageText: String {
        guard profile.age > 0 else { return "--" }
        return String(
            format: NSLocalizedString("screen.profile.metric.age.value", value: "%d years", comment: ""),
            profile.age
        )
    }

    private var heightText: String {
        guard profile.heightCm > 0 else { return "--" }
        return String(
            format: NSLocalizedString("screen.profile.metric.height.value", value: "%d cm", comment: ""),
            profile.heightCm
        )
    }

    private var weightText: String {
        guard profile.weightKg > 0 else { return "--" }
        return String(
            format: NSLocalizedString("screen.profile.metric.weight.value", value: "%d kg", comment: ""),
            profile.weightKg
        )
    }

    private var currentWeightDisplay: String {
        healthBioMetrics.weight ?? weightText
    }

    private var weightNumberText: String {
        metricComponents(
            from: currentWeightDisplay,
            fallbackUnit: defaultWeightUnitText
        ).value
    }

    private var weightUnitText: String {
        metricComponents(
            from: currentWeightDisplay,
            fallbackUnit: defaultWeightUnitText
        ).unit
    }

    private var defaultWeightUnitText: String {
        NSLocalizedString("weight", value: "kg", comment: "")
    }

    private var formattedLineScore: String {
        Self.numberFormatter.string(from: NSNumber(value: levelSummary.lineScore)) ?? "\(levelSummary.lineScore)"
    }

    @MainActor
    private func loadBioMetrics() async {
        let metrics = await HealthKitManager.shared.fetchBioMetrics()
        healthBioMetrics = metrics
    }

    private func metricComponents(
        from formattedValue: String?,
        fallbackUnit: String = ""
    ) -> (value: String, unit: String) {
        let trimmed = formattedValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty, trimmed != "--" else {
            return ("--", "")
        }

        let spacedParts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        if spacedParts.count == 2 {
            return (String(spacedParts[0]), String(spacedParts[1]))
        }

        let numericPrefix = trimmed.prefix { character in
            character.isNumber || character == "." || character == "," || character == "-"
        }
        let unitSuffix = trimmed.dropFirst(numericPrefix.count).trimmingCharacters(in: .whitespacesAndNewlines)

        if !numericPrefix.isEmpty {
            return (String(numericPrefix), unitSuffix.isEmpty ? fallbackUnit : unitSuffix)
        }

        return (trimmed, fallbackUnit)
    }

    private func refreshProfileState() {
        profile = UserProfileStore.shared.current
        avatarImage = UserProfileStore.shared.loadAvatar()
        isProfilePublic = UserProfileStore.shared.tribePrivacyMode == .public
    }

    private func refreshLevelSummary() {
        levelSummary = ProfileLevelSummary.load()
    }

    private func beginEdit(_ field: ProfileEditField) {
        currentEditField = field

        switch field {
        case .name:
            editText = profile.name
        case .age:
            editText = profile.age > 0 ? "\(profile.age)" : ""
        case .height:
            editText = profile.heightCm > 0 ? "\(profile.heightCm)" : ""
        case .weight:
            editText = profile.weightKg > 0 ? "\(profile.weightKg)" : ""
        }

        showingEditAlert = true
    }

    private func applyEditValue() {
        let trimmed = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        switch currentEditField {
        case .name:
            updateProfile { $0.name = trimmed }
        case .age:
            guard let value = Int(trimmed), value > 0 else { return }
            updateProfile { $0.age = value }
        case .height:
            guard let value = Int(trimmed), value > 0 else { return }
            updateProfile { $0.heightCm = value }
        case .weight:
            guard let value = Int(trimmed), value > 0 else { return }
            updateProfile { $0.weightKg = value }
        }

        editText = ""
    }

    private func updateProfile(_ mutate: (inout UserProfile) -> Void) {
        var current = profile
        mutate(&current)
        profile = current
        UserProfileStore.shared.current = current
    }

    private func contactSupport() {
        if MFMailComposeViewController.canSendMail() {
            showMailComposer = true
            return
        }

        guard let url = URL(string: "mailto:AppAiQo5@gmail.com") else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Privacy Toggle

    private func toggleVisibility(_ newValue: Bool) {
        let previousValue = isProfilePublic

        // Optimistic UI update
        isProfilePublic = newValue
        isSyncingPrivacy = true
        privacySyncFailed = false
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        // Persist locally
        UserProfileStore.shared.setTribePrivacyMode(newValue ? .public : .private)

        // Sync to Supabase
        Task {
            do {
                try await SupabaseArenaService.shared.updateProfileVisibility(isPublic: newValue)
                await MainActor.run {
                    isSyncingPrivacy = false
                }
            } catch {
                // Revert on failure
                await MainActor.run {
                    isProfilePublic = previousValue
                    UserProfileStore.shared.setTribePrivacyMode(previousValue ? .public : .private)
                    isSyncingPrivacy = false
                    privacySyncFailed = true
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }

                // Auto-dismiss error after 3 seconds
                try? await Task.sleep(for: .seconds(3))
                await MainActor.run {
                    privacySyncFailed = false
                }
            }
        }
    }

    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        return formatter
    }()
}

// MARK: - Profile Visibility Card

private struct ProfileVisibilityCard: View {
    @Binding var isPublic: Bool
    let isSyncing: Bool
    let syncFailed: Bool
    let onToggle: (Bool) -> Void

    @Environment(\.layoutDirection) private var layoutDirection

    private var isRTL: Bool { layoutDirection == .rightToLeft }

    private var accentColor: Color {
        isPublic ? ProfilePalette.mint : ProfilePalette.sand
    }

    private var statusIcon: String {
        isPublic ? "eye.fill" : "eye.slash.fill"
    }

    private var statusText: String {
        isPublic ? "عام" : "خاص"
    }

    var body: some View {
        VStack(alignment: isRTL ? .trailing : .leading, spacing: 0) {
            // Section header
            ProfileSectionHeader(
                title: NSLocalizedString(
                    "screen.profile.section.visibility",
                    value: "Visibility",
                    comment: ""
                )
            )
            .padding(.bottom, 10)

            // Card
            VStack(spacing: 14) {
                // Top row: icon + title + toggle
                HStack(spacing: 12) {
                    if isRTL { toggleSwitch }

                    VStack(alignment: isRTL ? .trailing : .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            if !isRTL { statusBadge }

                            Text("حساب عام")
                                .font(.system(size: 15.5, weight: .black, design: .rounded))
                                .foregroundStyle(ProfilePalette.textPrimary)

                            if isRTL { statusBadge }
                        }

                        Text("تظهر للقبائل والارينا")
                            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(ProfilePalette.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)

                    if !isRTL { toggleSwitch }
                }

                // Divider
                Rectangle()
                    .fill(ProfilePalette.stroke)
                    .frame(height: 1)
                    .padding(.horizontal, 4)

                // Sub-label
                HStack(spacing: 8) {
                    if !isRTL { privacyInfoIcon }

                    Text("إيقاف هذا الخيار سيخفي اسمك الصريح ويعرض أحرفك الأولى فقط في لوحة الصدارة")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(ProfilePalette.textTertiary)
                        .multilineTextAlignment(isRTL ? .trailing : .leading)
                        .fixedSize(horizontal: false, vertical: true)

                    if isRTL { privacyInfoIcon }
                }

                // Error banner
                if syncFailed {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text("فشل التحديث — حاول مرة أخرى")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.red.opacity(0.8))
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.red.opacity(0.08))
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background {
                ProfileSurface(tone: .pearl, cornerRadius: 22)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isPublic)
        .animation(.easeInOut(duration: 0.25), value: syncFailed)
    }

    // MARK: - Sub-components

    private var toggleSwitch: some View {
        ZStack {
            if isSyncing {
                ProgressView()
                    .tint(accentColor)
                    .scaleEffect(0.8)
                    .frame(width: 51, height: 31)
            } else {
                Toggle("", isOn: Binding(
                    get: { isPublic },
                    set: { onToggle($0) }
                ))
                .toggleStyle(SwitchToggleStyle(tint: Color(hex: "B7E3CA")))
                .labelsHidden()
                .frame(width: 51)
            }
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: statusIcon)
                .font(.system(size: 9, weight: .bold))
            Text(statusText)
                .font(.system(size: 9.5, weight: .heavy, design: .rounded))
        }
        .foregroundStyle(isPublic ? Color(hex: "3BA87A") : ProfilePalette.textTertiary)
        .padding(.horizontal, 7)
        .padding(.vertical, 3.5)
        .background(
            Capsule(style: .continuous)
                .fill(accentColor.opacity(0.22))
        )
    }

    private var privacyInfoIcon: some View {
        Image(systemName: "info.circle")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(ProfilePalette.textTertiary)
    }
}

private struct ProfileBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    ProfilePalette.backgroundTop,
                    ProfilePalette.backgroundBottom
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Circle()
                .fill(ProfilePalette.mint.opacity(0.21))
                .frame(width: 240, height: 240)
                .blur(radius: 52)
                .offset(x: -148, y: -238)

            Circle()
                .fill(ProfilePalette.sand.opacity(0.20))
                .frame(width: 280, height: 280)
                .blur(radius: 56)
                .offset(x: 148, y: -110)

            RoundedRectangle(cornerRadius: 120, style: .continuous)
                .fill(Color.white.opacity(0.28))
                .frame(width: 300, height: 240)
                .blur(radius: 72)
                .offset(y: 240)
        }
    }
}

private struct ProfileHeroCard: View {
    @Binding var selectedPhoto: PhotosPickerItem?
    let avatarImage: UIImage?
    let displayName: String
    let displayUsername: String
    let subtitle: String
    let levelSummary: ProfileLevelSummary
    let lineScoreText: String
    let onEditName: () -> Void
    let onLevelTap: () -> Void

    @Environment(\.layoutDirection) private var layoutDirection

    private var isRTL: Bool {
        layoutDirection == .rightToLeft
    }

    private var textAlignment: Alignment {
        isRTL ? .trailing : .leading
    }

    private var multilineAlignment: TextAlignment {
        isRTL ? .trailing : .leading
    }

    private var shieldSymbol: String {
        LevelSystem.getShieldIconName(for: levelSummary.level)
    }

    private var progressPercentageText: String {
        "\(Int(levelSummary.clampedProgress * 100))%"
    }

    var body: some View {
        VStack(alignment: isRTL ? .trailing : .leading, spacing: 14) {
            if isRTL {
                HStack(alignment: .center, spacing: 14) {
                    identityBlock
                    avatarPicker
                }
            } else {
                HStack(alignment: .center, spacing: 14) {
                    avatarPicker
                    identityBlock
                }
            }

            Button(action: onLevelTap) {
                VStack(alignment: isRTL ? .trailing : .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        if isRTL {
                            ProfileStatPill(
                                title: NSLocalizedString("line_score", value: "Line Score", comment: ""),
                                value: lineScoreText,
                                symbol: "chart.line.uptrend.xyaxis",
                                flipsForRTL: true
                            )

                            ProfileStatPill(
                                title: NSLocalizedString("level", value: "Level", comment: ""),
                                value: "\(levelSummary.level)",
                                symbol: shieldSymbol,
                                flipsForRTL: true
                            )
                        } else {
                            ProfileStatPill(
                                title: NSLocalizedString("level", value: "Level", comment: ""),
                                value: "\(levelSummary.level)",
                                symbol: shieldSymbol
                            )

                            ProfileStatPill(
                                title: NSLocalizedString("line_score", value: "Line Score", comment: ""),
                                value: lineScoreText,
                                symbol: "chart.line.uptrend.xyaxis"
                            )
                        }
                    }

                    VStack(alignment: isRTL ? .trailing : .leading, spacing: 6) {
                        HStack {
                            Text(
                                NSLocalizedString(
                                    "screen.profile.hero.progress",
                                    value: "Progress to next level",
                                    comment: ""
                                )
                            )
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(ProfilePalette.textSecondary)

                            Spacer(minLength: 8)

                            Text(progressPercentageText)
                                .font(.system(size: 14, weight: .black, design: .rounded))
                                .foregroundStyle(ProfilePalette.textPrimary)
                                .contentTransition(.numericText())
                        }

                        ProfileProgressBar(progress: levelSummary.clampedProgress)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background {
                    ProfileInsetSurface(fill: ProfilePalette.pearl.opacity(0.54), cornerRadius: 22)
                }
            }
            .buttonStyle(ProfileCardButtonStyle())
        }
        .padding(18)
        .background {
            ProfileSurface(tone: .sand, cornerRadius: 28)
        }
    }

    private var avatarPicker: some View {
        PhotosPicker(selection: $selectedPhoto, matching: .images) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let avatarImage {
                        Image(uiImage: avatarImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(ProfilePalette.textPrimary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(ProfilePalette.pearl.opacity(0.48))
                    }
                }
                .frame(width: 82, height: 82)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.76), lineWidth: 1.5)
                }
                .shadow(color: ProfilePalette.sand.opacity(0.18), radius: 14, x: 0, y: 9)

                ProfileIconBadge(
                    symbol: "camera.fill",
                    size: 26,
                    background: ProfilePalette.pearl.opacity(0.84),
                    foreground: ProfilePalette.textPrimary
                )
                .offset(x: isRTL ? -4 : 4, y: 4)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            NSLocalizedString(
                "screen.profile.hero.avatar.action",
                value: "Change profile photo",
                comment: ""
            )
        )
    }

    private var identityBlock: some View {
        VStack(alignment: isRTL ? .trailing : .leading, spacing: 5) {
            Text(NSLocalizedString("screen.profile.chip", value: "Profile", comment: ""))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(ProfilePalette.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background {
                    ProfilePillSurface(fill: ProfilePalette.pearl.opacity(0.54))
                }

            Button(action: onEditName) {
                Text(displayName)
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(ProfilePalette.textPrimary)
                    .multilineTextAlignment(multilineAlignment)
                    .frame(maxWidth: .infinity, alignment: textAlignment)
                    .lineLimit(2)
            }
            .buttonStyle(.plain)

            Text(displayUsername)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(ProfilePalette.textSecondary)

            Text(subtitle)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(ProfilePalette.textSecondary)
                .multilineTextAlignment(multilineAlignment)
                .frame(maxWidth: .infinity, alignment: textAlignment)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: textAlignment)
    }
}

private struct BioScanSummaryCard: View {
    let weightValue: String
    let weightUnit: String
    let subtitle: String
    let highlight: BioScanHighlight
    let action: () -> Void

    @Environment(\.layoutDirection) private var layoutDirection

    private var isRTL: Bool {
        layoutDirection == .rightToLeft
    }

    private var textAlignment: Alignment {
        isRTL ? .trailing : .leading
    }

    var body: some View {
        Button(action: action) {
            Group {
                if isRTL {
                    HStack(alignment: .center, spacing: 14) {
                        actionCluster
                        bodyCopy
                    }
                } else {
                    HStack(alignment: .center, spacing: 14) {
                        bodyCopy
                        actionCluster
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background {
                ProfileSurface(tone: .mint, cornerRadius: 24)
            }
        }
        .buttonStyle(ProfileCardButtonStyle())
    }

    private var bodyCopy: some View {
        VStack(alignment: isRTL ? .trailing : .leading, spacing: 5) {
            Text(NSLocalizedString("screen.profile.metric.weight", value: "Weight", comment: ""))
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(ProfilePalette.textSecondary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(weightValue)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(ProfilePalette.textPrimary)
                    .contentTransition(.numericText())

                if !weightUnit.isEmpty {
                    Text(weightUnit)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(ProfilePalette.textSecondary)
                }
            }

            Text(subtitle)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(ProfilePalette.textSecondary)
                .multilineTextAlignment(isRTL ? .trailing : .leading)
                .frame(maxWidth: .infinity, alignment: textAlignment)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: textAlignment)
    }

    private var actionCluster: some View {
        VStack(alignment: isRTL ? .leading : .trailing, spacing: 8) {
            ProfileInsightPill(
                title: highlight.title,
                value: highlight.value,
                symbol: highlight.symbol
            )

            HStack(spacing: 8) {
                ProfileIconBadge(
                    symbol: "waveform.path.ecg.rectangle.fill",
                    size: 42,
                    background: ProfilePalette.pearl.opacity(0.5),
                    foreground: ProfilePalette.textPrimary
                )

                ProfileDisclosureBadge(size: 30)
            }
        }
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let symbol: String
    let tone: ProfileSurfaceTone
    let action: () -> Void

    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        Button(action: action) {
            VStack(alignment: layoutDirection == .rightToLeft ? .trailing : .leading, spacing: 12) {
                ProfileIconBadge(
                    symbol: symbol,
                    size: 38,
                    background: ProfilePalette.pearl.opacity(0.54),
                    foreground: ProfilePalette.textPrimary
                )

                VStack(alignment: layoutDirection == .rightToLeft ? .trailing : .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(ProfilePalette.textSecondary)

                    Text(value)
                        .font(.system(size: 19, weight: .black, design: .rounded))
                        .foregroundStyle(ProfilePalette.textPrimary)
                        .multilineTextAlignment(layoutDirection == .rightToLeft ? .trailing : .leading)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 102, alignment: layoutDirection == .rightToLeft ? .trailing : .leading)
            .padding(14)
            .background {
                ProfileSurface(tone: tone, cornerRadius: 22)
            }
        }
        .buttonStyle(ProfileCardButtonStyle())
    }
}

private struct PreferenceSelectorCard: View {
    @Binding var selection: ActivityNotificationGender

    @Environment(\.layoutDirection) private var layoutDirection

    private var isRTL: Bool {
        layoutDirection == .rightToLeft
    }

    private var displayOptions: [ActivityNotificationGender] {
        let base: [ActivityNotificationGender] = [.male, .female]
        return isRTL ? Array(base.reversed()) : base
    }

    var body: some View {
        VStack(alignment: isRTL ? .trailing : .leading, spacing: 12) {
            if isRTL {
                HStack(spacing: 10) {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(NSLocalizedString("gender", value: "Gender", comment: ""))
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(ProfilePalette.textPrimary)

                        Text(
                            NSLocalizedString(
                                "screen.profile.preferences.subtitle",
                                value: "Used for training and notification personalization",
                                comment: ""
                            )
                        )
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(ProfilePalette.textSecondary)
                        .multilineTextAlignment(.trailing)
                    }

                    Spacer(minLength: 8)

                    ProfileIconBadge(
                        symbol: "figure.arms.open",
                        size: 38,
                        background: ProfilePalette.pearl.opacity(0.46),
                        foreground: ProfilePalette.textPrimary
                    )
                }
            } else {
                HStack(spacing: 10) {
                    ProfileIconBadge(
                        symbol: "figure.arms.open",
                        size: 38,
                        background: ProfilePalette.pearl.opacity(0.46),
                        foreground: ProfilePalette.textPrimary
                    )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(NSLocalizedString("gender", value: "Gender", comment: ""))
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(ProfilePalette.textPrimary)

                        Text(
                            NSLocalizedString(
                                "screen.profile.preferences.subtitle",
                                value: "Used for training and notification personalization",
                                comment: ""
                            )
                        )
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(ProfilePalette.textSecondary)
                    }
                }
            }

            HStack(spacing: 8) {
                ForEach(displayOptions, id: \.self) { option in
                    let isSelected = option == selection

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                            selection = option
                        }
                    } label: {
                        Text(title(for: option))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(isSelected ? ProfilePalette.textPrimary : ProfilePalette.textSecondary)
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background {
                                Group {
                                    if isSelected {
                                        ProfileInsetSurface(fill: ProfilePalette.pearl.opacity(0.86), cornerRadius: 18)
                                    } else {
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .fill(ProfilePalette.pearl.opacity(0.18))
                                    }
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                }
            }
            .padding(4)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(ProfilePalette.pearl.opacity(0.22))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.42), lineWidth: 1)
                    }
            }
        }
        .padding(16)
        .background {
            ProfileSurface(tone: .mint, cornerRadius: 22)
        }
    }

    private func title(for option: ActivityNotificationGender) -> String {
        switch option {
        case .male:
            return NSLocalizedString("male", value: "Male", comment: "")
        case .female:
            return NSLocalizedString("female", value: "Female", comment: "")
        }
    }
}

private struct AppActionRow: View {
    let icon: String
    let iconFill: Color
    let title: String
    let subtitle: String
    let action: () -> Void

    @Environment(\.layoutDirection) private var layoutDirection

    private var isRTL: Bool {
        layoutDirection == .rightToLeft
    }

    var body: some View {
        Button(action: action) {
            Group {
                if isRTL {
                    HStack(spacing: 12) {
                        ProfileDisclosureBadge(size: 28)

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(title)
                                .font(.system(size: 15, weight: .black, design: .rounded))
                                .foregroundStyle(ProfilePalette.textPrimary)

                            Text(subtitle)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(ProfilePalette.textSecondary)
                                .multilineTextAlignment(.trailing)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)

                        ProfileIconBadge(
                            symbol: icon,
                            size: 38,
                            background: iconFill,
                            foreground: ProfilePalette.textPrimary
                        )
                    }
                } else {
                    HStack(spacing: 12) {
                        ProfileIconBadge(
                            symbol: icon,
                            size: 38,
                            background: iconFill,
                            foreground: ProfilePalette.textPrimary
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(title)
                                .font(.system(size: 15, weight: .black, design: .rounded))
                                .foregroundStyle(ProfilePalette.textPrimary)

                            Text(subtitle)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(ProfilePalette.textSecondary)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        ProfileDisclosureBadge(size: 28)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background {
                ProfileSurface(tone: .pearl, cornerRadius: 20)
            }
        }
        .buttonStyle(ProfileCardButtonStyle())
    }
}

private struct BioMetricsSheet: View {
    let currentWeight: String
    let metrics: [BioMetricDetail]
    let onEditWeight: () -> Void

    @Environment(\.layoutDirection) private var layoutDirection

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    private var isRTL: Bool {
        layoutDirection == .rightToLeft
    }

    var body: some View {
        ZStack {
            ProfileBackdrop()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: isRTL ? .trailing : .leading, spacing: 20) {
                    Group {
                        if isRTL {
                            HStack(alignment: .top, spacing: 12) {
                                updateButton
                                Spacer(minLength: 8)
                                headerCopy
                            }
                        } else {
                            HStack(alignment: .top, spacing: 12) {
                                headerCopy
                                Spacer(minLength: 8)
                                updateButton
                            }
                        }
                    }

                    VStack(alignment: isRTL ? .trailing : .leading, spacing: 10) {
                        Text(NSLocalizedString("screen.profile.metric.weight", value: "Weight", comment: ""))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(ProfilePalette.textSecondary)

                        Text(currentWeight)
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundStyle(ProfilePalette.textPrimary)

                        Text(
                            NSLocalizedString(
                                "screen.profile.bioSheet.caption",
                                value: "Latest body composition synced from HealthKit",
                                comment: ""
                            )
                        )
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(ProfilePalette.textSecondary)
                        .multilineTextAlignment(isRTL ? .trailing : .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
                    .padding(20)
                    .background {
                        ProfileSurface(tone: .mint, cornerRadius: 30)
                    }

                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(metrics) { metric in
                            BioMetricTile(metric: metric)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 22)
            }
        }
    }

    private var headerCopy: some View {
        VStack(alignment: isRTL ? .trailing : .leading, spacing: 6) {
            Text(
                NSLocalizedString(
                    "screen.profile.bioSheet.title",
                    value: "Bio-Scan Details",
                    comment: ""
                )
            )
            .font(.system(size: 28, weight: .black, design: .rounded))
            .foregroundStyle(ProfilePalette.textPrimary)

            Text(
                NSLocalizedString(
                    "screen.profile.bioSheet.subtitle",
                    value: "A quick look at your current body composition snapshot.",
                    comment: ""
                )
            )
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundStyle(ProfilePalette.textSecondary)
            .multilineTextAlignment(isRTL ? .trailing : .leading)
        }
    }

    private var updateButton: some View {
        Button(action: onEditWeight) {
            Text(NSLocalizedString("screen.profile.editWeight.title", value: "Update Weight", comment: ""))
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(ProfilePalette.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background {
                    ProfilePillSurface(fill: ProfilePalette.pearl.opacity(0.82))
                }
        }
        .buttonStyle(ProfileCardButtonStyle())
    }
}

private struct BioMetricTile: View {
    let metric: BioMetricDetail

    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        VStack(alignment: layoutDirection == .rightToLeft ? .trailing : .leading, spacing: 16) {
            ProfileIconBadge(
                symbol: metric.symbol,
                size: 46,
                background: ProfilePalette.pearl.opacity(0.54),
                foreground: ProfilePalette.textPrimary
            )

            VStack(alignment: layoutDirection == .rightToLeft ? .trailing : .leading, spacing: 6) {
                Text(metric.title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(ProfilePalette.textSecondary)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(metric.value)
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(ProfilePalette.textPrimary)

                    if !metric.unit.isEmpty {
                        Text(metric.unit)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(ProfilePalette.textSecondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 156, alignment: layoutDirection == .rightToLeft ? .trailing : .leading)
        .padding(18)
        .background {
            ProfileSurface(tone: metric.tone, cornerRadius: 26)
        }
    }
}

private struct ProfileSectionHeader: View {
    let title: String

    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        Text(title)
            .font(.system(size: 18, weight: .black, design: .rounded))
            .foregroundStyle(ProfilePalette.textPrimary)
            .frame(maxWidth: .infinity, alignment: layoutDirection == .rightToLeft ? .trailing : .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct ProfileStatPill: View {
    let title: String
    let value: String
    let symbol: String
    var flipsForRTL = false

    @Environment(\.layoutDirection) private var layoutDirection

    private var isRTL: Bool {
        layoutDirection == .rightToLeft
    }

    var body: some View {
        HStack(spacing: 8) {
            if isRTL && flipsForRTL {
                textBlock
                icon
            } else {
                icon
                textBlock
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background {
            ProfilePillSurface(fill: ProfilePalette.pearl.opacity(0.44))
        }
    }

    private var textBlock: some View {
        VStack(alignment: isRTL && flipsForRTL ? .trailing : .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(ProfilePalette.textSecondary)

            Text(value)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(ProfilePalette.textPrimary)
                .contentTransition(.numericText())
        }
    }

    private var icon: some View {
        ProfileIconBadge(
            symbol: symbol,
            size: 30,
            background: ProfilePalette.pearl.opacity(0.48),
            foreground: ProfilePalette.textPrimary
        )
    }
}

private struct ProfileInsightPill: View {
    let title: String
    let value: String
    let symbol: String

    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        HStack(spacing: 10) {
            ProfileIconBadge(
                symbol: symbol,
                size: 30,
                background: ProfilePalette.pearl.opacity(0.5),
                foreground: ProfilePalette.textPrimary
            )

            VStack(alignment: layoutDirection == .rightToLeft ? .trailing : .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(ProfilePalette.textSecondary)

                Text(value)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(ProfilePalette.textPrimary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background {
            ProfilePillSurface(fill: ProfilePalette.pearl.opacity(0.40))
        }
    }
}

private struct ProfilePillSurface: View {
    let fill: Color

    var body: some View {
        Capsule(style: .continuous)
            .fill(fill)
            .overlay {
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                ProfilePalette.innerGlow.opacity(0.42),
                                Color.white.opacity(0.08),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .overlay {
                Capsule(style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.78),
                                Color.white.opacity(0.28)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: Color.black.opacity(0.018), radius: 6, x: 0, y: 3)
    }
}

private struct ProfileIconBadge: View {
    let symbol: String
    var size: CGFloat = 40
    var background: Color = ProfilePalette.whiteSoft
    var foreground: Color = ProfilePalette.textPrimary

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.36, style: .continuous)
            .fill(background)
            .frame(width: size, height: size)
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.36, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                ProfilePalette.innerGlow.opacity(0.36),
                                Color.white.opacity(0.08),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.34, weight: .bold))
                    .foregroundStyle(foreground)
            }
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.36, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.78),
                                Color.white.opacity(0.26)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: Color.black.opacity(0.02), radius: 7, x: 0, y: 4)
    }
}

private struct ProfileDisclosureBadge: View {
    @Environment(\.layoutDirection) private var layoutDirection
    var size: CGFloat = 32
    var background: Color = ProfilePalette.pearl.opacity(0.58)

    var body: some View {
        ProfileIconBadge(
            symbol: layoutDirection == .rightToLeft ? "chevron.left" : "chevron.right",
            size: size,
            background: background,
            foreground: ProfilePalette.textSecondary
        )
    }
}

private struct ProfileProgressBar: View {
    let progress: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let fillWidth = width * min(max(progress, 0), 1)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.36))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.34), lineWidth: 1)
                    }

                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(ProfilePalette.mint.opacity(0.22))
                    .frame(width: fillWidth)
                    .blur(radius: 2)

                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [ProfilePalette.mint, ProfilePalette.sand.opacity(0.9)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: fillWidth)

                Circle()
                    .fill(Color.white.opacity(0.94))
                    .frame(width: 12, height: 12)
                    .overlay {
                        Circle()
                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    }
                    .shadow(color: Color.black.opacity(0.10), radius: 6, x: 0, y: 3)
                    .offset(x: max(0, min(fillWidth - 12, width - 12)))
                    .opacity(progress > 0.02 ? 1 : 0)
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.88), value: progress)
        }
        .frame(height: 10)
    }
}

private struct ProfileSurface: View {
    let tone: ProfileSurfaceTone
    var cornerRadius: CGFloat = 24

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: tone.gradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                tone.topSheen,
                                Color.white.opacity(0.10),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                .clear,
                                tone.bottomTint
                            ],
                            startPoint: .center,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(tone.materialOpacity)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [tone.rimStart, tone.rimEnd],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: tone.shadowTint, radius: 18, x: 0, y: 10)
            .shadow(color: ProfilePalette.shadow, radius: 7, x: 0, y: 4)
    }
}

private struct ProfileInsetSurface: View {
    let fill: Color
    var cornerRadius: CGFloat = 20

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(fill)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                ProfilePalette.innerGlow.opacity(0.38),
                                Color.white.opacity(0.08),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.74),
                                Color.white.opacity(0.22)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: Color.black.opacity(0.022), radius: 10, x: 0, y: 5)
    }
}

private struct ProfileCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .brightness(configuration.isPressed ? -0.015 : 0)
            .animation(.spring(response: 0.24, dampingFraction: 0.88), value: configuration.isPressed)
    }
}

private struct SupportMailComposer: UIViewControllerRepresentable {
    let to: String
    let subject: String

    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: dismiss)
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.setToRecipients([to])
        controller.setSubject(subject)
        controller.mailComposeDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        private let dismiss: DismissAction

        init(dismiss: DismissAction) {
            self.dismiss = dismiss
        }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            dismiss()
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
