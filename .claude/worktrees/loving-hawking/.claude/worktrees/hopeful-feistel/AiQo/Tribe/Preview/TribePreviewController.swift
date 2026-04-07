import Foundation
internal import Combine

@MainActor
final class TribePreviewController: ObservableObject {
    static let shared = TribePreviewController()

    enum PreviewState: String, CaseIterable, Identifiable {
        case visitor
        case member
        case owner

        var id: String { rawValue }

        var title: String {
            switch self {
            case .visitor:
                return "زائر"
            case .member:
                return "عضو"
            case .owner:
                return "قائد"
            }
        }
    }

    @Published var state: PreviewState
    @Published var tribe: Tribe?
    @Published var members: [TribeMember]
    @Published var missions: [TribeMission]
    @Published var events: [TribeEvent]
    @Published var energyProgress: (current: Int, target: Int)

    static let forcePreviewKey = "aiqo.tribe.preview.forceEnabled"

    static var isPreviewEnabled: Bool {
#if DEBUG
        true
#else
        UserDefaults.standard.bool(forKey: forcePreviewKey)
#endif
    }

    static var canShowModeSwitcher: Bool {
#if DEBUG
        true
#else
        UserDefaults.standard.bool(forKey: forcePreviewKey)
#endif
    }

    var canCreateTribe: Bool {
        state == .owner
    }

    var showsOwnerBadge: Bool {
        state == .owner
    }

    var actionMemberId: String {
        currentUserId
    }

    var currentUserPrivacyMode: PrivacyMode {
        get {
            members.first(where: { $0.id == currentUserId })?.privacyMode ?? .private
        }
        set {
            guard let index = members.firstIndex(where: { $0.id == currentUserId }) else { return }
            members[index].privacyMode = newValue
        }
    }

    private let currentUserId = "preview-self"
    private let ownerUserId = "preview-owner"

    private init() {
        self.state = .member
        self.tribe = nil
        self.members = []
        self.missions = []
        self.events = []
        self.energyProgress = TribePreviewData.sampleEnergyProgress()
        apply(state: .member)
    }

    func apply(state: PreviewState) {
        self.state = state
        energyProgress = TribePreviewData.sampleEnergyProgress()

        switch state {
        case .visitor:
            tribe = nil
            members = TribePreviewData.sampleMembers(
                currentUserId: currentUserId,
                currentUserName: "أنت",
                currentUserPrivacy: .private,
                ownerUserId: ownerUserId,
                ownerDisplayName: "القائد"
            )
            missions = TribePreviewData.sampleMissions(energyProgress: energyProgress)
            events = TribePreviewData.sampleEvents(members: members, ownerUserId: ownerUserId)
        case .member:
            tribe = TribePreviewData.sampleTribe(ownerUserId: ownerUserId)
            members = TribePreviewData.sampleMembers(
                currentUserId: currentUserId,
                currentUserName: "أنت",
                currentUserPrivacy: .private,
                ownerUserId: ownerUserId,
                ownerDisplayName: "القائد"
            )
            missions = TribePreviewData.sampleMissions(energyProgress: energyProgress)
            events = TribePreviewData.sampleEvents(members: members, ownerUserId: ownerUserId)
        case .owner:
            tribe = TribePreviewData.sampleTribe(ownerUserId: currentUserId)
            members = TribePreviewData.sampleMembers(
                currentUserId: currentUserId,
                currentUserName: "أنت",
                currentUserPrivacy: .public,
                ownerUserId: currentUserId,
                ownerDisplayName: "أنت"
            )
            missions = TribePreviewData.sampleMissions(energyProgress: energyProgress)
            events = TribePreviewData.sampleEvents(members: members, ownerUserId: currentUserId)
        }
    }

    func joinPreviewTribe() {
        apply(state: .member)
    }

    func createPreviewTribe(named name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            apply(state: .owner)
            return
        }

