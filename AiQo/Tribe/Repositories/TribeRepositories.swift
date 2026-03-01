import Foundation

private func tribeRepo(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

struct TribeRepositorySnapshot {
    var tribe: Tribe?
    var members: [TribeMember]
    var missions: [TribeMission]
    var events: [TribeEvent]
}

protocol TribeRepositoryProtocol {
    func loadSnapshot() async -> TribeRepositorySnapshot
}

protocol ChallengeRepositoryProtocol {
    func loadChallenges() async -> [TribeChallenge]
    func loadCuratedGalaxyChallenges() async -> [TribeChallenge]
}

enum TribeRepositoryFactory {
    static func makeTribeRepository() -> any TribeRepositoryProtocol {
        if TribeFeatureFlags.backendEnabled {
            return SupabaseTribeRepository()
        }
        return MockTribeRepository()
    }

    static func makeChallengeRepository() -> any ChallengeRepositoryProtocol {
        if TribeFeatureFlags.backendEnabled {
            return SupabaseChallengeRepository()
        }
        return MockChallengeRepository()
    }
}

struct MockTribeRepository: TribeRepositoryProtocol {
    func loadSnapshot() async -> TribeRepositorySnapshot {
        let tribe = Tribe(
            id: "tribe-calm",
            name: tribeRepo("tribe.mock.name"),
            ownerUserId: "tribe-owner",
            inviteCode: "AIQO30",
            createdAt: Date().addingTimeInterval(-(60 * 60 * 24 * 18))
        )

        let members = [
            TribeMember(
                id: "tribe-owner",
                userId: "tribe-owner",
                displayName: "ليان",
                displayNamePublic: "ليان",
                displayNamePrivate: "لي",
                avatarURL: nil,
                level: 19,
                privacyMode: .public,
                energyContributionToday: 46,
                initials: "لي",
                isLeader: true,
                role: .owner
            ),
            TribeMember(
                id: "tribe-admin-1",
                userId: "tribe-admin-1",
                displayName: "سكون",
                displayNamePublic: "سكون",
                displayNamePrivate: "سك",
                avatarURL: nil,
                level: 17,
                privacyMode: .public,
                energyContributionToday: 38,
                initials: "سك",
                role: .admin
            ),
            TribeMember(
                id: "tribe-self",
                userId: "tribe-self",
                displayName: tribeRepo("tribe.mock.selfName"),
                displayNamePublic: tribeRepo("tribe.mock.selfName"),
                displayNamePrivate: "أن",
                avatarURL: nil,
                level: 16,
                privacyMode: .private,
                energyContributionToday: 34,
                initials: "أن",
                role: .member
            ),
            TribeMember(id: "member-01", displayName: "نور", displayNamePublic: "نور", displayNamePrivate: "نو", level: 14, privacyMode: .public, energyContributionToday: 29, initials: "نو"),
            TribeMember(id: "member-02", displayName: "مدى", displayNamePublic: "مدى", displayNamePrivate: "مد", level: 13, privacyMode: .public, energyContributionToday: 27, initials: "مد"),
            TribeMember(id: "member-03", displayName: tribeRepo("tribe.mock.privateMember"), displayNamePublic: "روح", displayNamePrivate: "ره", level: 13, privacyMode: .private, energyContributionToday: 25, initials: "ره"),
            TribeMember(id: "member-04", displayName: "أمل", displayNamePublic: "أمل", displayNamePrivate: "أم", level: 12, privacyMode: .public, energyContributionToday: 22, initials: "أم"),
            TribeMember(id: "member-05", displayName: "صفا", displayNamePublic: "صفا", displayNamePrivate: "صف", level: 11, privacyMode: .public, energyContributionToday: 20, initials: "صف"),
            TribeMember(id: "member-06", displayName: tribeRepo("tribe.mock.privateMember"), displayNamePublic: "وتر", displayNamePrivate: "وت", level: 11, privacyMode: .private, energyContributionToday: 18, initials: "وت"),
            TribeMember(id: "member-07", displayName: "غيم", displayNamePublic: "غيم", displayNamePrivate: "غي", level: 10, privacyMode: .public, energyContributionToday: 16, initials: "غي"),
            TribeMember(id: "member-08", displayName: "وَجد", displayNamePublic: "وَجد", displayNamePrivate: "وج", level: 9, privacyMode: .public, energyContributionToday: 13, initials: "وج"),
            TribeMember(id: "member-09", displayName: "عضو خاص", displayNamePublic: "أثر", displayNamePrivate: "أث", level: 8, privacyMode: .private, energyContributionToday: 11, initials: "أث")
        ]

        let now = Date()
        let missions = [
            TribeMission(
                id: "mission-daily-energy",
                title: tribeRepo("tribe.mock.mission.energy"),
                targetValue: 500,
                progressValue: members.reduce(0) { $0 + $1.energyToday },
                endsAt: now.addingTimeInterval(60 * 60 * 11)
            ),
            TribeMission(
                id: "mission-monthly-calm",
                title: tribeRepo("tribe.mock.mission.calm"),
                targetValue: 180,
                progressValue: 122,
                endsAt: now.addingTimeInterval(60 * 60 * 24 * 19)
            )
        ]

        let events = [
            TribeEvent(id: "event-01", type: .memberJoined, actorId: "member-07", actorDisplayName: "غيم", message: tribeRepo("tribe.mock.event.memberJoined"), createdAt: now.addingTimeInterval(-60 * 32)),
            TribeEvent(id: "event-02", type: .sparkSent, actorId: "tribe-self", actorDisplayName: tribeRepo("tribe.mock.selfName"), message: tribeRepo("tribe.mock.event.spark"), value: 2, createdAt: now.addingTimeInterval(-60 * 56)),
            TribeEvent(id: "event-03", type: .challengeCompleted, actorId: "tribe-admin-1", actorDisplayName: "سكون", message: tribeRepo("tribe.mock.event.challengeCompleted"), createdAt: now.addingTimeInterval(-60 * 90)),
            TribeEvent(id: "event-04", type: .leadChanged, actorId: "tribe-owner", actorDisplayName: "ليان", message: tribeRepo("tribe.mock.event.leadChanged"), createdAt: now.addingTimeInterval(-60 * 130)),
            TribeEvent(id: "event-05", type: .contribution, actorId: "member-01", actorDisplayName: "نور", message: tribeRepo("tribe.mock.event.contribution"), value: 12, createdAt: now.addingTimeInterval(-60 * 165)),
            TribeEvent(id: "event-06", type: .challengeSuggested, actorId: "tribe-self", actorDisplayName: tribeRepo("tribe.mock.selfName"), message: tribeRepo("tribe.mock.event.suggested"), createdAt: now.addingTimeInterval(-60 * 210))
        ]

        return TribeRepositorySnapshot(
            tribe: tribe,
            members: members,
            missions: missions,
            events: events.sorted { $0.createdAt > $1.createdAt }
        )
    }
}

struct MockChallengeRepository: ChallengeRepositoryProtocol {
    func loadChallenges() async -> [TribeChallenge] {
        let now = Date()
        return [
            TribeChallenge(
                id: "challenge-personal-daily-calm",
                scope: .personal,
                cadence: .daily,
                title: tribeRepo("tribe.mock.challenge.personalCalm.title"),
                subtitle: tribeRepo("tribe.mock.challenge.personalCalm.subtitle"),
                metricType: .calmMinutes,
                targetValue: 20,
                progressValue: 8,
                endAt: now.addingTimeInterval(60 * 60 * 10),
                createdByUserId: "tribe-self",
                participantsCount: 1
            ),
            TribeChallenge(
                id: "challenge-tribe-daily-steps",
                scope: .tribe,
                cadence: .daily,
                title: tribeRepo("tribe.mock.challenge.tribeSteps.title"),
                subtitle: tribeRepo("tribe.mock.challenge.tribeSteps.subtitle"),
                metricType: .steps,
                targetValue: 50_000,
                progressValue: 37_600,
                endAt: now.addingTimeInterval(60 * 60 * 11),
                createdByUserId: "tribe-owner",
                participantsCount: 9
            ),
            TribeChallenge(
                id: "challenge-tribe-daily-water",
                scope: .tribe,
                cadence: .daily,
                title: tribeRepo("tribe.mock.challenge.tribeWater.title"),
                subtitle: tribeRepo("tribe.mock.challenge.tribeWater.subtitle"),
                metricType: .water,
                targetValue: 40,
                progressValue: 28,
                endAt: now.addingTimeInterval(60 * 60 * 8),
                createdByUserId: "tribe-admin-1",
                participantsCount: 7
            ),
            TribeChallenge(
                id: "challenge-personal-monthly-steps",
                scope: .personal,
                cadence: .monthly,
                title: tribeRepo("tribe.mock.challenge.personalMonthlySteps.title"),
                subtitle: tribeRepo("tribe.mock.challenge.personalMonthlySteps.subtitle"),
                metricType: .steps,
                targetValue: 120_000,
                progressValue: 74_000,
                endAt: now.addingTimeInterval(60 * 60 * 24 * 20),
                createdByUserId: "tribe-self",
                participantsCount: 1
            ),
            TribeChallenge(
                id: "challenge-tribe-monthly-sleep",
                scope: .tribe,
                cadence: .monthly,
                title: tribeRepo("tribe.mock.challenge.tribeSleep.title"),
                subtitle: tribeRepo("tribe.mock.challenge.tribeSleep.subtitle"),
                metricType: .sleep,
                targetValue: 40,
                progressValue: 26,
                endAt: now.addingTimeInterval(60 * 60 * 24 * 18),
                createdByUserId: "tribe-owner",
                participantsCount: 6
            )
        ] + curatedGalaxyChallenges(reference: now)
    }

    func loadCuratedGalaxyChallenges() async -> [TribeChallenge] {
        curatedGalaxyChallenges(reference: Date())
    }

    private func curatedGalaxyChallenges(reference now: Date) -> [TribeChallenge] {
        [
            TribeChallenge(
                id: "curated-daily-water",
                scope: .galaxy,
                cadence: .daily,
                title: tribeRepo("tribe.mock.challenge.curatedDailyWater.title"),
                subtitle: tribeRepo("tribe.mock.challenge.curatedDailyWater.subtitle"),
                metricType: .water,
                targetValue: 40,
                progressValue: 19,
                endAt: now.addingTimeInterval(60 * 60 * 9),
                isCuratedGlobal: true,
                participantsCount: 142
            ),
            TribeChallenge(
                id: "curated-daily-sugar",
                scope: .galaxy,
                cadence: .daily,
                title: tribeRepo("tribe.mock.challenge.curatedDailySugar.title"),
                subtitle: tribeRepo("tribe.mock.challenge.curatedDailySugar.subtitle"),
                metricType: .sugarFree,
                targetValue: 1,
                progressValue: 0,
                endAt: now.addingTimeInterval(60 * 60 * 12),
                isCuratedGlobal: true,
                participantsCount: 98
            ),
            TribeChallenge(
                id: "curated-daily-calm",
                scope: .galaxy,
                cadence: .daily,
                title: tribeRepo("tribe.mock.challenge.curatedDailyCalm.title"),
                subtitle: tribeRepo("tribe.mock.challenge.curatedDailyCalm.subtitle"),
                metricType: .calmMinutes,
                targetValue: 60,
                progressValue: 34,
                endAt: now.addingTimeInterval(60 * 60 * 7),
                isCuratedGlobal: true,
                participantsCount: 121
            ),
            TribeChallenge(
                id: "curated-monthly-steps",
                scope: .galaxy,
                cadence: .monthly,
                title: tribeRepo("tribe.mock.challenge.curatedMonthlySteps.title"),
                subtitle: tribeRepo("tribe.mock.challenge.curatedMonthlySteps.subtitle"),
                metricType: .steps,
                targetValue: 250_000,
                progressValue: 93_500,
                endAt: now.addingTimeInterval(60 * 60 * 24 * 25),
                isCuratedGlobal: true,
                participantsCount: 287
            ),
            TribeChallenge(
                id: "curated-monthly-sleep",
                scope: .galaxy,
                cadence: .monthly,
                title: tribeRepo("tribe.mock.challenge.curatedMonthlySleep.title"),
                subtitle: tribeRepo("tribe.mock.challenge.curatedMonthlySleep.subtitle"),
                metricType: .sleep,
                targetValue: 40,
                progressValue: 18,
                endAt: now.addingTimeInterval(60 * 60 * 24 * 21),
                isCuratedGlobal: true,
                participantsCount: 164
            )
        ]
    }
}

struct SupabaseTribeRepository: TribeRepositoryProtocol {
    func loadSnapshot() async -> TribeRepositorySnapshot {
        await MockTribeRepository().loadSnapshot()
    }
}

struct SupabaseChallengeRepository: ChallengeRepositoryProtocol {
    func loadChallenges() async -> [TribeChallenge] {
        await MockChallengeRepository().loadChallenges()
    }

    func loadCuratedGalaxyChallenges() async -> [TribeChallenge] {
        await MockChallengeRepository().loadCuratedGalaxyChallenges()
    }
}

@MainActor
extension TribeStore {
    func loadFromRepository(_ repository: any TribeRepositoryProtocol) async {
        let snapshot = await repository.loadSnapshot()
        currentTribe = snapshot.tribe
        members = snapshot.members
        missions = snapshot.missions
        events = snapshot.events
        inviteCodeInput = snapshot.tribe?.inviteCode ?? ""
        error = nil
    }
}
