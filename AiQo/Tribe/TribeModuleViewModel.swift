import Foundation
internal import Combine
import SwiftUI

@MainActor
final class TribeModuleViewModel: ObservableObject {
    @Published var selectedTab: TribeDashboardTab = .tribe
    @Published private(set) var isLoading = false
    @Published private(set) var heroSummary = TribeHeroSummary(
        title: "القبيلة",
        subtitle: "إيقاع يومي هادئ يربط أعضاء القبيلة.",
        progress: 0,
        centerValue: "0٪",
        centerLabel: "اكتمال اليوم"
    )
    @Published private(set) var tribeStats: [TribeStatCardModel] = []
    @Published private(set) var featuredMembers: [TribeFeaturedMember] = []
    @Published private(set) var arenaStats: [TribeStatCardModel] = []
    @Published private(set) var arenaChallenges: [TribeChallenge] = []
    @Published private(set) var globalHeroTitle = "حضور عالمي هادئ"
    @Published private(set) var globalHeroSubtitle = "ترتيب يعكس الاستمرارية لا الضجيج."
    @Published private(set) var globalTopThree: [TribeGlobalRankEntry] = []
    @Published private(set) var globalRankings: [TribeGlobalRankEntry] = []
    @Published private(set) var currentUserGlobalEntry: TribeGlobalRankEntry?

    private let allowsPreviewAccess: Bool
    private let tribeStore: TribeStore
    private let arenaStore: ArenaStore
    private let tribeRepository: any TribeRepositoryProtocol
    private let challengeRepository: any ChallengeRepositoryProtocol

    private var hasLoaded = false

    init(
        allowsPreviewAccess: Bool = false,
        tribeStore: TribeStore? = nil,
        tribeRepository: (any TribeRepositoryProtocol)? = nil,
        challengeRepository: (any ChallengeRepositoryProtocol)? = nil
    ) {
        self.allowsPreviewAccess = allowsPreviewAccess
        self.tribeStore = tribeStore ?? .shared

        let resolvedChallengeRepository = challengeRepository ?? TribeRepositoryFactory.makeChallengeRepository()
        self.challengeRepository = resolvedChallengeRepository
        self.arenaStore = ArenaStore(repository: resolvedChallengeRepository)
        self.tribeRepository = tribeRepository ?? TribeRepositoryFactory.makeTribeRepository()

        self.featuredMembers = TribeRingSegmentToken.ringOrder.enumerated().map { index, segment in
            TribeFeaturedMember(slot: index + 1, segment: segment, member: nil, isCurrentUser: false)
        }
    }

    func loadIfNeeded() async {
        guard hasLoaded == false else { return }
        hasLoaded = true
        await refresh()
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        if shouldBootstrapRepositoryData {
            await tribeStore.loadFromRepository(tribeRepository)
        } else {
            tribeStore.fetchTribe()
        }

        await arenaStore.load(using: challengeRepository)
        rebuildPresentation()
    }

    private var shouldBootstrapRepositoryData: Bool {
        allowsPreviewAccess ||
            tribeStore.currentTribe == nil ||
            tribeStore.members.isEmpty ||
            tribeStore.missions.isEmpty
    }

