import SwiftUI

/// Thin persistent banner shown at the top of the Captain chat. Tapping opens
/// the full medical disclaimer as a sheet. Satisfies Apple guideline 1.4.1 by
/// keeping the "wellness, not medical" framing visible on every conversation.
struct CaptainSafetyBanner: View {
    @State private var showFullDisclaimer = false

    private let mint = Color(red: 0.718, green: 0.898, blue: 0.824)
    private let ink  = Color(red: 0.059, green: 0.090, blue: 0.129)

    private var isArabic: Bool {
        AppSettingsStore.shared.appLanguage == .arabic
    }

    private var bannerTitle: String {
        isArabic ? "محادثة للعافية فقط — ليست استشارة طبية"
                 : "Wellness chat only — not medical advice"
    }

    private var accessibilityText: String {
        isArabic ? "محادثة للعافية — ليست استشارة طبية. اضغط لمزيد من المعلومات"
                 : "Wellness chat — not medical advice. Tap for more details"
    }

    private var chevronName: String {
        isArabic ? "chevron.left" : "chevron.right"
    }

    var body: some View {
        Button { showFullDisclaimer = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(mint)
                Text(bannerTitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ink.opacity(0.75))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
                Image(systemName: chevronName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ink.opacity(0.35))
            }
            .padding(.horizontal, 16)
            .frame(height: 40)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.ultraThinMaterial)
                    HStack(spacing: 0) {
                        Rectangle().fill(mint).frame(width: 3)
                        Spacer()
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText)
        .sheet(isPresented: $showFullDisclaimer) {
            NavigationStack {
                MedicalDisclaimerDetailView(mode: .settings)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
        }
    }
}
