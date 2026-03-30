// Supabase hook: replace the locally seeded `GalaxyViewModel` with a dependency-injected
// store once Tribe graph data and challenges are loaded from the backend.
import SwiftUI

@MainActor
struct GalaxyScreen: View {
    @StateObject private var viewModel: GalaxyViewModel

    init() {
        _viewModel = StateObject(wrappedValue: GalaxyViewModel())
    }

    init(initialCardMode: GalaxyCardMode) {
        _viewModel = StateObject(wrappedValue: GalaxyViewModel(initialCardMode: initialCardMode))
    }

    init(viewModel: GalaxyViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let toastMessage = viewModel.toastMessage {
                HStack {
                    Spacer(minLength: 0)
                    GalaxyToast(message: toastMessage)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            GalaxyProjectImageCard(height: 220, contentMode: .fill)

            GalaxyExperienceCard(viewModel: viewModel)

            Text(NSLocalizedString("galaxy.soulConnected", comment: ""))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.58))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 4)
        }
        .animation(.spring(response: 0.36, dampingFraction: 0.88), value: viewModel.toastMessage)
    }
}

@MainActor
struct GalaxyExperienceCard: View {
    @ObservedObject var viewModel: GalaxyViewModel

    var body: some View {
        TribeGlassCard(
            cornerRadius: 32,
            padding: 18,
            tint: Color(hue: viewModel.activeAccentHue, saturation: 0.28, brightness: 0.90).opacity(0.04)
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(NSLocalizedString("tribe.galaxy.title", comment: ""))
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text(viewModel.cardMode == .network ? NSLocalizedString("galaxy.networkSubtitle", comment: "") : NSLocalizedString("galaxy.arenaSubtitle", comment: ""))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.62))
                    }

                    Spacer(minLength: 12)

                    TribeSegmentedPill(
                        options: GalaxyCardMode.allCases,
                        selection: Binding(
                            get: { viewModel.cardMode },
                            set: { viewModel.setCardMode($0) }
                        ),
                        title: { $0.title }
                    )
                    .frame(maxWidth: 190)
                }

                Group {
                    if viewModel.cardMode == .network {
                        TribeSegmentedPill(
                            options: GalaxyConnectionStyle.allCases,
                            selection: Binding(
                                get: { viewModel.connectionStyle },
                                set: { viewModel.setConnectionStyle($0) }
                            ),
                            title: { $0.title }
                        )
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "scope")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.60))
                            Text(NSLocalizedString("galaxy.challengesDescription", comment: ""))
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.58))
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .transition(.opacity)

                ZStack(alignment: .bottom) {
                    ConstellationCanvasView(viewModel: viewModel)

                    Group {
                        switch viewModel.cardMode {
                        case .network:
                            if let selectedNode = viewModel.selectedNode {
                                GalaxySelectionCard(
                                    node: selectedNode,
                                    tribeName: viewModel.tribeName,
                                    onSpark: viewModel.sendSparkFromSelected,
                                    onTogglePreview: viewModel.togglePreviewMode
                                )
                            }
                        case .arena:
                            GalaxyArenaSheet(viewModel: viewModel)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.spring(response: 0.38, dampingFraction: 0.86), value: viewModel.cardMode)
            }
        }
    }
}

@MainActor
private struct GalaxyArenaSheet: View {
    @ObservedObject var viewModel: GalaxyViewModel

    var body: some View {
        TribeGlassCard(
            cornerRadius: 26,
            padding: 14,
            tint: Color(hue: viewModel.activeAccentHue, saturation: 0.28, brightness: 0.92).opacity(0.05)
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 8) {
                    Text(NSLocalizedString("galaxy.orbitMissions", comment: ""))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)

                    Spacer(minLength: 8)

                    if let activeChallenge = viewModel.activeChallenge {
                        Text(activeChallenge.cadence.title)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.64))
                    }
                }

                ForEach(Array(viewModel.featuredChallenges.prefix(3))) { challenge in
                    GalaxyChallengeMiniCard(
                        challenge: challenge,
                        isActive: challenge.id == viewModel.activeChallengeId,
                        onTap: {
                            viewModel.activateChallenge(challenge)
                        },
                        onContribute: {
                            viewModel.contributeToChallenge(challenge)
                        }
                    )
                }
            }
        }
    }
}

#Preview("Galaxy Network") {
    ZStack {
        TribeGalaxyBackground()

        ScrollView(showsIndicators: false) {
            GalaxyScreen()
                .padding(16)
        }
    }
    .environment(\.layoutDirection, .rightToLeft)
}

#Preview("Galaxy Arena") {
    ZStack {
        TribeGalaxyBackground()

        ScrollView(showsIndicators: false) {
            GalaxyScreen(initialCardMode: .arena)
                .padding(16)
        }
    }
    .environment(\.layoutDirection, .rightToLeft)
}
