import Foundation
internal import Combine
import SwiftUI

@MainActor
final class TribeModuleViewModel: ObservableObject {
    @Published var selectedTab: TribeDashboardTab = .tribe
    @Published var arenaScopeFilter: ArenaScopeFilter = .everyone {
        didSet { applyArenaScopeFilter() }
    }
    @Published var globalTimeFilter: GlobalTimeFilter = .today {
        didSet { applyGlobalTimeFilter() }
    }
    @Published private(set) var isLoading = false
    @Published private(set) var heroSummary = TribeSummary(
        eyebrow: "نبض اليوم",
        title: "قبيلة الهدوء",
        summary: "إيقاع يومي هادئ يربط أعضاء القبيلة.",
        memberBadge: "0/5 أعضاء",
        progress: 0,
        progressValue: "0٪",
        progressLabel: "اكتمال اليوم",
        ringSegmentTarget: 100
    )
    @Published private(set) var tribeStats: [TribeStatMiniCardModel] = []
    @Published private(set) var featuredMembers: [TribeRingMember] = []
    @Published private(set) var arenaHeroSummary = ArenaHeroSummary(
        title: "أرينا اليوم",
        subtitle: "التحديات النشطة",
        activeCountText: "4 نشط"
    )
    @Published private(set) var arenaCompactChallenges: [ArenaCompactChallenge] = []
    @Published private(set) var arenaStats: [TribeStatMiniCardModel] = []
    @Published private(set) var arenaChallenges: [TribeChallenge] = []
    @Published private(set) var globalHeroTitle = "حضور عالمي هادئ"
    @Published private(set) var globalHeroSubtitle = "ترتيب يعكس الاستمرارية لا الضجيج."
    @Published private(set) var globalTopThree: [TribeGlobalRankEntry] = []
    @Published private(set) var globalRankings: [TribeGlobalRankEntry] = []
    @Published private(set) var currentUserGlobalEntry: TribeGlobalRankEntry?
    @Published private(set) var globalSelfRankSummary = GlobalSelfRankSummary(
        title: "ترتيبك العالمي #—",
        percentileText: "ضمن أعلى —",
        scoreText: "0 نقطة"
    )
    @Published private(set) var globalRankingRows: [GlobalRankingRowItem] = []

    private let allowsPreviewAccess: Bool
    private let tribeStore: TribeStore
    private let arenaStore: ArenaStore
    private let tribeRepository: any TribeRepositoryProtocol
    private let challengeRepository: any ChallengeRepositoryProtocol

    private var hasLoaded = false
    private var allArenaCompactChallenges = ArenaCompactChallenge.mockData
    private var baseGlobalEntries: [TribeGlobalRankEntry] = []

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

