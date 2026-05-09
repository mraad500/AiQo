import SwiftUI

struct AIDataUseDisclosureRows: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            disclosureRow(
                icon: "doc.text.fill",
                titleKey: "ai.consent.what.title",
                detailKey: "ai.consent.what.detail"
            )

            disclosureRow(
                icon: "server.rack",
                titleKey: "ai.consent.who.title",
                detailKey: "ai.consent.who.detail"
            )

            disclosureRow(
                icon: "sparkles.rectangle.stack.fill",
                titleKey: "ai.consent.why.title",
                detailKey: "ai.consent.why.detail"
            )

            disclosureRow(
                icon: "checkmark.shield.fill",
                titleKey: "ai.consent.notSent.title",
                detailKey: "ai.consent.notSent.detail"
            )

            disclosureRow(
                icon: "drop.fill",
                titleKey: "ai.consent.water.title",
                detailKey: "ai.consent.water.detail"
            )

            disclosureRow(
                icon: "hand.raised.fill",
                titleKey: "ai.consent.control.title",
                detailKey: "ai.consent.control.detail"
            )
        }
    }

    private func disclosureRow(
        icon: String,
        titleKey: String,
        detailKey: String
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 24, height: 24)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString(titleKey, comment: ""))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text(NSLocalizedString(detailKey, comment: ""))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct AIDataUseDisclosureView: View {
    var body: some View {
        AIDataUseDisclosureRows()
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
    }
}

struct AIDataPrivacySettingsView: View {
    @ObservedObject private var consentManager = AIDataConsentManager.shared
    @State private var showPrivacyPolicy = false
    @State private var showingRevokeConfirmation = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                statusCard
                AIDataUseDisclosureView()

                VStack(alignment: .leading, spacing: 12) {
                    Button {
                        if consentManager.hasUserConsented {
                            showingRevokeConfirmation = true
                        } else {
                            consentManager.presentDisclosure()
                        }
                    } label: {
                        Text(
                            consentManager.hasUserConsented
                            ? NSLocalizedString("ai.settings.revoke", comment: "")
                            : NSLocalizedString("ai.settings.reviewConsent", comment: "")
                        )
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(consentManager.hasUserConsented ? .red : .white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(consentManager.hasUserConsented ? Color.red.opacity(0.10) : Color.accentColor)
                        )
                    }
                    .buttonStyle(.plain)
                    .confirmationDialog(
                        NSLocalizedString("ai.settings.revoke.confirm.title", comment: ""),
                        isPresented: $showingRevokeConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button(
                            NSLocalizedString("ai.settings.revoke", comment: ""),
                            role: .destructive
                        ) {
                            consentManager.revokeConsent()
                        }
                        Button(
                            NSLocalizedString("settings.cancel", comment: ""),
                            role: .cancel
                        ) {}
                    } message: {
                        Text(NSLocalizedString("ai.settings.revoke.confirm.message", comment: ""))
                    }

                    Button {
                        showPrivacyPolicy = true
                    } label: {
                        Text(NSLocalizedString("ai.consent.privacyPolicy", comment: ""))
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
        .navigationTitle(NSLocalizedString("ai.settings.title", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPrivacyPolicy) {
            LegalView(type: .privacyPolicy)
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("ai.settings.status.title", comment: ""))
                .font(.system(size: 16, weight: .bold, design: .rounded))

            Text(statusText)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private var statusText: String {
        if let acceptedAt = consentManager.acceptedAt {
            return String(
                format: NSLocalizedString("ai.settings.status.accepted", comment: ""),
                acceptedAt.formatted(date: .abbreviated, time: .shortened)
            )
        }

        return NSLocalizedString("ai.settings.status.notAccepted", comment: "")
    }
}
