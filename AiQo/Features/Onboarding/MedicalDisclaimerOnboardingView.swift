import SwiftUI

struct MedicalDisclaimerOnboardingView: View {
    let onAcknowledge: () -> Void

    @State private var isChecked = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            AuthFlowBackground()

            VStack(spacing: 0) {
                AuthFlowBrandHeader()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        heroIcon
                        headerCard
                        bulletCard
                        acknowledgementRow
                        settingsNote
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
        .environment(\.layoutDirection, AppSettingsStore.shared.appLanguage == .arabic ? .rightToLeft : .leftToRight)
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.84)) {
                appeared = true
            }
        }
    }

    private var heroIcon: some View {
        ZStack {
            Circle()
                .fill(AuthFlowTheme.sand.opacity(0.22))
                .frame(width: 96, height: 96)

            Image(systemName: "cross.case.fill")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(AuthFlowTheme.sand)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(NSLocalizedString("onboarding.medical.title", comment: ""))
                .font(.aiqoDisplay(24))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text(NSLocalizedString("onboarding.medical.body", comment: ""))
                .font(.aiqoBody(15))
                .foregroundStyle(.secondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 24)
    }

    private var bulletCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            bulletRow(key: "onboarding.medical.wont.1")
            bulletRow(key: "onboarding.medical.wont.2")
            bulletRow(key: "onboarding.medical.wont.3")
            bulletRow(key: "onboarding.medical.wont.4")
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 24)
    }

    private func bulletRow(key: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.red.opacity(0.75))
                .frame(width: 24, height: 24)
                .padding(.top, 1)

            Text(NSLocalizedString(key, comment: ""))
                .font(.aiqoBody(15))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var acknowledgementRow: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(isChecked ? AuthFlowTheme.mint : Color.secondary.opacity(0.55))
                .frame(width: 30, height: 30)

            Text(NSLocalizedString("onboarding.medical.confirm", comment: ""))
                .font(.aiqoBody(15))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .glassCard(cornerRadius: 22)
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isChecked.toggle()
            }
        }
        .accessibilityIdentifier("medical-disclaimer-confirm-checkbox")
    }

    private var settingsNote: some View {
        Text(NSLocalizedString("onboarding.medical.settingsNote", comment: ""))
            .font(.aiqoCaption(12))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
    }

    private var continueButton: some View {
        Button {
            guard isChecked else { return }
            onAcknowledge()
        } label: {
            Text(NSLocalizedString("onboarding.medical.continue", comment: ""))
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
        .disabled(!isChecked)
        .opacity(isChecked ? 1 : 0.5)
        .accessibilityIdentifier("medical-disclaimer-continue")
    }
}
