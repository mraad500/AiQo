import SwiftUI
import PhotosUI
import MessageUI
import UIKit

private enum ProfileEditField {
    case name
    case age
    case height
    case weight
    case goal

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
        case .goal:
            return NSLocalizedString("screen.profile.editGoal.title", value: "Daily Goal", comment: "")
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
        case .goal:
            return NSLocalizedString("screen.profile.editGoal.message", value: "Enter your goal", comment: "")
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
        case .goal:
            return NSLocalizedString("screen.profile.editGoal.placeholder", value: "e.g. 500 kcal", comment: "")
        }
    }

    var keyboardType: UIKeyboardType {
        switch self {
        case .name, .goal:
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
    let colors: [Color]
    let iconTint: Color
}

private enum ProfileCardPalette {
    static let pastelGreen = Color.aiqoMint
    static let pastelBeige = Color.aiqoSand

    static let textPrimary = Color.black.opacity(0.86)
    static let textSecondary = Color.black.opacity(0.58)
    static let textTertiary = Color.black.opacity(0.42)
    static let shadow = Color.black.opacity(0.10)
    static let badgeFill = Color.white.opacity(0.42)
}

struct ProfileScreen: View {
    @State private var profile: UserProfile = UserProfileStore.shared.current
    @State private var healthBioMetrics: HealthKitManager.BioMetrics = .empty

    @State private var avatarImage: UIImage? = UserProfileStore.shared.loadAvatar()
    @State private var selectedPhoto: PhotosPickerItem?

    @State private var showingEditAlert = false
    @State private var currentEditField: ProfileEditField = .name
    @State private var editText = ""

    @State private var showSettingsSheet = false
    @State private var showMailComposer = false
    @State private var showLevelInfo = false
    @State private var showBioMetricsSheet = false

    var body: some View {
        ZStack {
            profileBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    headerCard

                    LevelCardView()
                        .frame(height: 100)
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            showLevelInfo = true
                        }

                    weightCard
                    bodySection
                    preferencesSection
                    appSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }
        }
        .onAppear {
            refreshProfileState()
            HealthKitManager.shared.fetchSteps()
        }
        .task {
            await loadBioMetrics()
        }
        .onReceive(NotificationCenter.default.publisher(for: .userProfileDidChange)) { _ in
            refreshProfileState()
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
        }
        .sheet(isPresented: $showSettingsSheet) {
            NavigationStack {
                AppSettingsScreen()
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showMailComposer) {
            SupportMailComposer(
                to: "AppAiQo5@gmail.com",
                subject: NSLocalizedString("screen.profile.support.subject", value: "AiQo Support", comment: "")
            )
        }
    }

    private var profileBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.white,
                    Color.aiqoMint.opacity(0.18),
                    Color.aiqoLemon.opacity(0.22)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.aiqoMint.opacity(0.30))
                .frame(width: 240, height: 240)
                .blur(radius: 36)
                .offset(x: -140, y: -260)

            Circle()
                .fill(Color.aiqoSand.opacity(0.22))
                .frame(width: 280, height: 280)
                .blur(radius: 42)
                .offset(x: 150, y: -140)
        }
    }

    private var headerCard: some View {
        HStack(spacing: 16) {
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Group {
                    if let avatarImage {
                        Image(uiImage: avatarImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(ProfileCardPalette.textPrimary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.white.opacity(0.35))
                    }
                }
                .frame(width: 84, height: 84)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.75), lineWidth: 2)
                )
                .shadow(color: Color.aiqoMint.opacity(0.18), radius: 18, x: 0, y: 10)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 6) {
                Text(NSLocalizedString("screen.profile.chip", value: "Profile", comment: ""))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(ProfileCardPalette.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.55), in: Capsule())

                Button {
                    beginEdit(.name)
                } label: {
                    Text(displayName)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(ProfileCardPalette.textPrimary)
                        .multilineTextAlignment(.leading)
                }
                .buttonStyle(.plain)

                Text(displayUsername)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(ProfileCardPalette.textSecondary)

                Text(
                    NSLocalizedString(
                        "optimize_bio",
                        value: "Let's optimize your body & mind",
                        comment: ""
                    )
                )
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(ProfileCardPalette.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(22)
        .background(
            ProfileCardBackground(
                baseColor: ProfileCardPalette.pastelBeige,
                shadowColor: ProfileCardPalette.shadow
            )
        )
    }

    private var weightCard: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showBioMetricsSheet = true
        } label: {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Label(
                        NSLocalizedString("screen.profile.metric.weight", value: "Weight", comment: ""),
                        systemImage: "scalemass.fill"
                    )
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(ProfileCardPalette.textSecondary)

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(weightNumberText)
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundStyle(ProfileCardPalette.textPrimary)
                            .contentTransition(.numericText())

                        Text(weightUnitText)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(ProfileCardPalette.textSecondary)
                    }

                    Text(
                        NSLocalizedString(
                            "screen.profile.weightCard.subtitle",
                            value: "Tap to open Bio-Scan details",
                            comment: ""
                        )
                    )
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(ProfileCardPalette.textSecondary)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(ProfileCardPalette.badgeFill)
                            .frame(width: 58, height: 58)

                        Image(systemName: "waveform.path.ecg.rectangle.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(ProfileCardPalette.textPrimary)
                    }

                    HStack(spacing: 6) {
                        Text(
                            NSLocalizedString(
                                "screen.profile.weightCard.action",
                                value: "Bio-Scan",
                                comment: ""
                            )
                        )
                        .font(.system(size: 13, weight: .bold, design: .rounded))

                        Image(systemName: "chevron.up")
                            .font(.system(size: 12, weight: .black))
                    }
                    .foregroundStyle(ProfileCardPalette.textSecondary)
                }
            }
            .padding(.horizontal, 20)
            .frame(height: 92)
            .frame(maxWidth: .infinity)
            .background(
                ProfileCardBackground(
                    baseColor: ProfileCardPalette.pastelBeige,
                    cornerRadius: 26,
                    shadowColor: ProfileCardPalette.shadow
                )
            )
        }
        .buttonStyle(.plain)
    }

    private var bodySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(NSLocalizedString("body_stats", value: "Body Stats", comment: ""))

            HStack(spacing: 14) {
                ProfileMetricCard(
                    title: NSLocalizedString("screen.profile.metric.age", value: "Age", comment: ""),
                    value: ageText,
                    symbol: "calendar",
                    colors: [ProfileCardPalette.pastelGreen, ProfileCardPalette.pastelGreen.opacity(0.92)],
                    iconTint: ProfileCardPalette.textPrimary,
                    action: { beginEdit(.age) }
                )

                ProfileMetricCard(
                    title: NSLocalizedString("screen.profile.metric.height", value: "Height", comment: ""),
                    value: heightText,
                    symbol: "ruler",
                    colors: [ProfileCardPalette.pastelBeige, ProfileCardPalette.pastelBeige.opacity(0.92)],
                    iconTint: ProfileCardPalette.textPrimary,
                    action: { beginEdit(.height) }
                )
            }

            Button {
                beginEdit(.goal)
            } label: {
                HStack(spacing: 14) {
                    iconBadge(
                        symbol: "flame.fill",
                        background: ProfileCardPalette.badgeFill,
                        foreground: ProfileCardPalette.textPrimary
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("screen.profile.metric.goal", value: "Goal", comment: ""))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(ProfileCardPalette.textSecondary)

                        Text(goalText)
                            .font(.system(size: 19, weight: .heavy, design: .rounded))
                            .foregroundStyle(ProfileCardPalette.textPrimary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.forward")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(ProfileCardPalette.textSecondary)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .background(
                    ProfileCardBackground(
                        baseColor: ProfileCardPalette.pastelGreen,
                        cornerRadius: 24,
                        shadowColor: ProfileCardPalette.shadow
                    )
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(NSLocalizedString("screen.profile.preferences.title", value: "Preferences", comment: ""))

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    iconBadge(
                        symbol: "figure.arms.open",
                        background: ProfileCardPalette.badgeFill,
                        foreground: ProfileCardPalette.textPrimary
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("gender", value: "Gender", comment: ""))
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundStyle(ProfileCardPalette.textPrimary)

                        Text(
                            NSLocalizedString(
                                "screen.profile.preferences.subtitle",
                                value: "Used for training and notification personalization",
                                comment: ""
                            )
                        )
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(ProfileCardPalette.textSecondary)
                    }

                    Spacer(minLength: 0)
                }

                Picker("", selection: genderBinding) {
                    Text(NSLocalizedString("male", value: "Male", comment: ""))
                        .tag(ActivityNotificationGender.male)
                    Text(NSLocalizedString("female", value: "Female", comment: ""))
                        .tag(ActivityNotificationGender.female)
                }
                .pickerStyle(.segmented)
            }
            .padding(18)
            .background(
                ProfileCardBackground(
                    baseColor: ProfileCardPalette.pastelGreen,
                    cornerRadius: 24,
                    shadowColor: ProfileCardPalette.shadow
                )
            )
        }
    }

    private var appSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(NSLocalizedString("app_section", value: "Application", comment: ""))

            ProfileActionRow(
                icon: "gearshape.fill",
                title: NSLocalizedString("settings", value: "Settings", comment: ""),
                subtitle: NSLocalizedString("notif_lang", value: "Notifications & Language", comment: ""),
                colors: [ProfileCardPalette.pastelBeige, ProfileCardPalette.pastelBeige.opacity(0.92)],
                iconTint: ProfileCardPalette.textPrimary,
                action: { showSettingsSheet = true }
            )

            ProfileActionRow(
                icon: "message.fill",
                title: NSLocalizedString("support", value: "Support", comment: ""),
                subtitle: NSLocalizedString("contact_us", value: "Contact Us", comment: ""),
                colors: [ProfileCardPalette.pastelBeige, ProfileCardPalette.pastelBeige.opacity(0.92)],
                iconTint: ProfileCardPalette.textPrimary,
                action: contactSupport
            )
        }
    }

    private var bioMetricDetails: [BioMetricDetail] {
        let bodyFatMetric = metricComponents(
            from: healthBioMetrics.bodyFatPercentage,
            fallbackUnit: "%"
        )
        let leanBodyMassMetric = metricComponents(
            from: healthBioMetrics.leanBodyMass,
            fallbackUnit: defaultWeightUnitText
        )
        let waterMetric = metricComponents(from: nil, fallbackUnit: "%")
        let bmrMetric = metricComponents(from: nil, fallbackUnit: "kcal")

        return [
            BioMetricDetail(
                id: "body-fat",
                title: NSLocalizedString("screen.profile.bio.bodyFat", value: "Body Fat", comment: ""),
                value: bodyFatMetric.value,
                unit: bodyFatMetric.unit,
                symbol: "drop.fill",
                colors: [ProfileCardPalette.pastelBeige, ProfileCardPalette.pastelBeige.opacity(0.92)],
                iconTint: ProfileCardPalette.textPrimary
            ),
            BioMetricDetail(
                id: "muscle-mass",
                title: NSLocalizedString("screen.profile.bio.muscleMass", value: "Muscle Mass", comment: ""),
                value: leanBodyMassMetric.value,
                unit: leanBodyMassMetric.unit,
                symbol: "figure.strengthtraining.traditional",
                colors: [ProfileCardPalette.pastelGreen, ProfileCardPalette.pastelGreen.opacity(0.92)],
                iconTint: ProfileCardPalette.textPrimary
            ),
            BioMetricDetail(
                id: "water",
                title: NSLocalizedString("screen.profile.bio.water", value: "Water", comment: ""),
                value: waterMetric.value,
                unit: waterMetric.unit,
                symbol: "drop.circle.fill",
                colors: [ProfileCardPalette.pastelGreen, ProfileCardPalette.pastelGreen.opacity(0.92)],
                iconTint: ProfileCardPalette.textPrimary
            ),
            BioMetricDetail(
                id: "bmr",
                title: NSLocalizedString("screen.profile.bio.bmr", value: "Basal Metabolic Rate", comment: ""),
                value: bmrMetric.value,
                unit: bmrMetric.unit,
                symbol: "flame.circle.fill",
                colors: [ProfileCardPalette.pastelBeige, ProfileCardPalette.pastelBeige.opacity(0.92)],
                iconTint: ProfileCardPalette.textPrimary
            )
        ]
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

    private var goalText: String {
        profile.goalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "--" : profile.goalText
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 18, weight: .black, design: .rounded))
            .foregroundStyle(ProfileCardPalette.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }

    private func iconBadge(symbol: String, background: Color, foreground: Color) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(background)
            .frame(width: 46, height: 46)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(foreground)
            }
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
            return ("--", fallbackUnit)
        }

        let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        let value = parts.first.map(String.init) ?? "--"
        let unit = parts.dropFirst().first.map(String.init) ?? fallbackUnit
        return (value, unit)
    }

    private func refreshProfileState() {
        profile = UserProfileStore.shared.current
        avatarImage = UserProfileStore.shared.loadAvatar()
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
        case .goal:
            editText = profile.goalText
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
        case .goal:
            updateProfile { $0.goalText = trimmed }
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
}

