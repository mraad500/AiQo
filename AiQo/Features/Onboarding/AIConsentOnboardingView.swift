import SwiftUI

struct AIConsentOnboardingView: View {
    let onContinue: () -> Void

    @State private var appeared = false
    @State private var showPrivacyPolicy = false

    var body: some View {
        ZStack {
            AuthFlowBackground()

            VStack(spacing: 0) {
                AuthFlowBrandHeader()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        headerCard
                        disclosureCard
                        privacyPolicyLink
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 18)
                    .padding(.bottom, 16)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 28)
                }

                buttonStack
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
            }
        }
        .environment(\.layoutDirection, AppSettingsStore.shared.appLanguage == .arabic ? .rightToLeft : .leftToRight)
        .sheet(isPresented: $showPrivacyPolicy) {
            LegalView(type: .privacyPolicy)
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.84)) {
                appeared = true
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(AuthFlowTheme.mint.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AuthFlowTheme.mint)
                }

                Text(NSLocalizedString("ai.consent.title", comment: ""))
                    .font(.aiqoDisplay(26))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(NSLocalizedString("ai.consent.subtitle", comment: ""))
                .font(.aiqoBody(15))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 24)
    }

    private var disclosureCard: some View {
        AIDataUseDisclosureRows()
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(cornerRadius: 24)
    }

    private var privacyPolicyLink: some View {
        Button {
            showPrivacyPolicy = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "doc.plaintext")
                    .font(.system(size: 13, weight: .semibold))
                Text(NSLocalizedString("ai.consent.privacyPolicy", comment: ""))
                    .font(.aiqoBody(14))
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var buttonStack: some View {
        VStack(spacing: 12) {
            Button {
                AIDataConsentManager.shared.grantConsent()
                onContinue()
            } label: {
                Text(NSLocalizedString("ai.consent.agree", comment: ""))
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
            .accessibilityIdentifier("ai-consent-onboarding-agree")

            Button {
                AIDataConsentManager.shared.declineAndUseOffline()
                onContinue()
            } label: {
                Text(NSLocalizedString("onboarding.aiConsent.offlineOnly", comment: ""))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 28, style: .continuous)
                                    .stroke(AuthFlowTheme.sand, lineWidth: 1.5)
                            )
                    )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("ai-consent-onboarding-offline")
        }
    }
}
