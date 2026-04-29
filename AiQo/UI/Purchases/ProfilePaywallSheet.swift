import SwiftUI

/// Wraps `PaywallView` for non-onboarding contexts (e.g. opened from the
/// Profile "Subscription" section). Adds an explicit back button overlay so
/// the user can dismiss the full-screen paywall without making a purchase.
struct ProfilePaywallSheet: View {
    let onDismiss: () -> Void

    @AppStorage("aiqo.app.language") private var appLanguage = AppLanguage.arabic.rawValue

    private var isArabic: Bool {
        appLanguage == AppLanguage.arabic.rawValue
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            PaywallView(source: .manual, onPurchaseSuccess: onDismiss)

            PaywallDismissChip(
                label: NSLocalizedString(
                    "profile.paywall.back",
                    value: isArabic ? "رجوع" : "Back",
                    comment: ""
                ),
                icon: isArabic ? "chevron.right" : "chevron.left",
                action: onDismiss
            )
            .padding(.top, 6)
            .padding(.leading, 18)
            .accessibilityIdentifier("profile-paywall-back")
        }
        .environment(\.layoutDirection, isArabic ? .rightToLeft : .leftToRight)
        .environment(\.locale, Locale(identifier: isArabic ? "ar" : "en"))
    }
}
