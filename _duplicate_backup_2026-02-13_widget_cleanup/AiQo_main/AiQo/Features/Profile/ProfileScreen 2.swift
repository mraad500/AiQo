import SwiftUI
import PhotosUI
import MessageUI
internal import Combine
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

struct ProfileScreen: View {
    @State private var profile: UserProfile = UserProfileStore.shared.current
    @ObservedObject private var coinManager = CoinManager.shared

    @State private var avatarImage: UIImage? = UserProfileStore.shared.loadAvatar()
    @State private var selectedPhoto: PhotosPickerItem?

    @State private var showingEditAlert = false
    @State private var currentEditField: ProfileEditField = .name
    @State private var editText = ""

    @State private var showKernelSheet = false
    @State private var showSettingsSheet = false
    @State private var showMailComposer = false
    @State private var showLevelInfo = false
    @State private var showWalletInfo = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                headerCard

                LevelCardRepresentable()
                    .frame(height: 100)
                    .onTapGesture {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        showLevelInfo = true
                    }

                bodySection
                appSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .onAppear {
            refreshProfileState()
            HealthKitManager.shared.fetchSteps()
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
        .alert(
            NSLocalizedString("screen.profile.wallet.title", value: "AiQo Wallet", comment: ""),
            isPresented: $showWalletInfo
        ) {
            Button(NSLocalizedString("action.ok", value: "OK", comment: ""), role: .cancel) {}
        } message: {
            Text(
                NSLocalizedString(
                    "screen.profile.wallet.message",
                    value: "Keep moving to earn more coins.",
                    comment: ""
                )
            )
        }
        .sheet(isPresented: $showKernelSheet) {
            ContentView()
                .environmentObject(ProtectionModel.shared)
                .presentationDetents([.medium, .large])
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
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(.systemGray5))
                    }
                }
                .frame(width: 80, height: 80)
                .clipShape(Circle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Button {
                    beginEdit(.name)
                } label: {
                    Text(displayName)
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)

                Text(displayUsername)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)

                Text(
                    NSLocalizedString(
                        "optimize_bio",
                        value: "Let's optimize your body & mind",
                        comment: ""
                    )
                )
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var bodySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("body_stats", value: "Body Stats", comment: ""))
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.secondary)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ],
                spacing: 12
            ) {
                metricCard(
                    icon: "calendar",
                    title: NSLocalizedString("screen.profile.metric.age", value: "Age", comment: ""),
                    value: ageText,
                    action: { beginEdit(.age) }
                )

                metricCard(
                    icon: "ruler",
                    title: NSLocalizedString("screen.profile.metric.height", value: "Height", comment: ""),
                    value: heightText,
                    action: { beginEdit(.height) }
                )

                metricCard(
                    icon: "scalemass",
                    title: NSLocalizedString("screen.profile.metric.weight", value: "Weight", comment: ""),
                    value: weightText,
                    action: { beginEdit(.weight) }
                )

                metricCard(
                    icon: "flame",
                    title: NSLocalizedString("screen.profile.metric.goal", value: "Goal", comment: ""),
                    value: goalText,
                    action: { beginEdit(.goal) }
                )
            }

            HStack(spacing: 12) {
                Text(NSLocalizedString("gender", value: "Gender", comment: ""))
                    .font(.system(size: 15, weight: .bold))

                Spacer()

                Picker("", selection: genderBinding) {
                    Text(NSLocalizedString("male", value: "Male", comment: ""))
                        .tag(ActivityNotificationGender.male)
                    Text(NSLocalizedString("female", value: "Female", comment: ""))
                        .tag(ActivityNotificationGender.female)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }

    private var appSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(NSLocalizedString("app_section", value: "Application", comment: ""))
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.secondary)

            actionRow(
                icon: "brain.head.profile",
                title: NSLocalizedString(
                    "screen.profile.app.kernel.title",
                    value: "Bio-Digital Kernel",
                    comment: ""
                ),
                subtitle: NSLocalizedString("focus_protection", value: "Focus Protection", comment: ""),
                action: { showKernelSheet = true }
            )

            currencyCard
                .onTapGesture {
                    showWalletInfo = true
                }

            actionRow(
                icon: "gearshape.fill",
                title: NSLocalizedString("settings", value: "Settings", comment: ""),
                subtitle: NSLocalizedString("notif_lang", value: "Notifications & Language", comment: ""),
                action: { showSettingsSheet = true }
            )

            actionRow(
                icon: "message.fill",
                title: NSLocalizedString("support", value: "Support", comment: ""),
                subtitle: NSLocalizedString("contact_us", value: "Contact Us", comment: ""),
                action: contactSupport
            )
        }
    }

    private var currencyCard: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(
                    NSLocalizedString(
                        "screen.profile.currency.title",
                        value: "AiQo Balance",
                        comment: ""
                    )
                )
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.8))

                Text(
                    NSLocalizedString(
                        "screen.profile.currency.subtitle",
                        value: "Bio-Digital Coins",
                        comment: ""
                    )
                )
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

                Text("\(coinManager.balance)")
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundStyle(.primary)
            }

            Spacer(minLength: 0)

            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.blue)
                    .frame(width: 64, height: 64)
                    .shadow(color: .black.opacity(0.10), radius: 10, x: 0, y: 6)

                Image("currency")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 34)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.90, green: 0.96, blue: 1.0),
                            Color(red: 0.92, green: 1.0, blue: 0.96)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.55), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 8)
    }

    private func metricCard(icon: String, title: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 28, height: 28)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(value)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .frame(height: 70)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
        }
        .buttonStyle(.plain)
    }

    private func actionRow(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.forward")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .frame(height: 70)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
        }
        .buttonStyle(.plain)
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

    private var goalText: String {
        profile.goalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "--" : profile.goalText
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

private struct LevelCardRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> LevelCardView {
        LevelCardView()
    }

    func updateUIView(_ uiView: LevelCardView, context: Context) {
        uiView.reloadFromStorage()
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
