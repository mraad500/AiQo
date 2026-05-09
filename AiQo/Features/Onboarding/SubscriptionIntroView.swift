import SwiftUI

/// Onboarding wrapper around `PaywallView`. Shows the full paywall as part of
/// the first-run flow, plus a prominent "Skip" button at the top so users who
/// don't want to subscribe can still finish onboarding.
struct SubscriptionIntroView: View {
    let onContinue: () -> Void

    @AppStorage("aiqo.app.language") private var appLanguage = AppLanguage.arabic.rawValue

    private var isArabic: Bool {
        appLanguage == AppLanguage.arabic.rawValue
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            PaywallView(source: .manual, onPurchaseSuccess: onContinue)

            PaywallDismissChip(
                label: NSLocalizedString(
                    "subscriptionIntro.skip",
                    value: isArabic ? "تخطي" : "Skip",
                    comment: ""
                ),
                icon: isArabic ? "chevron.left" : "chevron.right",
                action: onContinue
            )
            .padding(.top, 6)
            .padding(.trailing, 18)
            .accessibilityIdentifier("subscription-intro-skip")
        }
        .environment(\.layoutDirection, isArabic ? .rightToLeft : .leftToRight)
        .environment(\.locale, Locale(identifier: isArabic ? "ar" : "en"))
    }
}

/// Reusable pill-style dismiss button placed on top of the dark `PaywallView`.
/// Used by both the onboarding intro and the profile-section sheet.
struct PaywallDismissChip: View {
    let label: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                Text(label)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule().fill(Color.white.opacity(0.22))
            )
            .overlay(
                Capsule().stroke(Color.white.opacity(0.45), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }
}
