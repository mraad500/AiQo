import SwiftUI

/// Mandatory age-gate + quick health condition screen shown right after the
/// medical disclaimer and before Captain personalization. Users under 18 are
/// blocked; condition flags are persisted and later fed into Captain's
/// system prompt.
struct HealthScreeningOnboardingView: View {
    let onContinue: () -> Void

    @State private var birthYearText: String = ""
    @State private var isPregnant = false
    @State private var hasHeartCondition = false
    @State private var hadRecentSurgery = false
    @State private var showUnderAgeBlock = false
    @State private var appeared = false
    @FocusState private var birthYearFocused: Bool

    private let currentYear = Calendar(identifier: .gregorian).component(.year, from: Date())

    private var parsedYear: Int? {
        let digits = Self.normalizeToWesternDigits(birthYearText)
            .trimmingCharacters(in: .whitespaces)
        guard let year = Int(digits), year > 1900, year <= currentYear else { return nil }
        return year
    }

    private static func normalizeToWesternDigits(_ input: String) -> String {
        // Users may type Eastern Arabic (٠-٩) or Extended Arabic-Indic (۰-۹) digits.
        let map: [Character: Character] = [
            "٠": "0", "١": "1", "٢": "2", "٣": "3", "٤": "4",
            "٥": "5", "٦": "6", "٧": "7", "٨": "8", "٩": "9",
            "۰": "0", "۱": "1", "۲": "2", "۳": "3", "۴": "4",
            "۵": "5", "۶": "6", "۷": "7", "۸": "8", "۹": "9"
        ]
        return String(input.map { map[$0] ?? $0 })
    }

    private var canContinue: Bool { parsedYear != nil }

    var body: some View {
        ZStack {
            AuthFlowBackground()

            if showUnderAgeBlock {
                underAgeBlock
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                form
                    .transition(.opacity)
            }
        }
        .environment(\.layoutDirection, AppSettingsStore.shared.appLanguage == .arabic ? .rightToLeft : .leftToRight)
        // Defensive: no-op on the root-switched path (this view is not a sheet),
        // but if a future surface ever wraps this screen in `.sheet { ... }`
        // (e.g. a "review your health answers" settings flow), the gate stays
        // non-dismissible. App Review readers also recognise this modifier as
        // the visual signal for a blocking health gate.
        .interactiveDismissDisabled(true)
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.84)) {
                appeared = true
            }
        }
    }

    private var form: some View {
        VStack(spacing: 0) {
            AuthFlowBrandHeader()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    headerCard
                    birthYearCard
                    conditionsCard
                    privacyFootnote
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 16)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 28)
            }

            continueButton
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 24)
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(NSLocalizedString("onboarding.healthScreening.title", comment: ""))
                .font(.aiqoDisplay(24))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Text(NSLocalizedString("onboarding.healthScreening.subtitle", comment: ""))
                .font(.aiqoBody(15))
                .foregroundStyle(.secondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 24)
    }

    private var birthYearCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("onboarding.healthScreening.birthYear.label", comment: ""))
                .font(.aiqoBody(16).weight(.semibold))
                .foregroundStyle(.primary)
            TextField(
                NSLocalizedString("onboarding.healthScreening.birthYear.placeholder", comment: ""),
                text: $birthYearText
            )
            .keyboardType(.numberPad)
            .font(.aiqoDisplay(20))
            .foregroundStyle(.primary)
            .tint(AuthFlowTheme.mint)
            .focused($birthYearFocused)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            )
            Text(NSLocalizedString("onboarding.healthScreening.birthYear.hint", comment: ""))
                .font(.aiqoCaption(12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 24)
    }

    private var conditionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(NSLocalizedString("onboarding.healthScreening.conditions.label", comment: ""))
                    .font(.aiqoBody(16).weight(.semibold))
                    .foregroundStyle(.primary)
                Text(NSLocalizedString("onboarding.healthScreening.conditions.hint", comment: ""))
                    .font(.aiqoCaption(12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            conditionToggle(
                titleKey: "onboarding.healthScreening.condition.pregnant",
                isOn: $isPregnant
            )
            conditionToggle(
                titleKey: "onboarding.healthScreening.condition.heart",
                isOn: $hasHeartCondition
            )
            conditionToggle(
                titleKey: "onboarding.healthScreening.condition.surgery",
                isOn: $hadRecentSurgery
            )
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 24)
    }

    private func conditionToggle(titleKey: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(NSLocalizedString(titleKey, comment: ""))
                .font(.aiqoBody(15))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .toggleStyle(SwitchToggleStyle(tint: AuthFlowTheme.mint))
    }

    private var privacyFootnote: some View {
        Text(NSLocalizedString("onboarding.healthScreening.privacy.footnote", comment: ""))
            .font(.aiqoCaption(12))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
            .padding(.top, 4)
    }

    private var continueButton: some View {
        Button {
            handleContinue()
        } label: {
            Text(NSLocalizedString("onboarding.healthScreening.continue", comment: ""))
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(AuthFlowTheme.mint)
                )
        }
        .buttonStyle(.plain)
        .disabled(!canContinue)
        .opacity(canContinue ? 1 : 0.5)
        .accessibilityIdentifier("health-screening-continue")
    }

    private var underAgeBlock: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 24)
            ZStack {
                Circle()
                    .fill(AuthFlowTheme.mint.opacity(0.18))
                    .frame(width: 112, height: 112)
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(AuthFlowTheme.mint)
            }
            Text(NSLocalizedString("onboarding.healthScreening.underAge.title", comment: ""))
                .font(.aiqoDisplay(26))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(NSLocalizedString("onboarding.healthScreening.underAge.body", comment: ""))
                .font(.aiqoBody(15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
                .fixedSize(horizontal: false, vertical: true)
            Text(NSLocalizedString("onboarding.healthScreening.underAge.support", comment: ""))
                .font(.aiqoCaption(12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(28)
    }

    private func handleContinue() {
        birthYearFocused = false
        guard let year = parsedYear else { return }
        let answers = HealthScreeningAnswers(
            birthYear: year,
            isPregnant: isPregnant,
            hasHeartOrBloodPressureCondition: hasHeartCondition,
            hadRecentSurgery: hadRecentSurgery
        )
        if answers.ageNow < HealthScreeningStore.minimumAge {
            withAnimation(.easeInOut(duration: 0.35)) {
                showUnderAgeBlock = true
            }
            return
        }
        HealthScreeningStore.save(answers)
        onContinue()
    }
}