private struct ProfileMetricCard: View {
    let title: String
    let value: String
    let symbol: String
    let colors: [Color]
    let iconTint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(ProfileCardPalette.badgeFill)
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: symbol)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(iconTint)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(ProfileCardPalette.textSecondary)

                    Text(value)
                        .font(.system(size: 21, weight: .black, design: .rounded))
                        .foregroundStyle(ProfileCardPalette.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
            .background(
                ProfileCardBackground(
                    colors: colors,
                    cornerRadius: 24,
                    shadowColor: ProfileCardPalette.shadow
                )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct ProfileActionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let colors: [Color]
    let iconTint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(ProfileCardPalette.badgeFill)
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(iconTint)
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(ProfileCardPalette.textPrimary)

                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(ProfileCardPalette.textSecondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.forward")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(ProfileCardPalette.textSecondary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                ProfileCardBackground(
                    colors: colors,
                    cornerRadius: 24,
                    shadowColor: ProfileCardPalette.shadow
                )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct BioMetricsSheet: View {
    let currentWeight: String
    let metrics: [BioMetricDetail]
    let onEditWeight: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(
                            NSLocalizedString(
                                "screen.profile.bioSheet.title",
                                value: "Bio-Scan Details",
                                comment: ""
                            )
                        )
                        .font(.system(size: 25, weight: .black, design: .rounded))
                        .foregroundStyle(ProfileCardPalette.textPrimary)

                        Text(
                            NSLocalizedString(
                                "screen.profile.bioSheet.subtitle",
                                value: "A quick look at your current body composition snapshot.",
                                comment: ""
                            )
                        )
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(ProfileCardPalette.textSecondary)
                    }

                    Spacer(minLength: 0)

                    Button(action: onEditWeight) {
                        Text(NSLocalizedString("screen.profile.editWeight.title", value: "Update Weight", comment: ""))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(ProfileCardPalette.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.60), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("screen.profile.metric.weight", value: "Weight", comment: ""))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(ProfileCardPalette.textSecondary)

                        Text(currentWeight)
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundStyle(ProfileCardPalette.textPrimary)

                        Text(
                            NSLocalizedString(
                                "screen.profile.bioSheet.caption",
                                value: "Latest body composition synced from HealthKit",
                                comment: ""
                            )
                        )
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(ProfileCardPalette.textSecondary)
                    }

                    Spacer(minLength: 0)

                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(ProfileCardPalette.badgeFill)
                        .frame(width: 82, height: 82)
                        .overlay {
                            Image(systemName: "heart.text.square.fill")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(ProfileCardPalette.textPrimary)
                        }
                }
                .padding(18)
                .background(
                    ProfileCardBackground(
                        colors: [ProfileCardPalette.pastelGreen, ProfileCardPalette.pastelGreen.opacity(0.92)],
                        cornerRadius: 26,
                        shadowColor: ProfileCardPalette.shadow
                    )
                )

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

