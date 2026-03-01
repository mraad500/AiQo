import Foundation
internal import Combine

struct ArenaLeaderboardEntry: Identifiable {
    let id: String
    let member: TribeMember
    let score: Int
}

@MainActor
final class ArenaStore: ObservableObject {
    @Published private(set) var challenges: [TribeChallenge] = []
    @Published private(set) var curatedChallenges: [TribeChallenge] = []
    @Published private(set) var pendingSuggestions: [GalaxyChallengeSuggestion] = []
    @Published var selectedCadence: ChallengeCadence = .daily
    @Published var showOnlyMyTribe = false
    @Published var activeChallengeId: String?
    @Published var statusMessage: String?

    private let repository: any ChallengeRepositoryProtocol

    init(repository: (any ChallengeRepositoryProtocol)? = nil) {
        self.repository = repository ?? TribeRepositoryFactory.makeChallengeRepository()
    }

    func load() async {
        await load(using: repository)
    }

    func load(using repository: any ChallengeRepositoryProtocol) async {
        let loadedChallenges = await repository.loadChallenges()
        let loadedCurated = await repository.loadCuratedGalaxyChallenges()
        let preferredActiveId = activeChallengeId
        challenges = loadedChallenges
        curatedChallenges = loadedCurated
        pendingSuggestions = []
        statusMessage = nil

        if let preferredActiveId,
           loadedChallenges.contains(where: { $0.id == preferredActiveId }) {
            activeChallengeId = preferredActiveId
        } else {
            activeChallengeId = loadedChallenges.first?.id ?? loadedCurated.first?.id
        }
    }

    func challenges(for cadence: ChallengeCadence, scope: ChallengeScope) -> [TribeChallenge] {
        let source = showOnlyMyTribe && scope == .galaxy ? [] : challenges
        return source
            .filter { $0.cadence == cadence && $0.scope == scope }
            .sorted { lhs, rhs in
                if lhs.isCuratedGlobal == rhs.isCuratedGlobal {
                    return lhs.endAt < rhs.endAt
                }
                return lhs.isCuratedGlobal && !rhs.isCuratedGlobal
            }
    }

    func featuredGalaxyChallenges(for cadence: ChallengeCadence) -> [TribeChallenge] {
        curatedChallenges
            .filter { $0.cadence == cadence }
            .sorted { $0.endAt < $1.endAt }
    }

    func setActiveChallenge(_ challenge: TribeChallenge) {
        activeChallengeId = challenge.id
    }

    func contribute(to challenge: TribeChallenge) {
        guard let index = challenges.firstIndex(where: { $0.id == challenge.id }) else { return }

        activeChallengeId = challenge.id
        challenges[index].progressValue = min(
            challenges[index].targetValue,
            challenges[index].progressValue + challenge.metricType.defaultIncrement
        )
        showStatus("tribe.toast.challengeUpdated".localized)
    }

    func createChallenge(
        scope: ChallengeScope,
        cadence: ChallengeCadence,
        metricType: TribeChallengeMetricType,
        title: String,
        subtitle: String
    ) {
        if scope == .galaxy {
            showStatus("tribe.toast.galaxyCuratedOnly".localized)
            return
        }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let challenge = TribeChallenge(
            id: "local-\(UUID().uuidString)",
            scope: scope,
            cadence: cadence,
            title: trimmedTitle.isEmpty ? fallbackTitle(for: metricType, cadence: cadence) : trimmedTitle,
            subtitle: subtitle,
            metricType: metricType,
            targetValue: suggestedTarget(for: metricType, cadence: cadence),
            progressValue: 0,
            endAt: cadence == .daily ? Date().addingTimeInterval(60 * 60 * 24) : Date().addingTimeInterval(60 * 60 * 24 * 30),
            createdByUserId: "tribe-self",
            isCuratedGlobal: false,
            participantsCount: scope == .tribe ? 1 : 1
        )

        challenges.insert(challenge, at: 0)
        activeChallengeId = challenge.id
        showStatus("tribe.toast.challengeCreated".localized)
    }

    func suggestGalaxyChallenge(
        title: String,
        metricType: TribeChallengeMetricType,
        cadence: ChallengeCadence
    ) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            showStatus("tribe.toast.challengeTitleRequired".localized)
            return
        }

        let suggestion = GalaxyChallengeSuggestion(
            id: "suggestion-\(UUID().uuidString)",
            title: trimmedTitle,
            metricType: metricType,
            cadence: cadence,
            proposedByUserId: "tribe-self",
            status: .pendingSuggestion,
            createdAt: .now
        )

        pendingSuggestions.insert(suggestion, at: 0)
        showStatus("tribe.toast.challengeSuggested".localized)
    }

    func leaderboard(for challenge: TribeChallenge, members: [TribeMember]) -> [ArenaLeaderboardEntry] {
        members
            .sorted {
                if $0.auraEnergyToday == $1.auraEnergyToday {
                    return $0.level > $1.level
                }
                return $0.auraEnergyToday > $1.auraEnergyToday
            }
            .prefix(5)
            .enumerated()
            .map { index, member in
                ArenaLeaderboardEntry(
                    id: "\(challenge.id)-\(member.id)",
                    member: member,
                    score: max(1, member.auraEnergyToday - (index * 2))
                )
            }
    }

    private func showStatus(_ message: String) {
        statusMessage = message

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            if self.statusMessage == message {
                self.statusMessage = nil
            }
        }
    }

    private func fallbackTitle(for metricType: TribeChallengeMetricType, cadence: ChallengeCadence) -> String {
        switch (metricType, cadence) {
        case (.steps, .daily):
            return "tribe.challenge.template.steps.daily".localized
        case (.steps, .monthly):
            return "tribe.challenge.template.steps.monthly".localized
        case (.water, .daily):
            return "tribe.challenge.template.water.daily".localized
        case (.water, .monthly):
            return "tribe.challenge.template.water.monthly".localized
        case (.sleep, .daily):
            return "tribe.challenge.template.sleep.daily".localized
        case (.sleep, .monthly):
            return "tribe.challenge.template.sleep.monthly".localized
        case (.minutes, .daily), (.calmMinutes, .daily):
            return "tribe.challenge.template.calm.daily".localized
        case (.minutes, .monthly), (.calmMinutes, .monthly):
            return "tribe.challenge.template.calm.monthly".localized
        case (.sugarFree, .daily):
            return "tribe.challenge.template.sugarFree.daily".localized
        case (.sugarFree, .monthly):
            return "tribe.challenge.template.sugarFree.monthly".localized
        case (.custom, .daily):
            return "tribe.challenge.template.custom.daily".localized
        case (.custom, .monthly):
            return "tribe.challenge.template.custom.monthly".localized
        }
    }

    private func suggestedTarget(for metricType: TribeChallengeMetricType, cadence: ChallengeCadence) -> Int {
        switch (metricType, cadence) {
        case (.steps, .daily):
            return 10_000
        case (.steps, .monthly):
            return 120_000
        case (.water, .daily):
            return 12
        case (.water, .monthly):
            return 180
        case (.sleep, .daily):
            return 8
        case (.sleep, .monthly):
            return 40
        case (.minutes, .daily), (.calmMinutes, .daily):
            return 20
        case (.minutes, .monthly), (.calmMinutes, .monthly):
            return 240
        case (.custom, .daily):
            return 10
        case (.custom, .monthly):
            return 30
        case (.sugarFree, .daily):
            return 1
        case (.sugarFree, .monthly):
            return 20
        }
    }
}
