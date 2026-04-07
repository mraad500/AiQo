import SwiftUI
import UIKit

private enum TribeFlowDestination: Hashable {
    case join
    case success
}

private struct TribeFeatureDescriptor: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let tint: UIColor

    static let landingCards: [TribeFeatureDescriptor] = [
        TribeFeatureDescriptor(
            id: "connect",
            title: "Connect",
            subtitle: "Find people with similar goals",
            icon: "point.3.connected.trianglepath.dotted",
            tint: UIColor(red: 0.22, green: 0.30, blue: 0.46, alpha: 1)
        ),
        TribeFeatureDescriptor(
            id: "challenges",
            title: "Challenges",
            subtitle: "VIP missions & streak rituals",
            icon: "sparkles.rectangle.stack.fill",
            tint: UIColor(red: 0.28, green: 0.36, blue: 0.54, alpha: 1)
        ),
        TribeFeatureDescriptor(
            id: "levels",
            title: "Levels",
            subtitle: "Earn status through consistency",
            icon: "crown.fill",
            tint: UIColor(red: 0.32, green: 0.39, blue: 0.58, alpha: 1)
        )
    ]
}

struct TribeExperienceFlowView: View {
    let source: TribeMarketingSource

    @Environment(\.dismiss) private var dismiss
    @AppStorage(TribeScreenshotMode.key) private var screenshotModeEnabled = false
    @StateObject private var accessManager = AccessManager.shared

    @State private var path: [TribeFlowDestination] = []
    @State private var selectedInterests: Set<TribeMarketingInterest> = []
    @State private var didSeedScreenshotState = false
    @State private var showPremiumSheet = false
    @State private var showTribeHub = false

    init(source: TribeMarketingSource = .settings) {
        self.source = source
    }

