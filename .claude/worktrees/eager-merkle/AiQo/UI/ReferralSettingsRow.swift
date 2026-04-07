import SwiftUI

/// صف الإحالة بشاشة الإعدادات
struct ReferralSettingsRow: View {
    @StateObject private var referralManager = ReferralManager.shared
    @State private var showShareSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("referral.title".localized)
                        .foregroundStyle(.primary)

                    Text("referral.subtitle".localized)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Text(String(format: "referral.yourCode".localized, referralManager.referralCode))
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(.blue)
                }

                Spacer()

                Button {
                    showShareSheet = true
                } label: {
                    Text("referral.share".localized)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.blue)
                        )
                }
                .buttonStyle(.plain)
            }

            if referralManager.bonusDaysEarned > 0 {
                Text(String(format: "referral.earned".localized, referralManager.bonusDaysEarned))
                    .font(.footnote)
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [referralManager.shareText])
        }
    }
}

/// UIKit share sheet wrapper
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
