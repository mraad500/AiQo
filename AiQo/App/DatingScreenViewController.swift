import SwiftUI

struct DatingScreenView: View {
    @State private var fullName = ""
    @State private var username = ""
    @State private var birthDate = Calendar.current.date(byAdding: .year, value: -20, to: Date()) ?? Date()
    @State private var gender: ActivityNotificationGender = .male
    @State private var weightText = ""
    @State private var heightText = ""

    private var layoutDirection: LayoutDirection {
        AppSettingsStore.shared.appLanguage == .arabic ? .rightToLeft : .leftToRight
    }

    private var canContinue: Bool {
        let weight = Int(weightText) ?? 0
        let height = Int(heightText) ?? 0
        return !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !normalizedUsername.isEmpty
            && weight > 0
            && height > 0
    }

    var body: some View {
        ZStack {
            AuthFlowBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    AuthFlowBrandHeader(
                        subtitle: localized("dating.brand.subtitle", fallback: "Elite Profile Setup")
                    )

                    AuthFlowCard {
                        VStack(spacing: 18) {
                            Text(localized("dating.title", fallback: "كمّل ملفك الشخصي"))
                                .font(.aiqoDisplay(32))
                                .foregroundStyle(AuthFlowTheme.text)
                                .multilineTextAlignment(.center)

                            Text(localized(
                                "dating.subtitle",
                                fallback: "أدخل معلوماتك حتى نجهّز خطتك الصحية بشكل أدق."
                            ))
                            .font(.aiqoBody(15))
                            .foregroundStyle(AuthFlowTheme.subtext)
                            .multilineTextAlignment(.center)

                            AuthFlowTextField(
                                title: localized("dating.name", fallback: "الاسم"),
                                text: $fullName,
                                keyboardType: .default
                            )

                            AuthFlowTextField(
                                title: localized("dating.username", fallback: "اسم المستخدم"),
                                text: $username,
                                keyboardType: .asciiCapable
                            )

                            AuthFlowFieldPanel(
                                title: localized("dating.birthDate", fallback: "تاريخ الميلاد")
                            ) {
                                DatePicker(
                                    "",
                                    selection: $birthDate,
                                    in: ...Date(),
                                    displayedComponents: .date
                                )
                                .labelsHidden()
                                .datePickerStyle(.compact)
                                .tint(AuthFlowTheme.mint)
                            }

                            AuthFlowFieldPanel(
                                title: localized("dating.gender", fallback: "الجنس")
                            ) {
                                Picker("Gender", selection: $gender) {
                                    Text(localized("male", fallback: "Male")).tag(ActivityNotificationGender.male)
                                    Text(localized("female", fallback: "Female")).tag(ActivityNotificationGender.female)
                                }
                                .pickerStyle(.segmented)
                                .tint(AuthFlowTheme.gold)
                            }

                            HStack(spacing: 12) {
                                AuthFlowTextField(
                                    title: localized("dating.weight", fallback: "الوزن (كغم)"),
                                    text: $weightText,
                                    keyboardType: .numberPad
                                )

                                AuthFlowTextField(
                                    title: localized("dating.height", fallback: "الطول (سم)"),
                                    text: $heightText,
                                    keyboardType: .numberPad
                                )
                            }

                            AuthPrimaryButton(
                                title: localized("dating.continue", fallback: "متابعة"),
                                isEnabled: canContinue,
                                action: continueTapped
                            )
                            .padding(.top, 4)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 20)
            }
        }
        .environment(\.layoutDirection, layoutDirection)
        .preferredColorScheme(.dark)
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
        guard let weight = Int(weightText), let height = Int(heightText), !trimmedName.isEmpty else { return }

        let age = Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 0

        var profile = UserProfileStore.shared.current
        profile.name = trimmedName
        profile.age = max(age, 0)
        profile.heightCm = height
        profile.weightKg = weight
        profile.username = normalizedUsername
        profile.birthDate = birthDate
        profile.gender = gender

        if profile.goalText.isEmpty {
            profile.goalText = "Stronger • Leaner"
        }

        UserProfileStore.shared.current = profile
        NotificationPreferencesStore.shared.gender = gender

        UIApplication.activeSceneDelegate()?.didCompleteDatingProfile()
    }

    private func localized(_ key: String, fallback: String) -> String {
        NSLocalizedString(key, tableName: "Localizable", bundle: .main, value: fallback, comment: "")
    }
}
