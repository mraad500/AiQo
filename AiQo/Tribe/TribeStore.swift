import Foundation
import Combine
import Supabase
import Auth

@MainActor
final class TribeStore: ObservableObject {
    static let shared = TribeStore()

    @Published var currentTribe: Tribe?
    @Published var members: [TribeMember] = []
    @Published var missions: [TribeMission] = []
    @Published var events: [TribeEvent] = []
    @Published var inviteCodeInput = ""
    @Published var loading = false
    @Published var error: String?

    private let supabaseService: SupabaseService
    private let accessManager: AccessManager
    private let dateProvider: () -> Date
    private let defaults: UserDefaults

    private init(
        dateProvider: @escaping () -> Date = Date.init,
        defaults: UserDefaults = .standard
    ) {
        self.supabaseService = SupabaseService.shared
        self.accessManager = AccessManager.shared
        self.dateProvider = dateProvider
        self.defaults = defaults
        restorePersistedState()
    }

    var actionMemberId: String {
        currentUserId
    }

    var canJoinTribe: Bool {
        accessManager.canAccessTribe
    }

    var currentPrivacyMode: PrivacyMode {
        UserProfileStore.shared.tribePrivacyMode
    }

    func createTribe(name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            error = "tribe.error.nameRequired".localized
            return
        }

        guard accessManager.canCreateTribe else {
            error = "tribe.error.familyRequired".localized
            return
        }

        loading = true
        defer { loading = false }

        error = nil

        let tribe = Tribe(
            id: UUID().uuidString,
            name: trimmedName,
            ownerUserId: currentUserId,
            inviteCode: generatedInviteCode(),
            createdAt: dateProvider()
        )

        currentTribe = tribe
        members = [makeCurrentMember(energyContribution: 120)]
        missions = demoMissions()
        events = demoEvents()
        persistLocalState()

