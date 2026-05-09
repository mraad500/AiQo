import SwiftUI

struct ProfileSetupView: View {
    @State private var fullName = UserProfileStore.shared.current.name
    @State private var ageText = ""
    @State private var gender: ActivityNotificationGender = .male
    @State private var weightText = ""
    @State private var heightText = ""
    @State private var isProfilePublic = true
    @State private var appeared = false

    private var isFormValid: Bool {
        !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !ageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !weightText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !heightText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            AuthFlowBackground()

            VStack(spacing: 0) {
                AuthFlowBrandHeader()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        VStack(spacing: 8) {
                            Text(localized("dating.title", fallback: "أكمل ملفك"))
                                .font(.system(size: 28, weight: .black, design: .rounded))
                            Text(localized("dating.subtitle", fallback: "خلينا نجهّز حسابك"))
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)

                        AuthFlowTextField(
                            title: localized("dating.name", fallback: "الاسم"),
                            text: $fullName,
                            icon: "person.fill"
                        )

                        HStack(spacing: 8) {
                            CompactNumericField(
                                title: localized("dating.age", fallback: "العمر"),
                                text: $ageText
                            )
                            CompactNumericField(
                                title: localized("dating.weight", fallback: "الوزن"),
                                text: $weightText,
                                suffix: NSLocalizedString("unit.kg", value: "كغم", comment: "")
                            )
                            CompactNumericField(
                                title: localized("dating.height", fallback: "الطول"),
                                text: $heightText,
                                suffix: NSLocalizedString("unit.cm", value: "سم", comment: "")
                            )
                        }

                        VStack(alignment: .trailing, spacing: 10) {
                            Text(localized("dating.gender", fallback: "الجنس"))
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)

                            HStack(spacing: 0) {
                                GenderButton(
                                    title: localized("female", fallback: "أنثى"),
                                    isSelected: gender == .female
                                ) {
                                    gender = .female
                                }
                                GenderButton(
                                    title: localized("male", fallback: "ذكر"),
                                    isSelected: gender == .male
                                ) {
                                    gender = .male
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.gray.opacity(0.08))
                            )
                        }

                        AuthPrimaryButton(
                            title: localized("dating.continue", fallback: "متابعة"),
                            isEnabled: isFormValid,
                            action: continueTapped
                        )
                    }
                    .padding(28)
                    .glassCard()
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 30)
                    .scaleEffect(appeared ? 1 : 0.96)
                }
            }
        }
        .environment(\.layoutDirection, AppSettingsStore.shared.appLanguage == .arabic ? .rightToLeft : .leftToRight)
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }

    private func continueTapped() {
        let trimmedName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedWeight = weightText.replacingOccurrences(of: ",", with: ".")
        guard !trimmedName.isEmpty,
              let age = Int(ageText.trimmingCharacters(in: .whitespacesAndNewlines)),
              let weight = Double(normalizedWeight),
              let height = Int(heightText) else { return }

        var profile = UserProfileStore.shared.current
        profile.name = trimmedName
        profile.age = max(age, 0)
        profile.heightCm = height
        profile.weightKg = Int(weight.rounded())
        profile.gender = gender

        if profile.goalText.isEmpty {
            profile.goalText = "Stronger • Leaner"
        }

        UserProfileStore.shared.current = profile
        UserProfileStore.shared.setTribePrivacyMode(isProfilePublic ? .public : .private)
        NotificationPreferencesStore.shared.gender = gender

        // Sync visibility to Supabase (fire-and-forget; local state is already saved)
        Task {
            try? await SupabaseArenaService.shared.updateProfileVisibility(isPublic: isProfilePublic)
        }

        AppFlowController.shared.didCompleteProfileSetup()
    }

    private func localized(_ key: String, fallback: String) -> String {
        NSLocalizedString(key, tableName: "Localizable", bundle: .main, value: fallback, comment: "")
    }
}

// MARK: - Compact Numeric Field

private struct CompactNumericField: View {
    let title: String
    @Binding var text: String
    var suffix: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let suffix = suffix {
                Text(suffix)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize()
            }
            TextField(title, text: $text)
                .keyboardType(.asciiCapableNumberPad)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.white.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

// MARK: - Setup Privacy Toggle Card

private struct SetupPrivacyToggleCard: View {
    @Binding var isPublic: Bool

    private var accentColor: Color {
        isPublic ? AuthFlowTheme.mint : Color.gray.opacity(0.35)
    }

    private var statusIcon: String {
        isPublic ? "eye.fill" : "eye.slash.fill"
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                // Toggle
                Toggle("", isOn: $isPublic)
                    .toggleStyle(SwitchToggleStyle(tint: AuthFlowTheme.mint))
                    .labelsHidden()
                    .frame(width: 51)
                    .onChange(of: isPublic) { _, _ in
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }

                // Labels
                VStack(alignment: .trailing, spacing: 3) {
                    HStack(spacing: 6) {
                        // Status badge
                        HStack(spacing: 3) {
                            Image(systemName: statusIcon)
                                .font(.system(size: 8.5, weight: .bold))
                            Text(isPublic
                                 ? NSLocalizedString("profile.privacy.public", value: "عام", comment: "")
                                 : NSLocalizedString("profile.privacy.private", value: "خاص", comment: ""))
                                .font(.system(size: 9, weight: .heavy, design: .rounded))
                        }
                        .foregroundStyle(isPublic ? Color(hex: "3BA87A") : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule(style: .continuous)
                                .fill(accentColor.opacity(0.25))
                        )

                        Text(NSLocalizedString("profile.privacy.publicAccount", value: "حساب عام", comment: ""))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                    }

                    Text(NSLocalizedString("profile.privacy.arenaHint", value: "للمنافسة في الارينا", comment: ""))
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)

                // Icon
                Image(systemName: "shield.checkered")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(accentColor)
                    .frame(width: 38, height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(accentColor.opacity(0.15))
                    )
            }

            // Sub-text divider + hint
            Rectangle()
                .fill(Color.black.opacity(0.05))
                .frame(height: 1)
                .padding(.horizontal, 4)

            HStack(spacing: 6) {
                Text(NSLocalizedString("profile.privacy.changeHint", value: "يمكنك إخفاء اسمك لاحقاً وجعله خاصاً متى ما شئت.", comment: ""))
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.trailing)

                Image(systemName: "info.circle")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: AuthFlowTheme.cardShadow, radius: 8, x: 0, y: 4)
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isPublic)
    }
}