private struct BioMetricTile: View {
    let metric: BioMetricDetail

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(ProfileCardPalette.badgeFill)
                .frame(width: 46, height: 46)
                .overlay {
                    Image(systemName: metric.symbol)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(metric.iconTint)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(metric.title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(ProfileCardPalette.textSecondary)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(metric.value)
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(ProfileCardPalette.textPrimary)

                    Text(metric.unit)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(ProfileCardPalette.textSecondary)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 156, alignment: .leading)
        .background(
            ProfileCardBackground(
                colors: metric.colors,
                cornerRadius: 24,
                shadowColor: ProfileCardPalette.shadow
            )
        )
    }
}

private struct ProfileCardBackground: View {
    let colors: [Color]
    var cornerRadius: CGFloat = 28
    var shadowColor: Color = ProfileCardPalette.shadow

    init(baseColor: Color, cornerRadius: CGFloat = 28, shadowColor: Color = ProfileCardPalette.shadow) {
        self.colors = [baseColor, baseColor.opacity(0.92)]
        self.cornerRadius = cornerRadius
        self.shadowColor = shadowColor
    }

    init(colors: [Color], cornerRadius: CGFloat = 28, shadowColor: Color = ProfileCardPalette.shadow) {
        self.colors = colors
        self.cornerRadius = cornerRadius
        self.shadowColor = shadowColor
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: colors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.40), lineWidth: 1)
            )
            .shadow(color: shadowColor, radius: 14, x: 0, y: 8)
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

#Preview {
    NavigationStack {
        ProfileScreen()
    }
}
