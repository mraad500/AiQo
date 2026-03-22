// Supabase hook: replace `seedPreviewData()` with member/challenge fetches and map the
// API payload into `TribeMember`, `TribeChallenge`, and `ChallengeContribution`.
import Combine
import SwiftUI
import UIKit

@MainActor
final class GalaxyViewModel: ObservableObject {
    @Published private(set) var members: [TribeMember] = []
    @Published private(set) var nodes: [GalaxyNode] = []
    @Published private(set) var edges: [GalaxyEdge] = []
    @Published private(set) var contributions: [ChallengeContribution] = []
    @Published var selectedNodeId: String?
    @Published var toastMessage: String?
    @Published var sparkEvent: GalaxySparkEvent?
    @Published var dragOffset: CGSize = .zero
    @Published var cardMode: GalaxyCardMode
    @Published var connectionStyle: GalaxyConnectionStyle
    @Published var featuredChallenges: [TribeChallenge] = []
    @Published var activeChallengeId: String?
    @Published var simplifiedPreview = false

    let tribeName: String
    let sourceTitle = "المصدر"

    init(
        tribeName: String = "سكون",
        initialCardMode: GalaxyCardMode = .network,
        initialConnectionStyle: GalaxyConnectionStyle = .spokes
    ) {
        self.tribeName = tribeName
        self.cardMode = initialCardMode
        self.connectionStyle = initialConnectionStyle
        seedPreviewData()
    }

    var visibleNodes: [GalaxyNode] {
        let limit = simplifiedPreview ? 6 : 10
        return Array(nodes.prefix(limit))
    }

    var visibleEdges: [GalaxyEdge] {
        let visibleIDs = Set(visibleNodes.map(\.id))
        return edges.filter { visibleIDs.contains($0.fromId) && visibleIDs.contains($0.toId) }
    }

    var selectedNode: GalaxyNode? {
        visibleNodes.first(where: { $0.id == selectedNodeId }) ?? visibleNodes.first
    }

    var activeChallenge: TribeChallenge? {
        featuredChallenges.first(where: { $0.id == activeChallengeId }) ?? featuredChallenges.first
    }

    var highlightNodeIDs: Set<String> {
        guard let activeChallengeId else { return Set(visibleNodes.prefix(2).map(\.id)) }

        let ranked = contributions
            .filter { $0.challengeId == activeChallengeId }
            .sorted { $0.value > $1.value }
            .map(\.nodeId)

        if ranked.isEmpty {
            return Set(visibleNodes.prefix(2).map(\.id))
        }

        return Set(ranked.prefix(3))
    }

    var activeAccentHue: Double {
        activeChallenge?.goalType.accentHue ?? 0.60
    }

    func setCardMode(_ mode: GalaxyCardMode) {
        cardMode = mode
        impact(.soft)
    }

    func setConnectionStyle(_ style: GalaxyConnectionStyle) {
        connectionStyle = style
    }

    func select(node: GalaxyNode?) {
        guard let node else { return }
        selectedNodeId = node.id
        impact(.light)
    }

    func togglePreviewMode() {
        simplifiedPreview.toggle()
        if let selectedNodeId, !visibleNodes.contains(where: { $0.id == selectedNodeId }) {
            self.selectedNodeId = visibleNodes.first?.id
        }
        showToast(simplifiedPreview ? "تم تفعيل وضع العرض" : "تم توسيع العرض")
    }

    func activateChallenge(_ challenge: TribeChallenge) {
        activeChallengeId = challenge.id
        cardMode = .arena
        impact(.rigid)
    }

    func sendSparkFromSelected() {
        let sourceId = selectedNode?.id ?? visibleNodes.first?.id
        sparkEvent = GalaxySparkEvent(sourceNodeId: sourceId)
        impact(.medium)
        showToast("تم إرسال شرارة")
    }

    func contributeToChallenge(_ challenge: TribeChallenge) {
        guard let index = featuredChallenges.firstIndex(where: { $0.id == challenge.id }) else { return }

        featuredChallenges[index].progressValue = min(
            featuredChallenges[index].targetValue,
            featuredChallenges[index].progressValue + challenge.goalType.defaultIncrement
        )
        presentContribution(for: featuredChallenges[index])
    }