    private func rebuildPresentation() {
        let sortedMembers = tribeStore.members.sorted { lhs, rhs in
            if lhs.energyToday == rhs.energyToday {
                return lhs.level > rhs.level
            }

            return lhs.energyToday > rhs.energyToday
        }

        let totalEnergy = sortedMembers.reduce(0) { $0 + $1.energyToday }
        let activeMembers = sortedMembers.filter { $0.energyToday > 0 }
        let energyMission = tribeStore.missions.first(where: { $0.id == "mission-energy" }) ?? tribeStore.missions.first
        let energyTarget = max(energyMission?.targetValue ?? max(totalEnergy, 1), 1)
        let energyProgress = min(Double(totalEnergy) / Double(energyTarget), 1)
        let primaryGoal = arenaStore.challenges.first(where: { $0.scope == .tribe && $0.status == .active }) ??
            arenaStore.challenges.first(where: { $0.status == .active })

        heroSummary = TribeHeroSummary(
            title: tribeStore.currentTribe?.name ?? "قبيلة AiQo",
            subtitle: "تم جمع \(totalEnergy.formatted(.number.grouping(.automatic))) نقطة اليوم عبر \(activeMembers.count.formatted(.number.grouping(.automatic))) أعضاء نشطين.",
            progress: energyProgress,
            centerValue: "\(Int((energyProgress * 100).rounded()))٪",
            centerLabel: "اكتمال اليوم"
        )

        tribeStats = [
            TribeStatCardModel(
                id: "team-energy",
                title: "طاقة الفريق",
                value: totalEnergy.formatted(.number.grouping(.automatic)),
                detail: "من أصل \(energyTarget.formatted(.number.grouping(.automatic))) هدف اليوم",
                symbol: "bolt.heart.fill",
                accent: TribeModernPalette.mint
            ),
            TribeStatCardModel(
                id: "active-members",
                title: "الأعضاء النشطون",
                value: activeMembers.count.formatted(.number.grouping(.automatic)),
                detail: "من أصل \(sortedMembers.count.formatted(.number.grouping(.automatic))) أعضاء",
                symbol: "person.3.sequence.fill",
                accent: TribeModernPalette.sky
            ),
            TribeStatCardModel(
                id: "goal-type",
                title: "نوع الهدف",
                value: primaryGoal?.metricType.title ?? "حضور يومي",
                detail: primaryGoal?.subtitle.isEmpty == false ? primaryGoal?.subtitle ?? "" : "المحور الأوضح لطاقة القبيلة الآن.",
                symbol: "scope",
                accent: primaryGoal?.metricType.premiumAccent ?? TribeModernPalette.warm
            )
        ]

        featuredMembers = TribeRingSegmentToken.ringOrder.enumerated().map { index, segment in
            let member = index < sortedMembers.count ? sortedMembers[index] : nil
            return TribeFeaturedMember(
                slot: index + 1,
                segment: segment,
                member: member,
                isCurrentUser: member.map(isCurrentUser(member:)) ?? false
            )
        }

        let activeChallenges = arenaStore.challenges
            .filter { $0.status == .active && $0.scope != .personal }
            .sorted(by: challengeSort(lhs:rhs:))

        arenaChallenges = activeChallenges

        let participationTotal = activeChallenges.reduce(0) { $0 + $1.participantsCount }
        let averageCompletion = activeChallenges.isEmpty
            ? 0
            : Int((activeChallenges.reduce(0.0) { $0 + $1.progress } / Double(activeChallenges.count) * 100).rounded())

        arenaStats = [
            TribeStatCardModel(
                id: "arena-active",
                title: "التحديات النشطة",
                value: activeChallenges.count.formatted(.number.grouping(.automatic)),
                detail: "بين القبيلة والمجتمع العالمي",
                symbol: "flag.2.crossed.fill",
                accent: TribeModernPalette.mint
            ),
            TribeStatCardModel(
                id: "arena-participants",
                title: "إجمالي المشاركات",
                value: participationTotal.formatted(.number.grouping(.automatic)),
                detail: "حضور جماعي عبر جميع المسارات",
                symbol: "person.2.wave.2.fill",
                accent: TribeModernPalette.sky
            ),
            TribeStatCardModel(
                id: "arena-completion",
                title: "متوسط الإنجاز",
                value: "\(averageCompletion)٪",
                detail: "يعكس التقدم الحالي للتحديات",
                symbol: "chart.line.uptrend.xyaxis",
                accent: TribeModernPalette.warm
            )
        ]

        let rankEntries = buildGlobalRankings(from: sortedMembers)
        globalTopThree = Array(rankEntries.prefix(3))
        globalRankings = Array(rankEntries.dropFirst(3))
        currentUserGlobalEntry = rankEntries.first(where: \.isCurrentUser)

        if let currentUserGlobalEntry {
            let totalEntries = rankEntries.count
            let bestPercent = max(
                1,
                Int(
                    (Double(totalEntries - currentUserGlobalEntry.rank + 1) / Double(max(totalEntries, 1)) * 100).rounded()
                )
            )

            globalHeroTitle = "ترتيبك العالمي هذا الأسبوع"
            globalHeroSubtitle = "أنت ضمن أفضل \(bestPercent)٪، في المركز \(currentUserGlobalEntry.rank.formatted(.number.grouping(.automatic))) بسلسلة \(currentUserGlobalEntry.streakDays.formatted(.number.grouping(.automatic))) يوم."
        } else {
            globalHeroTitle = "لوحة القبائل العالمية"
            globalHeroSubtitle = "حضور متوازن يبرز الثبات، التعافي، وجودة الإيقاع داخل مجتمع AiQo."
        }
    }