    var body: some View {
        Group {
            if showTribeHub || accessManager.isPreviewModeActive || TribeFeatureFlags.subscriptionGateEnabled == false {
                NavigationStack {
                    TribeScreen()
                }
            } else {
                NavigationStack(path: $path) {
                    TribeLandingScreen(
                        screenshotModeEnabled: screenshotModeEnabled,
                        onJoin: { path.append(.join) },
                        onDismiss: handleDismissAction
                    )
                    .toolbar(.hidden, for: .navigationBar)
                    .navigationDestination(for: TribeFlowDestination.self) { destination in
                        switch destination {
                        case .join:
                            TribeJoinScreen(
                                selectedInterests: $selectedInterests,
                                screenshotModeEnabled: screenshotModeEnabled,
                                onContinue: { path.append(.success) }
                            )
                            .navigationBarTitleDisplayMode(.inline)
                        case .success:
                            TribeSuccessScreen(
                                screenshotModeEnabled: screenshotModeEnabled,
                                onExplore: handleExploreAction,
                                onGoToPremium: handlePremiumAction
                            )
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showPremiumSheet) {
            PaywallView()
        }
        .onAppear(perform: seedScreenshotStateIfNeeded)
    }

    private func seedScreenshotStateIfNeeded() {
        guard screenshotModeEnabled, !didSeedScreenshotState else { return }
        selectedInterests = [.fitness, .discipline]
        didSeedScreenshotState = true
    }

    private func handleDismissAction() {
        switch source {
        case .premium, .settings:
            dismiss()
        case .tab:
            MainTabRouter.shared.navigate(to: .home)
        }
    }

    private func handleExploreAction() {
        switch source {
        case .tab:
            showTribeHub = true
        case .premium, .settings:
            dismiss()
        }
    }

    private func handlePremiumAction() {
        switch source {
        case .premium:
            dismiss()
        case .settings, .tab:
            showPremiumSheet = true
        }
    }
}

private struct TribeLandingScreen: View {
    let screenshotModeEnabled: Bool
    let onJoin: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            PremiumBackgroundView()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    Spacer(minLength: 22)

                    Text("AIQO TRIBE")
                        .font(.system(.largeTitle, design: .rounded, weight: .black))
                        .foregroundStyle(TribePremiumPalette.textPrimary)

                    Text("A calm VIP community for builders of better habits.")
                        .font(.system(.title3, design: .rounded, weight: .medium))
                        .foregroundStyle(TribePremiumPalette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: 14) {
                        ForEach(TribeFeatureDescriptor.landingCards) { card in
                            Button(action: {}) {
                                PremiumGlassCard(tint: card.tint) {
                                    HStack(spacing: 14) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.white.opacity(0.09))
                                                .frame(width: 46, height: 46)

                                            Image(systemName: card.icon)
                                                .font(.system(size: 18, weight: .semibold))
                                                .foregroundStyle(Color.white.opacity(0.86))
                                        }

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(card.title)
                                                .font(.system(.headline, design: .rounded, weight: .semibold))
                                                .foregroundStyle(TribePremiumPalette.textPrimary)

                                            Text(card.subtitle)
                                                .font(.system(.subheadline, design: .rounded, weight: .medium))
                                                .foregroundStyle(TribePremiumPalette.textSecondary)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }

                                        Spacer(minLength: 0)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // STUB: Live Supabase backend not yet connected.
                    // This feature is hidden via TRIBE_FEATURE_VISIBLE=false in Info.plist.
                    // TODO before launch: replace with live SupabaseTribeRepository call.
                    futurePlaceholders

                    Button("Join the Tribe", action: onJoin)
                        .buttonStyle(PrimaryCTAButtonStyle())
                        .padding(.top, 6)

                    Button("Not now", action: onDismiss)
                        .buttonStyle(.plain)
                        .font(.system(.body, design: .rounded, weight: .medium))
                        .foregroundStyle(TribePremiumPalette.textSecondary)
                        .frame(maxWidth: .infinity)

                    // STUB: Live Supabase backend not yet connected.
                    // This feature is hidden via TRIBE_FEATURE_VISIBLE=false in Info.plist.
                    // TODO before launch: replace with live SupabaseTribeRepository call.
                    TribeDebugFootnote(
                        screenshotModeEnabled: screenshotModeEnabled,
                        text: "Preview layer only. Community feed, challenges, and invites are placeholders for now."
                    )
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var futurePlaceholders: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Soon")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(TribePremiumPalette.textSecondary.opacity(0.78))

            HStack(spacing: 8) {
                placeholderPill(title: "Feed")
                placeholderPill(title: "Challenges")
                placeholderPill(title: "Invites")
            }
        }
    }

    private func placeholderPill(title: String) -> some View {
        Text(title)
            .font(.system(.caption, design: .rounded, weight: .semibold))
            .foregroundStyle(TribePremiumPalette.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        Capsule()
                            .stroke(TribePremiumPalette.stroke, lineWidth: 1)
                    )
            )
    }
}

private struct TribeJoinScreen: View {
    @Binding var selectedInterests: Set<TribeMarketingInterest>

    let screenshotModeEnabled: Bool
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            PremiumBackgroundView()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Join the AiQo Tribe")
                        .font(.system(.largeTitle, design: .rounded, weight: .black))
                        .foregroundStyle(TribePremiumPalette.textPrimary)
                        .padding(.top, 26)

                    Text("Choose the signals that fit your style.")
                        .font(.system(.title3, design: .rounded, weight: .medium))
                        .foregroundStyle(TribePremiumPalette.textSecondary)

                    PremiumGlassCard(tint: UIColor(red: 0.24, green: 0.31, blue: 0.48, alpha: 1)) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Focus")
                                .font(.system(.headline, design: .rounded, weight: .semibold))
                                .foregroundStyle(TribePremiumPalette.textPrimary)

                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(TribeMarketingInterest.allCases) { interest in
                                    TribeInterestChip(
                                        title: interest.rawValue,
                                        isSelected: selectedInterests.contains(interest)
                                    ) {
                                        toggle(interest)
                                    }
                                }
                            }

                            Text("No spam. Respect-first.")
                                .font(.system(.footnote, design: .rounded, weight: .medium))
                                .foregroundStyle(TribePremiumPalette.textSecondary)
                        }
                    }

                    Button("Continue", action: onContinue)
                        .buttonStyle(PrimaryCTAButtonStyle())
                        .padding(.top, 4)

                    // STUB: Live Supabase backend not yet connected.
                    // This feature is hidden via TRIBE_FEATURE_VISIBLE=false in Info.plist.
                    // TODO before launch: replace with live SupabaseTribeRepository call.
                    TribeDebugFootnote(
                        screenshotModeEnabled: screenshotModeEnabled,
                        text: "Selections are local only for now. Backend enrollment is intentionally not wired yet."
                    )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
    }

    private func toggle(_ interest: TribeMarketingInterest) {
        if selectedInterests.contains(interest) {
            selectedInterests.remove(interest)
        } else {
            selectedInterests.insert(interest)
        }
    }
}

private struct TribeSuccessScreen: View {
    let screenshotModeEnabled: Bool
    let onExplore: () -> Void
    let onGoToPremium: () -> Void