    func presentContribution(for challenge: TribeChallenge) {
        activeChallengeId = challenge.id

        let sourceId = selectedNode?.id ?? visibleNodes.first?.id
        sparkEvent = GalaxySparkEvent(sourceNodeId: sourceId)
        impact(.medium)
        showToast("تمت المساهمة")
    }

    func replaceChallenges(with challenges: [TribeChallenge]) {
        featuredChallenges = Array(challenges.prefix(4))
        if activeChallengeId == nil || !featuredChallenges.contains(where: { $0.id == activeChallengeId }) {
            activeChallengeId = featuredChallenges.first?.id
        }
    }

    func updateDragOffset(_ translation: CGSize) {
        dragOffset = clampedOffset(for: translation)
    }

    func resetDragOffset() {
        dragOffset = .zero
    }

    private func seedPreviewData() {
        members = Self.previewMembers()
        nodes = Self.layoutNodes(from: members)
        edges = Self.buildConstellationEdges(for: nodes)
        contributions = Self.previewContributions(for: members)
        featuredChallenges = Array(Self.previewChallenges().prefix(4))
        activeChallengeId = featuredChallenges.first?.id
        selectedNodeId = nodes.first?.id
    }

    private func showToast(_ message: String) {
        toastMessage = message

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            if self.toastMessage == message {
                self.toastMessage = nil
            }
        }
    }

    private func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    private func clampedOffset(for translation: CGSize) -> CGSize {
        let limit: CGFloat = 18
        return CGSize(
            width: min(max(translation.width, -limit), limit),
            height: min(max(translation.height, -limit), limit)
        )
    }
}

private extension GalaxyViewModel {
    static func previewMembers() -> [TribeMember] {
        [
            TribeMember(id: "member-source-1", displayName: "ليان", level: 18, privacyMode: .public, energyContributionToday: 24, initials: "لي", isLeader: true),
            TribeMember(id: "member-source-2", displayName: "سكون", level: 16, privacyMode: .public, energyContributionToday: 21, initials: "سك"),
            TribeMember(id: "member-source-3", displayName: "عضو خاص", level: 15, privacyMode: .private, energyContributionToday: 18, initials: "ره"),
            TribeMember(id: "member-source-4", displayName: "نور", level: 14, privacyMode: .public, energyContributionToday: 17, initials: "نو"),
            TribeMember(id: "member-source-5", displayName: "أمل", level: 13, privacyMode: .public, energyContributionToday: 15, initials: "أم"),
            TribeMember(id: "member-source-6", displayName: "عضو خاص", level: 12, privacyMode: .private, energyContributionToday: 13, initials: "غم"),
            TribeMember(id: "member-source-7", displayName: "صفا", level: 11, privacyMode: .public, energyContributionToday: 12, initials: "صف"),
            TribeMember(id: "member-source-8", displayName: "مدى", level: 10, privacyMode: .public, energyContributionToday: 10, initials: "مد"),
            TribeMember(id: "member-source-9", displayName: "عضو خاص", level: 9, privacyMode: .private, energyContributionToday: 8, initials: "هد"),
            TribeMember(id: "member-source-10", displayName: "وَجد", level: 8, privacyMode: .public, energyContributionToday: 7, initials: "وج")
        ]
    }

    static func previewChallenges(reference: Date = .now) -> [TribeChallenge] {
        [
            TribeChallenge(
                id: "daily-steps",
                scope: .tribe,
                cadence: .daily,
                title: "50,000 خطوة اليوم",
                subtitle: "دفعة قبليّة سريعة.",
                metricType: .steps,
                targetValue: 50_000,
                progressValue: 37_600,
                endAt: reference.addingTimeInterval(60 * 60 * 9),
                createdByUserId: "tribe",
                participantsCount: 8
            ),
            TribeChallenge(
                id: "daily-water",
                scope: .tribe,
                cadence: .daily,
                title: "ماء 40 كوب",
                subtitle: "ترطيب جماعي.",
                metricType: .water,
                targetValue: 40,
                progressValue: 28,
                endAt: reference.addingTimeInterval(60 * 60 * 7),
                createdByUserId: "tribe",
                participantsCount: 7,
                unitOverride: "كوب"
            ),
            TribeChallenge(
                id: "daily-sleep",
                scope: .galaxy,
                cadence: .daily,
                title: "نوم 40 ساعة",
                subtitle: "تحدٍ مجري مختار.",
                metricType: .sleep,
                targetValue: 40,
                progressValue: 26,
                endAt: reference.addingTimeInterval(60 * 60 * 13),
                createdByUserId: "AiQo",
                isCuratedGlobal: true,
                participantsCount: 64,
                unitOverride: "ساعة"
            ),
            TribeChallenge(
                id: "daily-calm",
                scope: .personal,
                cadence: .daily,
                title: "دقائق هدوء 60",
                subtitle: "هدوء شخصي قصير.",
                metricType: .calmMinutes,
                targetValue: 60,
                progressValue: 34,
                endAt: reference.addingTimeInterval(60 * 60 * 6),
                createdByUserId: "self",
                participantsCount: 1
            )
        ]
    }

