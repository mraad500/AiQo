import SwiftUI

/// Lightweight consent sheet shown before the FIRST on-device certificate
/// verification attempt on a given install. Per Apple HIG — any AI-based analysis of
/// user content warrants explicit opt-in, even when the processing is on-device.
///
/// State is persisted in `OnDeviceVerificationConsent` (UserDefaults). Revokable from
/// the app's privacy settings (see `AppSettingsScreen`).
struct OnDeviceVerificationConsentSheet: View {
    let onAccept: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var layoutDirection: LayoutDirection {
        AppSettingsStore.shared.appLanguage == .arabic ? .rightToLeft : .leftToRight
    }

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(Color(hex: "1A1A1A"))
                .padding(.top, 18)

            Text(questLocalizedText("gym.quest.learning.consent.title"))
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(hex: "1A1A1A"))
                .multilineTextAlignment(.center)

            Text(questLocalizedText("gym.quest.learning.consent.body"))
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color(hex: "444444"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                Button(action: accept) {
                    Text(questLocalizedText("gym.quest.learning.consent.accept"))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: "1A1A1A"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(hex: "B7E5D2"))
                        )
                }

                Button(action: { dismiss() }) {
                    Text(questLocalizedText("gym.quest.learning.consent.later"))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(hex: "666666"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 28)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .environment(\.layoutDirection, layoutDirection)
    }

    private func accept() {
        OnDeviceVerificationConsent.grant()
        onAccept()
        dismiss()
    }
}
