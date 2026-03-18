import SwiftUI

struct ProfileSetupView: View {
    @State private var fullName = ""
    @State private var username = ""
    @State private var birthDate = Calendar.current.date(byAdding: .year, value: -20, to: Date()) ?? Date()
    @State private var gender: ActivityNotificationGender = .male
    @State private var weightText = ""
    @State private var heightText = ""
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
                                .foregroundColor(.secondary)
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
                                .foregroundColor(.secondary)
                            Image(systemName: "calendar")
                                .foregroundColor(AuthFlowTheme.sand)
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
                                .foregroundColor(.secondary)

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
                                suffix: "كغم",
                                keyboardType: .decimalPad
                            )
                            AuthFlowTextField(
                                title: localized("dating.height", fallback: "الطول"),
                                text: $heightText,
                                icon: "ruler.fill",
                                suffix: "سم",
                                keyboardType: .numberPad
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
        .environment(\.layoutDirection, .rightToLeft)
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
        NotificationPreferencesStore.shared.gender = gender

        AppFlowController.shared.didCompleteProfileSetup()
    }

    private func localized(_ key: String, fallback: String) -> String {
        NSLocalizedString(key, tableName: "Localizable", bundle: .main, value: fallback, comment: "")
    }
}

typealias DatingScreenView = ProfileSetupView