    static func previewContributions(for members: [TribeMember]) -> [ChallengeContribution] {
        let dailyIDs = ["daily-steps", "daily-water", "daily-sleep", "daily-calm"]

        return members.enumerated().flatMap { index, member in
            dailyIDs.enumerated().compactMap { challengeIndex, challengeId in
                let value = max(1, (members.count - index) * (challengeIndex + 1))
                return ChallengeContribution(nodeId: member.id, challengeId: challengeId, value: value)
            }
        }
    }

    static func layoutNodes(from members: [TribeMember]) -> [GalaxyNode] {
        let orderedMembers = members
            .sorted {
                if $0.energyToday == $1.energyToday {
                    return $0.level > $1.level
                }
                return $0.energyToday > $1.energyToday
            }
            .prefix(10)

        let innerAngles = [-90.0, -5.0, 85.0, 175.0]
        let outerAngles = [-55.0, 5.0, 58.0, 122.0, 188.0, 242.0]
        let center = CGPoint(x: 0.5, y: 0.44)

        return orderedMembers.enumerated().map { index, member in
            let orbit = index < 4 ? 0 : 1
            let baseAngles = orbit == 0 ? innerAngles : outerAngles
            let baseAngle = baseAngles[(orbit == 0 ? index : index - 4) % baseAngles.count]
            let jitter = stableUnit(for: member.id, salt: orbit + 11) * 14.0 - 7.0
            let radius = orbit == 0 ? 0.20 : 0.31
            let angle = (baseAngle + jitter) * .pi / 180

            let x = min(max(center.x + CGFloat(cos(angle) * radius), 0.14), 0.86)
            let y = min(max(center.y + CGFloat(sin(angle) * radius), 0.12), 0.78)

            return GalaxyNode(
                id: member.id,
                member: member,
                rank: index + 1,
                orbit: orbit,
                normalizedPosition: CGPoint(x: x, y: y),
                hue: 0.56 + (Double(index % 4) * 0.03)
            )
        }
    }

    static func buildConstellationEdges(for nodes: [GalaxyNode]) -> [GalaxyEdge] {
        var seenPairs = Set<String>()
        var builtEdges: [GalaxyEdge] = []

        for node in nodes {
            let candidates = nodes
                .filter { $0.id != node.id }
                .sorted {
                    distance(from: node.normalizedPosition, to: $0.normalizedPosition) <
                    distance(from: node.normalizedPosition, to: $1.normalizedPosition)
                }
                .prefix(2)

            for candidate in candidates {
                let pair = [node.id, candidate.id].sorted().joined(separator: "::")
                guard seenPairs.insert(pair).inserted else { continue }

                let gap = distance(from: node.normalizedPosition, to: candidate.normalizedPosition)
                builtEdges.append(
                    GalaxyEdge(fromId: node.id, toId: candidate.id, weight: max(0.2, 1 - (gap * 2.6)))
                )
            }
        }

        return builtEdges
    }

    static func distance(from lhs: CGPoint, to rhs: CGPoint) -> Double {
        let dx = Double(lhs.x - rhs.x)
        let dy = Double(lhs.y - rhs.y)
        return sqrt((dx * dx) + (dy * dy))
    }

    static func stableUnit(for value: String, salt: Int) -> Double {
        let scalarSum = value.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let raw = (scalarSum * 131 + salt * 97) % 10_000
        return Double(raw) / 10_000
    }
}
