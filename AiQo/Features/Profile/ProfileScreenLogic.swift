import SwiftUI
import MessageUI
import UIKit

extension ProfileScreen {
    @ViewBuilder
    func profileSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ProfileSectionHeader(title: title)
            content()
        }
    }

    var bioMetricDetails: [BioMetricDetail] {
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
                tone: .mint
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
                tone: .mint
            )
        ]
    }

    var bioScanHighlight: BioScanHighlight {
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

    var genderBinding: Binding<ActivityNotificationGender> {
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

    var displayName: String {
        let fallback = NSLocalizedString("default_name", value: "Captain", comment: "")
        return profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback : profile.name
    }

    var displayUsername: String {
        let username = profile.username?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return username.isEmpty ? "@--" : "@\(username)"
    }

    var ageText: String {
        guard profile.age > 0 else { return "--" }
        return String(
            format: NSLocalizedString("screen.profile.metric.age.value", value: "%d years", comment: ""),
            profile.age
        )
    }

    var heightText: String {
        guard profile.heightCm > 0 else { return "--" }
        return String(
            format: NSLocalizedString("screen.profile.metric.height.value", value: "%d cm", comment: ""),
            profile.heightCm
        )
    }

    var weightText: String {
        guard profile.weightKg > 0 else { return "--" }
        return String(
            format: NSLocalizedString("screen.profile.metric.weight.value", value: "%d kg", comment: ""),
            profile.weightKg
        )
    }

    var genderDisplayText: String {
        switch genderBinding.wrappedValue {
        case .male:
            return NSLocalizedString("gender.male", value: "ذكر", comment: "")
        case .female:
            return NSLocalizedString("gender.female", value: "أنثى", comment: "")
        }
    }

    var currentWeightDisplay: String {
        healthBioMetrics.weight ?? weightText
    }

    var weightNumberText: String {
        metricComponents(
            from: currentWeightDisplay,
            fallbackUnit: defaultWeightUnitText
        ).value
    }

    var weightUnitText: String {
        metricComponents(
            from: currentWeightDisplay,
            fallbackUnit: defaultWeightUnitText
        ).unit
    }

    var defaultWeightUnitText: String {
        NSLocalizedString("weight", value: "kg", comment: "")
    }

    var formattedLineScore: String {
        Self.numberFormatter.string(from: NSNumber(value: levelSummary.lineScore)) ?? "\(levelSummary.lineScore)"
    }

    @MainActor
    func loadBioMetrics() async {
        let metrics = await HealthKitManager.shared.fetchBioMetrics()
        healthBioMetrics = metrics
    }

    func metricComponents(
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

    func refreshProfileState() {
        profile = UserProfileStore.shared.current
        avatarImage = UserProfileStore.shared.loadAvatar()
        isProfilePublic = UserProfileStore.shared.tribePrivacyMode == .public
    }

    func refreshLevelSummary() {
        levelSummary = ProfileLevelSummary.load()
    }

    func beginEdit(_ field: ProfileEditField) {
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

    func applyEditValue() {
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

    func updateProfile(_ mutate: (inout UserProfile) -> Void) {
        var current = profile
        mutate(&current)
        profile = current
        UserProfileStore.shared.current = current
    }

    func contactSupport() {
        if MFMailComposeViewController.canSendMail() {
            showMailComposer = true
            return
        }

        guard let url = URL(string: "mailto:AppAiQo5@gmail.com") else { return }
        UIApplication.shared.open(url)
    }

    func toggleVisibility(_ newValue: Bool) {
        let previousValue = isProfilePublic

        isProfilePublic = newValue
        isSyncingPrivacy = true
        privacySyncFailed = false
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        UserProfileStore.shared.setTribePrivacyMode(newValue ? .public : .private)

        Task {
            do {
                try await SupabaseArenaService.shared.updateProfileVisibility(isPublic: newValue)
                await MainActor.run {
                    isSyncingPrivacy = false
                }
            } catch {
                await MainActor.run {
                    isProfilePublic = previousValue
                    UserProfileStore.shared.setTribePrivacyMode(previousValue ? .public : .private)
                    isSyncingPrivacy = false
                    privacySyncFailed = true
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }

                try? await Task.sleep(for: .seconds(3))
                await MainActor.run {
                    privacySyncFailed = false
                }
            }
        }
    }

    static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        return formatter
    }()
}
