// Supabase hook: bind the creation form and contribution actions here to your challenge
// API once Arena data is no longer local preview data.
import SwiftUI

@MainActor
struct ArenaScreen: View {
    @StateObject private var arenaViewModel: ArenaViewModel
    @StateObject private var galaxyViewModel: GalaxyViewModel

    init() {
        let arena = ArenaViewModel()
        let galaxy = GalaxyViewModel(initialCardMode: .arena)
        galaxy.replaceChallenges(with: arena.featuredChallenges)
        _arenaViewModel = StateObject(wrappedValue: arena)
        _galaxyViewModel = StateObject(wrappedValue: galaxy)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let message = arenaViewModel.message {
                HStack {
                    Spacer(minLength: 0)
                    GalaxyToast(message: message)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            GalaxyExperienceCard(viewModel: galaxyViewModel)

            ForEach(ChallengeCadence.allCases) { cadence in
                ArenaChallengeGroupCard(
                    title: cadence.sectionTitle,
                    cadence: cadence,
                    viewModel: arenaViewModel,
                    onSelect: { challenge in
                        arenaViewModel.select(challenge)
                        syncHeroState(focusing: challenge)
                        galaxyViewModel.activateChallenge(challenge)
                    },
                    onContribute: { challenge in
                        arenaViewModel.contribute(to: challenge)
                        syncHeroState(focusing: arenaViewModel.challenges.first(where: { $0.id == challenge.id }))
                        if let refreshedChallenge = arenaViewModel.challenges.first(where: { $0.id == challenge.id }) {
                            galaxyViewModel.presentContribution(for: refreshedChallenge)
                        }
                    }
                )
            }

            ArenaComposerCard(viewModel: arenaViewModel) {
                arenaViewModel.createChallenge()
                syncHeroState(focusing: arenaViewModel.challenges.first)
            }
        }
        .animation(.spring(response: 0.36, dampingFraction: 0.88), value: arenaViewModel.message)
    }

    private func syncHeroState(focusing challenge: TribeChallenge?) {
        var heroChallenges = arenaViewModel.featuredChallenges

        if let challenge, !heroChallenges.contains(where: { $0.id == challenge.id }) {
            heroChallenges.insert(challenge, at: 0)
        }

        galaxyViewModel.replaceChallenges(with: Array(heroChallenges.prefix(4)))
    }
}

@MainActor
private struct ArenaChallengeGroupCard: View {
    let title: String
    let cadence: ChallengeCadence
    @ObservedObject var viewModel: ArenaViewModel
    let onSelect: (TribeChallenge) -> Void
    let onContribute: (TribeChallenge) -> Void

    var body: some View {
        TribeGlassCard(cornerRadius: 28, padding: 16, tint: Color.white.opacity(0.02)) {
            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)

                ForEach(ChallengeScope.allCases) { scope in
                    let items = viewModel.challenges(for: cadence, scope: scope)
                    if !items.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(scope.title)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.64))

                            ForEach(items) { challenge in
                                GalaxyChallengeMiniCard(
                                    challenge: challenge,
                                    isActive: challenge.id == viewModel.activeChallengeId,
                                    onTap: {
                                        onSelect(challenge)
                                    },
                                    onContribute: {
                                        onContribute(challenge)
                                    }
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@MainActor
private struct ArenaComposerCard: View {
    @ObservedObject var viewModel: ArenaViewModel
    let onCreate: () -> Void

    var body: some View {
        TribeGlassCard(cornerRadius: 28, padding: 16, tint: Color.white.opacity(0.02)) {
            VStack(alignment: .leading, spacing: 14) {
                Text("إنشاء تحدٍ جديد")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)

                TribeSegmentedPill(
                    options: ChallengeScope.allCases,
                    selection: $viewModel.createScope,
                    title: { $0.title }
                )

                TribeSegmentedPill(
                    options: ChallengeCadence.allCases,
                    selection: $viewModel.createCadence,
                    title: { $0.title }
                )

                Menu {
                    ForEach(ChallengeGoalType.allCases) { goalType in
                        Button(goalType.title) {
                            viewModel.createGoalType = goalType
                        }
                    }
                } label: {
                    HStack {
                        Text("الهدف")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.62))

                        Spacer(minLength: 8)

                        Text(viewModel.createGoalType.title)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.56))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    )
                }

                TextField("عنوان التحدي (اختياري)", text: $viewModel.customTitle)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    )
                    .foregroundStyle(.white)

                Button(action: onCreate) {
                    Text("إضافة التحدي")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)

                Text("تحديات المجرة مختارة من AiQo، ويمكنك إنشاء تحديات شخصية أو قبلية فقط.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.54))
            }
        }
    }
}

#Preview {
    ZStack {
        TribeGalaxyBackground()

        ScrollView(showsIndicators: false) {
            ArenaScreen()
                .padding(16)
        }
    }
    .environment(\.layoutDirection, .rightToLeft)
}
