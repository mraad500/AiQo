import SwiftUI

struct ProfileSetupView: View {
    @State private var fullName = UserProfileStore.shared.current.name
    @State private var username = UserProfileStore.shared.current.username ?? ""
    @State private var birthDate = Calendar.current.date(byAdding: .year, value: -20, to: Date()) ?? Date()
    @State private var gender: ActivityNotificationGender = .male
    @State private var weightText = ""
    @State private var heightText = ""
    @State private var isProfilePublic = true
    @State private var appeared = false

    private var isFormValid: Bool {
        return !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !normalizedUsername.isEmpty
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

                        AuthFlowTextField(
                            title: localized("dating.username", fallback: "اسم المستخدم"),
                            text: $username,
                            icon: "at",
                            prefix: "@",
                            keyboardType: .asciiCapable
                        )

                        HStack {
                            DatePicker(
                                "",
                                selection: $birthDate,
                                in: ...Date(),
                                displayedComponents: .date
                            )
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            Spacer()
                            Text(localized("dating.birthDate", fallback: "تاريخ الميلاد"))
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                            Image(systemName: "calendar")
                                .foregroundStyle(AuthFlowTheme.sand)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                                )
                        )

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

                        HStack(spacing: 12) {
                            AuthFlowTextField(
                                title: localized("dating.weight", fallback: "الوزن"),
                                text: $weightText,
                                icon: "scalemass.fill",
                                suffix: NSLocalizedString("unit.kg", value: "كغم", comment: ""),
                                keyboardType: .asciiCapableNumberPad
                            )
                            AuthFlowTextField(
                                title: localized("dating.height", fallback: "الطول"),
                                text: $heightText,
                                icon: "ruler.fill",
                                suffix: NSLocalizedString("unit.cm", value: "سم", comment: ""),
                                keyboardType: .asciiCapableNumberPad
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

    private var normalizedUsername: String {
        var raw = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if raw.hasPrefix("@") { raw.removeFirst() }

        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._"))
        let filtered = raw.unicodeScalars.filter { allowed.contains($0) }
        return String(String.UnicodeScalarView(filtered))
    }

    private func continueTapped() {
        let trimmedName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedWeight = weightText.replacingOccurrences(of: ",", with: ".")
        guard let weight = Double(normalizedWeight),
              let height = Int(heightText),
              !trimmedName.isEmpty else { return }

        let age = Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 0

        var profile = UserProfileStore.shared.current
        profile.name = trimmedName
        profile.age = max(age, 0)
        profile.heightCm = height
        profile.weightKg = Int(weight.rounded())
        profile.username = normalizedUsername
        profile.birthDate = birthDate
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
