import SwiftUI

/// Glassmorphism locked-feature card. Surfaces when a user lacks subscription
/// access to a Captain feature. RTL-first, mint/sand brand, SF Symbols only.
/// Callers supply `onUpgradeTap` — this view never imperatively presents a paywall;
/// the host flips a local `showPaywall` flag in that closure.
struct CaptainLockedView: View {

    struct Config {
        let title: String
        let subtitle: String
        let iconSystemName: String
        let tier: SubscriptionTier
        let onUpgradeTap: () -> Void

        init(
            title: String,
            subtitle: String,
            iconSystemName: String,
            tier: SubscriptionTier = .max,
            onUpgradeTap: @escaping () -> Void
        ) {
            self.title = title
            self.subtitle = subtitle
            self.iconSystemName = iconSystemName
            self.tier = tier
            self.onUpgradeTap = onUpgradeTap
        }
    }

    let config: Config

    init(config: Config) {
        self.config = config
    }

    private let mint = Color(red: 0.718, green: 0.898, blue: 0.824)  // #B7E5D2
    private let sand = Color(red: 0.922, green: 0.812, blue: 0.592)  // #EBCF97

    var body: some View {
        VStack(spacing: 20) {
            iconBadge

            VStack(spacing: 6) {
                Text(config.title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                Text(config.subtitle)
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            upgradeButton
        }
        .padding(28)
        .frame(maxWidth: 360)
        .background(cardBackground)
        .environment(\.layoutDirection, .rightToLeft)
    }

    private var iconBadge: some View {
        ZStack {
            Circle()
                .fill(mint.opacity(0.25))
                .frame(width: 72, height: 72)
            Image(systemName: config.iconSystemName)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.primary)
        }
    }

    private var upgradeButton: some View {
        Button(action: config.onUpgradeTap) {
            HStack(spacing: 8) {
                Image(systemName: "lock.open.fill")
                    .font(.system(size: 14, weight: .semibold))
                let unlockLabel = config.tier.displayName.isEmpty
                    ? "افتح"
                    : "افتح \(config.tier.displayName)"
                Text(unlockLabel)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(sand.opacity(0.9))
            )
        }
        .buttonStyle(.plain)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [mint.opacity(0.6), sand.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 8)
    }
}

#Preview {
    ZStack {
        Color(red: 0.973, green: 0.961, blue: 0.937).ignoresSafeArea()
        CaptainLockedView(config: .init(
            title: "الذاكرة",
            subtitle: "حمودي يتذكر محادثاتك ويبني عليها كل يوم. افتح AiQo Max لتفعيلها.",
            iconSystemName: "brain.head.profile",
            tier: .max,
            onUpgradeTap: {}
        ))
    }
}