        apply(state: .owner)
        if var updatedTribe = tribe {
            updatedTribe.name = trimmedName
            tribe = updatedTribe
        }
    }

    func updateMyPrivacy(mode: PrivacyMode) {
        currentUserPrivacyMode = mode
        refreshEventDisplayNames()
    }

    func addContribution(amount: Int, from memberId: String) {
        guard let memberIndex = members.firstIndex(where: { $0.id == memberId }) else { return }

        let wasShieldUnlocked = energyProgress.current >= energyProgress.target
        members[memberIndex].energyContributionToday += amount
        energyProgress.current += amount

        incrementMissionProgress(id: "preview-energy", by: amount, usesValueAsProgress: true)
        incrementMissionProgress(id: "preview-checkin", by: 1)
        incrementMissionProgress(id: "preview-streak", by: 1)

        let actorName = displayName(for: memberId)
        prependEvent(
            type: .contribution,
            actorId: memberId,
            actorDisplayName: actorName,
            message: "\(actorName) ساهم +\(amount) طاقة",
            value: amount
        )

        appendCompletionEventsIfNeeded(wasShieldUnlocked: wasShieldUnlocked)
    }

    func sendSpark(to memberId: String) {
        guard memberId != actionMemberId else { return }
        let actorName = displayName(for: actionMemberId)
        let targetName = displayName(for: memberId)

        applyEnergyIncrease(2, to: actionMemberId)

        prependEvent(
            type: .spark,
            actorId: actionMemberId,
            actorDisplayName: actorName,
            message: "\(actorName) أرسل شرارة إلى \(targetName)",
            value: 2
        )
    }

    private func applyEnergyIncrease(_ amount: Int, to memberId: String) {
        guard let memberIndex = members.firstIndex(where: { $0.id == memberId }) else { return }

        let wasShieldUnlocked = energyProgress.current >= energyProgress.target
        members[memberIndex].energyContributionToday += amount
        energyProgress.current += amount
        incrementMissionProgress(id: "preview-energy", by: amount, usesValueAsProgress: true)
        appendCompletionEventsIfNeeded(wasShieldUnlocked: wasShieldUnlocked)
    }

    private func incrementMissionProgress(id: String, by amount: Int, usesValueAsProgress: Bool = false) {
        guard let missionIndex = missions.firstIndex(where: { $0.id == id }) else { return }
        let previousValue = missions[missionIndex].progressValue

        if usesValueAsProgress {
            missions[missionIndex].progressValue = min(energyProgress.current, missions[missionIndex].targetValue)
        } else {
            missions[missionIndex].progressValue = min(previousValue + amount, missions[missionIndex].targetValue)
        }
    }

    private func appendCompletionEventsIfNeeded(wasShieldUnlocked: Bool) {
        if !wasShieldUnlocked, energyProgress.current >= energyProgress.target {
            prependEvent(
                type: .shieldUnlocked,
                actorId: "system",
                actorDisplayName: "النظام",
                message: "تم فتح الدرع ✅",
                value: nil
            )
        }

        if let mission = missions.first(where: { $0.progressValue >= $0.targetValue && $0.id != "preview-energy" }),
           !events.contains(where: { $0.type == .missionCompleted && $0.message.contains(mission.title) }) {
            prependEvent(
                type: .missionCompleted,
                actorId: "system",
                actorDisplayName: "النظام",
                message: "اكتملت مهمة: \(mission.title)",
                value: nil
            )
        }
    }

    private func prependEvent(
        type: TribeEventType,
        actorId: String,
        actorDisplayName: String,
        message: String,
        value: Int?
    ) {
        let event = TribeEvent(
            id: UUID().uuidString,
            type: type,
            actorId: actorId,
            actorDisplayName: actorDisplayName,
            message: message,
            value: value,
            createdAt: Date()
        )

        events.insert(event, at: 0)
    }

    private func displayName(for memberId: String) -> String {
        guard let member = members.first(where: { $0.id == memberId }) else { return "عضو" }
        return member.privacyMode == .public ? member.displayName : "عضو"
    }

    private func refreshEventDisplayNames() {
        events = events.map { event in
            var updatedEvent = event
            if event.actorId != "system" {
                updatedEvent.actorDisplayName = displayName(for: event.actorId)
                switch event.type {
                case .contribution:
                    updatedEvent.message = "\(updatedEvent.actorDisplayName) ساهم +\(event.value ?? 0) طاقة"
                case .join:
                    updatedEvent.message = "\(updatedEvent.actorDisplayName) أنشأ القبيلة"
                case .memberJoined:
                    updatedEvent.message = "\(updatedEvent.actorDisplayName) انضم إلى القبيلة"
                case .spark, .sparkSent:
                    updatedEvent.message = "\(updatedEvent.actorDisplayName) أرسل شرارة"
                case .challengeCompleted:
                    updatedEvent.message = "\(updatedEvent.actorDisplayName) أكمل تحدياً"
                case .leadChanged:
                    updatedEvent.message = "\(updatedEvent.actorDisplayName) تصدّر الترتيب"
                case .challengeSuggested:
                    updatedEvent.message = "\(updatedEvent.actorDisplayName) اقترح تحدياً للمجرة"
                case .shieldUnlocked, .missionCompleted:
                    break
                }
            }
            return updatedEvent
        }
    }
}