    var body: some View {
        ZStack {
            PremiumBackgroundView()

            VStack(spacing: 22) {
                Spacer(minLength: 24)

                MetallicOrbEmblem()
                    .frame(width: 164, height: 164)

                Text("Welcome to the Tribe")
                    .font(.system(.largeTitle, design: .rounded, weight: .black))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(TribePremiumPalette.textPrimary)

                Text("You’re in. Keep your aura clean. Build your streak.")
                    .font(.system(.title3, design: .rounded, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(TribePremiumPalette.textSecondary)
                    .padding(.horizontal, 12)

                // STUB: Live Supabase backend not yet connected.
                // This feature is hidden via TRIBE_FEATURE_VISIBLE=false in Info.plist.
                // TODO before launch: replace with live SupabaseTribeRepository call.
                PremiumGlassCard(tint: UIColor(red: 0.22, green: 0.27, blue: 0.41, alpha: 1)) {
                    HStack(spacing: 10) {
                        statusPill(title: "Feed")
                        statusPill(title: "Challenges")
                        statusPill(title: "Invites")
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.top, 8)

                Button("Explore", action: onExplore)
                    .buttonStyle(PrimaryCTAButtonStyle())

                Button("Go to Premium", action: onGoToPremium)
                    .buttonStyle(.plain)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(TribePremiumPalette.textSecondary)

                // STUB: Live Supabase backend not yet connected.
                // This feature is hidden via TRIBE_FEATURE_VISIBLE=false in Info.plist.
                // TODO before launch: replace with live SupabaseTribeRepository call.
                TribeDebugFootnote(
                    screenshotModeEnabled: screenshotModeEnabled,
                    text: "This is a premium community shell for now. Live networking and invites arrive in a later phase."
                )

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
        }
    }

    private func statusPill(title: String) -> some View {
        VStack(spacing: 4) {
            Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 32, height: 32)
                .overlay(
                    Circle()
                        .stroke(TribePremiumPalette.stroke, lineWidth: 1)
                )

            Text(title)
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(TribePremiumPalette.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct TribeInterestChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(title)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(TribePremiumPalette.textPrimary)

                Spacer(minLength: 0)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(
                        isSelected
                        ? TribePremiumPalette.highlight
                        : TribePremiumPalette.textSecondary
                    )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(isSelected ? 0.10 : 0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                isSelected ? TribePremiumPalette.highlight.opacity(0.60) : TribePremiumPalette.stroke,
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct MetallicOrbEmblem: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.28),
                            TribePremiumPalette.highlight.opacity(0.24),
                            Color.white.opacity(0.03)
                        ],
                        center: .topLeading,
                        startRadius: 4,
                        endRadius: 110
                    )
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.18), lineWidth: 1.2)
                )

            Circle()
                .fill(
                    AngularGradient(
                        colors: [
                            Color.white.opacity(0.58),
                            Color.white.opacity(0.12),
                            TribePremiumPalette.highlight.opacity(0.60),
                            Color.white.opacity(0.38)
                        ],
                        center: .center
                    )
                )
                .frame(width: 112, height: 112)
                .blur(radius: 0.3)

            Circle()
                .stroke(Color.white.opacity(0.14), lineWidth: 12)
                .frame(width: 136, height: 136)

            Circle()
                .trim(from: 0.12, to: 0.78)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.55),
                            TribePremiumPalette.highlight.opacity(0.30)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-35))
                .frame(width: 148, height: 148)

            Circle()
                .fill(Color.white.opacity(0.45))
                .frame(width: 18, height: 18)
                .blur(radius: 0.4)
                .offset(x: -20, y: -24)
        }
        .shadow(color: TribePremiumPalette.highlight.opacity(0.22), radius: 24, x: 0, y: 10)
        .shadow(color: Color.black.opacity(0.28), radius: 30, x: 0, y: 16)
    }
}

private struct TribeDebugFootnote: View {
    let screenshotModeEnabled: Bool
    let text: String

    var body: some View {
        Group {
            #if DEBUG
            if !screenshotModeEnabled {
                Text(text)
                    .font(.system(.footnote, design: .rounded, weight: .medium))
                    .foregroundStyle(TribePremiumPalette.textSecondary.opacity(0.84))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
            #endif
        }
    }
}

#Preview("TribeLanding") {
    TribeExperienceFlowView()
}

#Preview("TribeJoin") {
    NavigationStack {
        TribeJoinScreen(
            selectedInterests: .constant([.fitness, .discipline]),
            screenshotModeEnabled: true,
            onContinue: {}
        )
    }
}

#Preview("TribeSuccess") {
    TribeSuccessScreen(
        screenshotModeEnabled: true,
        onExplore: {},
        onGoToPremium: {}
    )
}
