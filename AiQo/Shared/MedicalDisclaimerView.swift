import SwiftUI

/// Reusable compliance banner for health-related guidance surfaces.
struct MedicalDisclaimerView: View {
    var compact: Bool = true

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "cross.case.fill")
                .font(.system(size: compact ? 14 : 16, weight: .semibold))
                .foregroundStyle(.orange.opacity(0.85))
                .padding(.top, 1)

            Text(NSLocalizedString("health.disclaimer.general", comment: ""))
                .font(.system(size: compact ? 11 : 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(compact ? 12 : 14)
        .background(
            RoundedRectangle(cornerRadius: compact ? 14 : 18, style: .continuous)
                .fill(Color.orange.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: compact ? 14 : 18, style: .continuous)
                        .stroke(Color.orange.opacity(0.16), lineWidth: 1)
                )
        )
    }
}

struct HealthComplianceCard: View {
    var compact: Bool = true

    @State private var isPresentingSources = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 10 : 12) {
            MedicalDisclaimerView(compact: compact)

            Button {
                isPresentingSources = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "text.book.closed.fill")
                        .font(.system(size: 13, weight: .semibold))

                    Text(NSLocalizedString("health.sources.button", comment: ""))
                        .font(.system(size: compact ? 13 : 14, weight: .bold, design: .rounded))

                    Spacer(minLength: 8)

                    Text(NSLocalizedString("health.disclaimer.learnMore", comment: ""))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, compact ? 14 : 16)
                .padding(.vertical, compact ? 12 : 14)
                .background(
                    RoundedRectangle(cornerRadius: compact ? 14 : 18, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: compact ? 14 : 18, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("health-sources-button")
        }
        .sheet(isPresented: $isPresentingSources) {
            HealthSourcesView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
    }
}

/// Inline health source attribution label.
struct HealthSourceLabel: View {
    let source: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "text.book.closed.fill")
                .font(.system(size: 9, weight: .semibold))
            Text(source)
                .font(.system(size: 10, weight: .medium, design: .rounded))
        }
        .foregroundStyle(.secondary.opacity(0.7))
    }
}