        print("🪶 Created tribe \(tribe.name) using local stub data until Supabase tribe tables are ready.")
    }

    func joinTribe(inviteCode: String) {
        let trimmedCode = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmedCode.isEmpty else {
            error = "tribe.error.inviteRequired".localized
            return
        }

        guard accessManager.canAccessTribe else {
            error = "tribe.error.premiumRequired".localized
            return
        }

        loading = true
        defer { loading = false }

        error = nil

        currentTribe = Tribe(
            id: UUID().uuidString,
            name: String(
                format: "tribe.mock.joinedName".localized,
                locale: Locale.current,
                String(trimmedCode.prefix(4))
            ),
            ownerUserId: "demo-owner",
            inviteCode: trimmedCode,
            createdAt: dateProvider().addingTimeInterval(-18_000)
        )

        members = demoMembers(inviteCode: trimmedCode)
        syncCurrentMemberWithLatestProfile()
        missions = demoMissions()
        events = demoEvents()
        persistLocalState()

        print("🪶 Joined tribe with code \(trimmedCode) using local stub data. Supabase integration can replace this later.")
    }

    func leaveTribe() {
        loading = true
        defer { loading = false }

        error = nil
        currentTribe = nil
        members = []
        missions = []
        events = []
        persistLocalState()

        print("🪶 Left tribe and cleared local tribe state.")
    }

    func fetchTribe() {
        loading = true
        defer { loading = false }

        error = nil

        guard currentTribe != nil else {
            members = []
            missions = []
            events = []
            persistLocalState()
            return
        }

        fetchMembers()
        fetchMissions()
        if events.isEmpty {
            events = demoEvents()
            persistLocalState()
        }

        print("🪶 Refreshed tribe state using local store. Current Supabase user: \(currentUserId)")
    }

    func fetchMembers() {
        guard currentTribe != nil else {
            members = []
            return
        }

        if members.isEmpty {
            members = demoMembers(inviteCode: currentTribe?.inviteCode ?? generatedInviteCode())
        }

        syncCurrentMemberWithLatestProfile()
        persistLocalState()
    }

    func fetchMissions() {
        guard currentTribe != nil else {
            missions = []
            return
        }

        if missions.isEmpty {
            missions = demoMissions()
        }

        persistLocalState()
    }

    func updateMyPrivacy(mode: PrivacyMode) {
        error = nil

        guard let index = members.firstIndex(where: { $0.id == currentUserId }) else {
            return
        }

        members[index].privacyMode = mode
        members[index].displayName = currentDisplayName
        members[index].level = LevelStore.shared.level
        members[index].avatarURL = currentAvatarToken
        refreshEventDisplayNames()
        persistLocalState()

        print("🪶 Updated tribe privacy for current user to \(mode.rawValue).")
    }

    func addContribution(amount: Int, from memberId: String) {
        guard let memberIndex = members.firstIndex(where: { $0.id == memberId }) else { return }

        let wasShieldUnlocked = totalEnergy >= shieldTarget
        members[memberIndex].energyContributionToday += amount
        updateMissionProgressAfterContribution(amount: amount)

        let actorName = displayName(for: memberId)
        prependEvent(
            type: .contribution,
            actorId: memberId,
            actorDisplayName: actorName,
            message: localizedFormat("tribe.event.contribution", actorName, amount),
            value: amount
        )

        appendCompletionEventsIfNeeded(wasShieldUnlocked: wasShieldUnlocked)
        persistLocalState()
    }

    func sendSpark(to memberId: String) {
        guard memberId != currentUserId else { return }

        let wasShieldUnlocked = totalEnergy >= shieldTarget

        if let actorIndex = members.firstIndex(where: { $0.id == currentUserId }) {
            members[actorIndex].energyContributionToday += 2
        }

        updateMissionEnergyProgress()

        let actorName = displayName(for: currentUserId)
        let targetName = displayName(for: memberId)

        prependEvent(
            type: .spark,
            actorId: currentUserId,
            actorDisplayName: actorName,
            message: localizedFormat("tribe.event.sparkTo", actorName, targetName),
            value: 2
        )

        appendCompletionEventsIfNeeded(wasShieldUnlocked: wasShieldUnlocked)
        persistLocalState()
    }

    private var currentUserId: String {
        if let currentUser = supabaseService.client.auth.currentUser {
            return String(describing: currentUser.id)
        }

        return "local-demo-user"
    }

    private var currentDisplayName: String {
        let profile = UserProfileStore.shared.current
        if let username = profile.username?.trimmingCharacters(in: .whitespacesAndNewlines), !username.isEmpty {
            return username
        }
        return profile.name
    }

    private var currentAvatarToken: String? {
        UserProfileStore.shared.loadAvatar() == nil ? nil : "local-avatar"
    }

    private var totalEnergy: Int {
        members.reduce(0) { $0 + $1.energyContributionToday }
    }

    private var shieldTarget: Int {
        missions.first(where: { $0.id == "mission-energy" })?.targetValue ?? 500
    }

    private func makeCurrentMember(energyContribution: Int) -> TribeMember {
        TribeMember(
            id: currentUserId,
            displayName: currentDisplayName,
            avatarURL: currentAvatarToken,
            level: LevelStore.shared.level,
            privacyMode: UserProfileStore.shared.tribePrivacyMode,
            energyContributionToday: energyContribution
        )
    }

    private func syncCurrentMemberWithLatestProfile() {
        let energy = members.first(where: { $0.id == currentUserId })?.energyContributionToday ?? 120
        let currentMember = makeCurrentMember(energyContribution: energy)

        if let index = members.firstIndex(where: { $0.id == currentUserId }) {
            members[index] = currentMember
        } else {
            members.insert(currentMember, at: 0)
        }
    }

    private func demoMembers(inviteCode: String) -> [TribeMember] {
        [
            TribeMember(
                id: "demo-owner",
                displayName: "الكابتن حمّودي",
                avatarURL: "Hammoudi5",
                level: 18,
                privacyMode: .public,
                energyContributionToday: 185
            ),
            TribeMember(
                id: "demo-private",
                displayName: "tribe.mock.privateMember".localized,
                avatarURL: "Tribeicon",
                level: 12,
                privacyMode: .private,
                energyContributionToday: 140
            ),
            TribeMember(
                id: "demo-public",
                displayName: "مازن",
                avatarURL: nil,
                level: 9,
                privacyMode: .public,
                energyContributionToday: 96
            ),
            makeCurrentMember(energyContribution: max(80, inviteCode.count * 24))
        ]
    }

    private func demoMissions() -> [TribeMission] {
        let now = dateProvider()

        return [
            TribeMission(
                id: "mission-energy",
                title: "tribe.store.mission.energy".localized,
                targetValue: 500,
                progressValue: min(members.reduce(0) { $0 + $1.energyContributionToday }, 500),
                endsAt: Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
            ),
            TribeMission(
                id: "mission-checkin",
                title: "tribe.store.mission.checkin".localized,
                targetValue: 5,
                progressValue: min(members.count, 5),
                endsAt: Calendar.current.date(byAdding: .hour, value: 12, to: now) ?? now
            ),
            TribeMission(
                id: "mission-streak",
                title: "tribe.store.mission.streak".localized,
                targetValue: 8,
                progressValue: min(max(members.count + 1, 2), 8),
                endsAt: Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
            )
        ]
    }

    private func demoEvents() -> [TribeEvent] {
        [
            TribeEvent(
                id: UUID().uuidString,
                type: .join,
                actorId: currentTribe?.ownerUserId ?? "demo-owner",
                actorDisplayName: displayName(for: currentTribe?.ownerUserId ?? "demo-owner"),
                message: localizedFormat("tribe.event.created", displayName(for: currentTribe?.ownerUserId ?? "demo-owner")),
                value: nil,
                createdAt: dateProvider().addingTimeInterval(-60 * 60 * 4)
            ),
            TribeEvent(
                id: UUID().uuidString,
                type: .contribution,
                actorId: "demo-public",
                actorDisplayName: displayName(for: "demo-public"),
                message: localizedFormat("tribe.event.contribution", displayName(for: "demo-public"), 20),
                value: 20,
                createdAt: dateProvider().addingTimeInterval(-60 * 34)
            ),
            TribeEvent(
                id: UUID().uuidString,
                type: .spark,
                actorId: currentUserId,
                actorDisplayName: displayName(for: currentUserId),
                message: localizedFormat("tribe.event.sparkTo", displayName(for: currentUserId), displayName(for: "demo-public")),
                value: 2,
                createdAt: dateProvider().addingTimeInterval(-60 * 9)
            )
        ]
        .sorted { $0.createdAt > $1.createdAt }
    }

    private func restorePersistedState() {
        if let data = defaults.data(forKey: StorageKey.currentTribe),
           let tribe = try? JSONDecoder().decode(Tribe.self, from: data) {
            currentTribe = tribe
        }

        if let data = defaults.data(forKey: StorageKey.members),
           let storedMembers = try? JSONDecoder().decode([TribeMember].self, from: data) {
            members = storedMembers
        }

        if let data = defaults.data(forKey: StorageKey.missions),
           let storedMissions = try? JSONDecoder().decode([TribeMission].self, from: data) {
            missions = storedMissions
        }

        if let data = defaults.data(forKey: StorageKey.events),
           let storedEvents = try? JSONDecoder().decode([TribeEvent].self, from: data) {
            events = storedEvents
        }
    }

    private func persistLocalState() {
        if let currentTribe,
           let data = try? JSONEncoder().encode(currentTribe) {
            defaults.set(data, forKey: StorageKey.currentTribe)
        } else {
            defaults.removeObject(forKey: StorageKey.currentTribe)
        }

        if let data = try? JSONEncoder().encode(members) {
            defaults.set(data, forKey: StorageKey.members)
        } else {
            defaults.removeObject(forKey: StorageKey.members)
        }

        if let data = try? JSONEncoder().encode(missions) {
            defaults.set(data, forKey: StorageKey.missions)
        } else {
            defaults.removeObject(forKey: StorageKey.missions)
        }

        if let data = try? JSONEncoder().encode(events) {
            defaults.set(data, forKey: StorageKey.events)
        } else {
            defaults.removeObject(forKey: StorageKey.events)
        }
    }

    private func updateMissionProgressAfterContribution(amount: Int) {
        updateMissionEnergyProgress()

        if let index = missions.firstIndex(where: { $0.id == "mission-checkin" }) {
            missions[index].progressValue = min(missions[index].progressValue + 1, missions[index].targetValue)
        }

        if let index = missions.firstIndex(where: { $0.id == "mission-streak" }) {
            missions[index].progressValue = min(missions[index].progressValue + 1, missions[index].targetValue)
        }
    }

    private func updateMissionEnergyProgress() {
        if let index = missions.firstIndex(where: { $0.id == "mission-energy" }) {
            missions[index].progressValue = min(totalEnergy, missions[index].targetValue)
        }
    }

    private func appendCompletionEventsIfNeeded(wasShieldUnlocked: Bool) {
        if !wasShieldUnlocked, totalEnergy >= shieldTarget {
            prependEvent(
                type: .shieldUnlocked,
                actorId: "system",
                actorDisplayName: "tribe.system".localized,
                message: "tribe.event.shieldUnlocked".localized,
                value: nil
            )
        }

        if let mission = missions.first(where: { $0.progressValue >= $0.targetValue && $0.id != "mission-energy" }),
           !events.contains(where: { $0.type == .missionCompleted && $0.message.contains(mission.title) }) {
            prependEvent(
                type: .missionCompleted,
                actorId: "system",
                actorDisplayName: "tribe.system".localized,
                message: localizedFormat("tribe.event.missionCompleted", mission.title),
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
            createdAt: dateProvider()
        )

        events.insert(event, at: 0)
    }

    private func displayName(for memberId: String) -> String {
        guard let member = members.first(where: { $0.id == memberId }) else { return "tribe.member.anonymous".localized }
        return member.privacyMode == .public ? member.displayName : "tribe.member.anonymous".localized
    }

    private func refreshEventDisplayNames() {
        events = events.map { event in
            var updatedEvent = event
            if event.actorId != "system" {
                updatedEvent.actorDisplayName = displayName(for: event.actorId)
                switch event.type {
                case .contribution:
                    updatedEvent.message = localizedFormat("tribe.event.contribution", updatedEvent.actorDisplayName, event.value ?? 0)
                case .join:
                    updatedEvent.message = localizedFormat("tribe.event.created", updatedEvent.actorDisplayName)
                case .memberJoined:
                    updatedEvent.message = localizedFormat("tribe.event.memberJoined", updatedEvent.actorDisplayName)
                case .spark, .sparkSent:
                    updatedEvent.message = localizedFormat("tribe.event.spark", updatedEvent.actorDisplayName)
                case .challengeCompleted:
                    updatedEvent.message = localizedFormat("tribe.event.challengeCompleted", updatedEvent.actorDisplayName)
                case .leadChanged:
                    updatedEvent.message = localizedFormat("tribe.event.leadChanged", updatedEvent.actorDisplayName)
                case .challengeSuggested:
                    updatedEvent.message = localizedFormat("tribe.event.challengeSuggested", updatedEvent.actorDisplayName)
                case .shieldUnlocked, .missionCompleted:
                    break
                }
            }
            return updatedEvent
        }
    }

    private func localizedFormat(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: key.localized, locale: Locale.current, arguments: arguments)
    }

    private func generatedInviteCode() -> String {
        String(UUID().uuidString.prefix(6)).uppercased()
    }

    private enum StorageKey {
        static let currentTribe = "aiqo.tribe.current"
        static let members = "aiqo.tribe.members"
        static let missions = "aiqo.tribe.missions"
        static let events = "aiqo.tribe.events"
    }
}
