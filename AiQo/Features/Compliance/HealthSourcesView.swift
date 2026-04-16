import SwiftUI

struct HealthSourcesView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    MedicalDisclaimerView(compact: false)

                    Text(NSLocalizedString("health.sources.intro", comment: ""))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(HealthSourceLibrary.all) { source in
                        if let url = source.url {
                            Link(destination: url) {
                                sourceCard(for: source)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle(NSLocalizedString("health.sources.title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func sourceCard(for source: HealthSource) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "text.book.closed.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.aiqoMint)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 6) {
                Text(source.title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text(NSLocalizedString(source.summaryKey, comment: ""))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(source.urlString)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.accentColor)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Image(systemName: "arrow.up.right.square")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}
