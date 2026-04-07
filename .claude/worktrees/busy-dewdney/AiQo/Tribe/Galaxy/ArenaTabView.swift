import SwiftUI
import SwiftData

struct ArenaTabView: View {
    @Binding var userTribe: ArenaTribe?
    @Environment(EmaraArenaViewModel.self) private var arenaVM
    @State private var isParticipating: Bool = true
    @State private var showCreateTribe = false
    @State private var showJoinTribe = false
    @State private var showTribeInvite = false
    @State private var showHallOfFameFull = false

    private var liveChallenge: ArenaWeeklyChallenge? {
        arenaVM.currentChallenge
    }

    private var liveLeaders: ArenaEmirateLeaders? {
        nil // Populated from real data when available
    }

    private var liveChallengeTitle: String {
        arenaVM.hallOfFame.first?.challengeTitle ?? ""
    }

    private var liveParticipations: [LeaderboardRow] {
        arenaVM.leaderboard
    }

    private var liveHallOfFame: [ArenaHallOfFameEntry] {
        arenaVM.hallOfFame
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                EmirateLeadersBanner(
                    leaders: liveLeaders,
                    winningTribe: userTribe,
                    challengeTitle: liveChallengeTitle
                )

                WeeklyChallengeCard(
                    challenge: liveChallenge,
                    userTribe: userTribe,
                    isParticipating: isParticipating,
                    userTribeScore: userTribe != nil ? userTribeScore : 0,
                    leadingScore: liveParticipations.first?.score ?? 100,
                    onJoinChallenge: { isParticipating = true }
                )

                BattleLeaderboard(
                    participations: liveParticipations,
                    userTribeName: userTribe?.name
                )

                if userTribe == nil {
                    noTribePrompt
                }

                HallOfFameSection(
                    entries: Array(liveHallOfFame.prefix(3)),
                    onShowAll: { showHallOfFameFull = true }
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .environment(\.layoutDirection, .rightToLeft)
        .sheet(isPresented: $showCreateTribe) {
            CreateTribeSheet { tribe in userTribe = tribe }
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showJoinTribe) {
            JoinTribeSheet { _ in
                userTribe = arenaVM.myTribe
            }
            .presentationDetents([.height(340)])
        }
        .sheet(isPresented: $showTribeInvite) {
            if let tribe = userTribe {
                TribeInviteView(tribe: tribe)
            }
        }
        .sheet(isPresented: $showHallOfFameFull) {
            HallOfFameFullView(entries: liveHallOfFame)
        }
    }

    private var userTribeScore: Double {
        guard let name = userTribe?.name else { return 0 }
        return liveParticipations.first(where: { $0.tribeName == name })?.score ?? 0
    }

    private var noTribePrompt: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 32))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.aiqoMint)

            Text(NSLocalizedString("arena.tribesCompete", comment: ""))
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(TribePalette.textPrimary)

            Text(NSLocalizedString("arena.createOrJoin", comment: ""))
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(TribePalette.textSecondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button { showCreateTribe = true } label: {
                    Text(NSLocalizedString("arena.createTribe", comment: ""))
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(hex: "2D6B4A"))
                        )
                        .shadow(color: Color(hex: "2D6B4A").opacity(0.2), radius: 8, y: 3)
                }

                Button { showJoinTribe = true } label: {
                    Text(NSLocalizedString("arena.joinWithCode", comment: ""))
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(Color(hex: "2D6B4A"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color(hex: "2D6B4A").opacity(0.4), lineWidth: 1.5)
                        )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                )
        )
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
    }
}