        self.featuredMembers = TribeSectorColor.memberDisplayOrder.enumerated().map { index, sectorColor in
            TribeRingMember(slot: index + 1, sectorColor: sectorColor)
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
        let tribeName = tribeStore.currentTribe?.name ?? "قبيلة AiQo"
        let energyMission = tribeStore.missions.first(where: { $0.id == "mission-energy" }) ?? tribeStore.missions.first
        let energyTarget = max(energyMission?.targetValue ?? max(totalEnergy, 1), 1)
        let energyProgress = min(Double(totalEnergy) / Double(energyTarget), 1)
        let primaryGoal = arenaStore.challenges.first(where: { $0.scope == .tribe && $0.status == .active }) ??
            arenaStore.challenges.first(where: { $0.status == .active })
        let displayedMembers = Array(sortedMembers.prefix(TribeSectorColor.memberDisplayOrder.count))
        let ringSegmentTarget = max(
            Int((Double(energyTarget) / Double(max(displayedMembers.count, 1))).rounded(.up)),
            1
        )

        heroSummary = TribeSummary(
            eyebrow: "نبض اليوم",
            title: tribeName,
            summary: "تم جمع \(totalEnergy.formatted(.number.grouping(.automatic))) نقطة اليوم عبر \(activeMembers.count.formatted(.number.grouping(.automatic))) أعضاء نشطين.",
            memberBadge: "\(displayedMembers.count)/5 أعضاء",
            progress: energyProgress,
            progressValue: "\(Int((energyProgress * 100).rounded()))٪",
            progressLabel: "اكتمال اليوم",
            ringSegmentTarget: ringSegmentTarget
        )

        tribeStats = [
            TribeStatMiniCardModel(
                id: "goal-type",
                title: "نوع الهدف",
                value: primaryGoal?.metricType.title ?? "خطوات",
                detail: primaryGoal?.subtitle.isEmpty == false ? primaryGoal?.subtitle ?? "" : "هدف هادئ يجمع القبيلة اليوم.",
                symbol: primaryGoal?.metricType.iconName ?? "figure.walk",
                accent: primaryGoal?.metricType.premiumAccent ?? TribeModernPalette.warm
            ),
            TribeStatMiniCardModel(
                id: "active-members",
                title: "الأعضاء النشطين",
                value: activeMembers.count.formatted(.number.grouping(.automatic)),
                detail: "من أصل \(sortedMembers.count.formatted(.number.grouping(.automatic))) أعضاء",
                symbol: "person.3.fill",
                accent: TribeModernPalette.sky
            ),
            TribeStatMiniCardModel(
                id: "team-energy",
                title: "طاقة اليوم",
                value: totalEnergy.formatted(.number.grouping(.automatic)),
                detail: "من أصل \(energyTarget.formatted(.number.grouping(.automatic))) هدف اليوم",
                symbol: "bolt.heart.fill",
                accent: TribeModernPalette.mint
            )
        ]

        featuredMembers = TribeSectorColor.memberDisplayOrder.enumerated().map { index, sectorColor in
            let member = index < sortedMembers.count ? sortedMembers[index] : nil
            guard let member else {
                return TribeRingMember(slot: index + 1, sectorColor: sectorColor)
            }

            return TribeRingMember(
                member: member,
                sectorColor: sectorColor,
                isCurrentUser: isCurrentUser(member: member)
            )
        }

        let activeChallenges = arenaStore.challenges
            .filter { $0.status == .active && $0.scope != .personal }
            .sorted(by: challengeSort(lhs:rhs:))

        arenaChallenges = activeChallenges
        allArenaCompactChallenges = ArenaCompactChallenge.mockData
        arenaHeroSummary = ArenaHeroSummary(
            title: "أرينا اليوم",
            subtitle: "التحديات النشطة",
            activeCountText: "\(allArenaCompactChallenges.count) نشط"
        )
        applyArenaScopeFilter()

        let participationTotal = activeChallenges.reduce(0) { $0 + $1.participantsCount }
        let averageCompletion = activeChallenges.isEmpty
            ? 0
            : Int((activeChallenges.reduce(0.0) { $0 + $1.progress } / Double(activeChallenges.count) * 100).rounded())

        arenaStats = [
            TribeStatMiniCardModel(
                id: "arena-active",
                title: "التحديات النشطة",
                value: activeChallenges.count.formatted(.number.grouping(.automatic)),
                detail: "بين القبيلة والمجتمع العالمي",
                symbol: "flag.2.crossed.fill",
                accent: TribeModernPalette.mint
            ),
            TribeStatMiniCardModel(
                id: "arena-participants",
                title: "إجمالي المشاركات",
                value: participationTotal.formatted(.number.grouping(.automatic)),
                detail: "حضور جماعي عبر جميع المسارات",
                symbol: "person.2.wave.2.fill",
                accent: TribeModernPalette.sky
            ),
            TribeStatMiniCardModel(
                id: "arena-completion",
                title: "متوسط الإنجاز",
                value: "\(averageCompletion)٪",
                detail: "يعكس التقدم الحالي للتحديات",
                symbol: "chart.line.uptrend.xyaxis",
                accent: TribeModernPalette.warm
            )
        ]

        baseGlobalEntries = buildGlobalRankings(from: sortedMembers)
        applyGlobalTimeFilter()
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

    private func applyArenaScopeFilter() {
        switch arenaScopeFilter {
        case .tribes:
            arenaCompactChallenges = allArenaCompactChallenges.filter { $0.scope == .tribes }
        case .everyone:
            arenaCompactChallenges = allArenaCompactChallenges
        }
    }

    private func applyGlobalTimeFilter() {
        let rankedEntries = buildFilteredGlobalEntries()
        globalTopThree = Array(rankedEntries.prefix(3))
        globalRankings = Array(rankedEntries.dropFirst(3))
        currentUserGlobalEntry = rankedEntries.first(where: \.isCurrentUser)
        globalRankingRows = rankedEntries.prefix(18).map { entry in
            GlobalRankingRowItem(
                id: entry.id,
                rank: entry.rank,
                name: entry.name,
                caption: entry.caption,
                scoreText: entry.formattedScore,
                accent: entry.accent,
                trend: trend(for: entry),
                isCurrentUser: entry.isCurrentUser
            )
        }

        if let currentUserGlobalEntry {
            let visiblePopulation = max(rankedEntries.count * 12, currentUserGlobalEntry.rank + 1)
            let bestPercent = max(
                1,
                Int(
                    (Double(currentUserGlobalEntry.rank) / Double(visiblePopulation) * 100).rounded()
                )
            )

            globalSelfRankSummary = GlobalSelfRankSummary(
                title: "ترتيبك العالمي #\(currentUserGlobalEntry.rank.formatted(.number.grouping(.automatic)))",
                percentileText: "ضمن أعلى \(bestPercent)٪",
                scoreText: "\(currentUserGlobalEntry.formattedScore) نقطة"
            )
            globalHeroTitle = "ترتيبك العالمي"
            globalHeroSubtitle = "هدوء ثابت بين نخبة الأرينا."
        } else {
            globalSelfRankSummary = GlobalSelfRankSummary(
                title: "ترتيبك العالمي #—",
                percentileText: "ضمن أعلى —",
                scoreText: "0 نقطة"
            )
            globalHeroTitle = "لوحة الترتيب العالمية"
            globalHeroSubtitle = "حضور هادئ بين أفضل الأداءات."
        }
    }

    private func buildFilteredGlobalEntries() -> [TribeGlobalRankEntry] {
        let scoredEntries = baseGlobalEntries.map { entry in
            (entry: entry, score: transformedScore(for: entry, filter: globalTimeFilter))
        }

        return scoredEntries
            .sorted {
                if $0.score == $1.score {
                    return $0.entry.streakDays > $1.entry.streakDays
                }

                return $0.score > $1.score
            }
            .enumerated()
            .map { index, item in
                TribeGlobalRankEntry(
                    id: item.entry.id,
                    memberId: item.entry.memberId,
                    rank: index + 1,
                    name: item.entry.name,
                    caption: item.entry.caption,
                    score: item.score,
                    streakDays: item.entry.streakDays,
                    accent: item.entry.accent,
                    isCurrentUser: item.entry.isCurrentUser,
                    isTribeMember: item.entry.isTribeMember
                )
            }
    }

    private func transformedScore(for entry: TribeGlobalRankEntry, filter: GlobalTimeFilter) -> Int {
        let seed = abs(entry.id.hashValue)
        let smallVariance = seed % 170

        switch filter {
        case .today:
            return entry.score + (smallVariance / 3)
        case .sevenDays:
            return Int(Double(entry.score) * 2.9) + (entry.streakDays * 55) + smallVariance + (entry.isTribeMember ? 80 : 0)
        case .thirtyDays:
            return Int(Double(entry.score) * 6.8) + (entry.streakDays * 140) + (smallVariance * 2) + (entry.isCurrentUser ? 180 : 0)
        }
    }

    private func trend(for entry: TribeGlobalRankEntry) -> GlobalRankingTrend {
        guard let baseRank = baseGlobalEntries.first(where: { $0.id == entry.id })?.rank else {
            return .stable
        }

        if entry.rank < baseRank {
            return .up
        }

        if entry.rank > baseRank {
            return .down
        }

        return .stable
    }

    private func buildGlobalRankings(from members: [TribeMember]) -> [TribeGlobalRankEntry] {
        let tribeAccentMap = Dictionary(
            uniqueKeysWithValues: featuredMembers.compactMap { featured in
                featured.memberId.map { ($0, featured.sectorColor.accent) }
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
                accent: tribeAccentMap[member.id] ?? TribeModernPalette.mint,
                isCurrentUser: isCurrentUser(member: member),
                isTribeMember: true
            )
        }

        let seededEntries = buildSeededGlobalEntries()

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

    private func buildSeededGlobalEntries() -> [TribeGlobalRankEntry] {
        let names = [
            "سما", "تالا", "ريان", "Mila", "آدم", "نوف", "Lina", "يوسف", "سِدن", "Layal",
            "هالة", "Rami", "Jade", "ريم", "Noah", "Leen", "Nora", "Omar", "Luca", "سدن"
        ]
        let captions = [
            "دبي", "الدوحة", "الرياض", "سنغافورة", "لندن", "الكويت", "برشلونة", "أبوظبي", "جدة", "باريس"
        ]
        let accents = [
            Color(hex: "E4C88A"),
            Color(hex: "A4C2E8"),
            Color(hex: "C6A6F8"),
            Color(hex: "88DFF4"),
            Color(hex: "F0C46D"),
            Color(hex: "7ED8CC"),
            Color(hex: "C1D6F5"),
            Color(hex: "E0B79A")
        ]

        return (0..<160).map { index in
            let baseScore = max(2_180, 7_400 - (index * 27))
            let streak = max(6, 34 - (index % 23))

            return TribeGlobalRankEntry(
                id: "global-seed-\(index)",
                memberId: nil,
                rank: 0,
                name: names[index % names.count],
                caption: captions[index % captions.count],
                score: baseScore,
                streakDays: streak,
                accent: accents[index % accents.count],
                isCurrentUser: false,
                isTribeMember: false
            )
        }
    }
}