    private func isCurrentUser(member: TribeMember) -> Bool {
        member.id == tribeStore.actionMemberId ||
            member.userId == tribeStore.actionMemberId ||
            member.displayName == "tribe.mock.selfName".localized ||
            member.displayNamePublic == "tribe.mock.selfName".localized
    }

    private func challengeSort(lhs: TribeChallenge, rhs: TribeChallenge) -> Bool {
        let lhsScope = challengePriority(for: lhs.scope)
        let rhsScope = challengePriority(for: rhs.scope)

        if lhsScope == rhsScope {
            if lhs.progress == rhs.progress {
                return lhs.endAt < rhs.endAt
            }
            return lhs.progress > rhs.progress
        }

        return lhsScope < rhsScope
    }

    private func challengePriority(for scope: ChallengeScope) -> Int {
        switch scope {
        case .tribe:
            return 0
        case .galaxy:
            return 1
        case .personal:
            return 2
        }
    }

    private func buildGlobalRankings(from members: [TribeMember]) -> [TribeGlobalRankEntry] {
        let tribeAccentMap = Dictionary(
            uniqueKeysWithValues: featuredMembers.compactMap { featured in
                featured.member.map { ($0.id, featured.segment.accent) }
            }
        )

        let tribeName = tribeStore.currentTribe?.name ?? "قبيلة AiQo"

        let memberEntries = members.map { member in
            let score = (member.energyToday * 26) + (member.level * 40) + (member.isLeader ? 55 : 0)

            return TribeGlobalRankEntry(
                id: "global-member-\(member.id)",
                memberId: member.id,
                rank: 0,
                name: member.visibleDisplayName,
                caption: tribeName,
                score: score,
                streakDays: max(4, member.level + (member.energyToday / 6)),
                accent: tribeAccentMap[member.id] ?? TribeModernPalette.sky,
                isCurrentUser: isCurrentUser(member: member),
                isTribeMember: true
            )
        }

        let seededEntries = [
            ("سما", "دبي", 3_420, 29, Color(hex: "E4C88A")),
            ("تالا", "الدوحة", 3_250, 27, Color(hex: "A4C2E8")),
            ("ريان", "الرياض", 3_120, 25, Color(hex: "C6A6F8")),
            ("Mila", "سنغافورة", 3_040, 24, Color(hex: "88DFF4")),
            ("آدم", "لندن", 2_980, 22, Color(hex: "F0C46D")),
            ("نوف", "الكويت", 2_930, 21, Color(hex: "7ED8CC")),
            ("Lina", "برشلونة", 2_860, 19, Color(hex: "C1D6F5")),
            ("يوسف", "أبوظبي", 2_790, 18, Color(hex: "E0B79A"))
        ].enumerated().map { index, item in
            TribeGlobalRankEntry(
                id: "global-seed-\(index)",
                memberId: nil,
                rank: 0,
                name: item.0,
                caption: item.1,
                score: item.2,
                streakDays: item.3,
                accent: item.4,
                isCurrentUser: false,
                isTribeMember: false
            )
        }

        return (memberEntries + seededEntries)
            .sorted {
                if $0.score == $1.score {
                    return $0.streakDays > $1.streakDays
                }

                return $0.score > $1.score
            }
            .enumerated()
            .map { index, entry in
                TribeGlobalRankEntry(
                    id: entry.id,
                    memberId: entry.memberId,
                    rank: index + 1,
                    name: entry.name,
                    caption: entry.caption,
                    score: entry.score,
                    streakDays: entry.streakDays,
                    accent: entry.accent,
                    isCurrentUser: entry.isCurrentUser,
                    isTribeMember: entry.isTribeMember
                )
            }
    }
}
