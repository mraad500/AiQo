import Foundation

enum PrivacyMode: String, Codable, CaseIterable, Identifiable {
    case `private`
    case `public`

    var id: String { rawValue }

    var title: String {
        switch self {
        case .private:
            return "tribe.privacy.private".localized
        case .public:
            return "tribe.privacy.public".localized
        }
    }
}

enum TribeMemberRole: String, Codable, CaseIterable {
    case owner
    case admin
    case member
}

struct Tribe: Identifiable, Codable {
    let id: String
    var name: String
    var ownerUserId: String
    var inviteCode: String
    var createdAt: Date
}

struct TribeMember: Identifiable, Codable {
    let id: String
    var userId: String
    var displayName: String
    var displayNamePublic: String
    var displayNamePrivate: String
    var avatarURL: String?
    var level: Int
    var privacyMode: PrivacyMode
    var energyContributionToday: Int
    var initials: String?
    var isLeader: Bool
    var role: TribeMemberRole

    init(
        id: String,
        userId: String? = nil,
        displayName: String,
        displayNamePublic: String? = nil,
        displayNamePrivate: String? = nil,
        avatarURL: String? = nil,
        level: Int,
        privacyMode: PrivacyMode,
        energyContributionToday: Int,
        initials: String? = nil,
        isLeader: Bool = false,
        role: TribeMemberRole = .member
    ) {
        self.id = id
        self.userId = userId ?? id
        self.displayName = displayName
        self.displayNamePublic = displayNamePublic ?? displayName
        self.displayNamePrivate = displayNamePrivate ?? "tribe.member.anonymous".localized
        self.avatarURL = avatarURL
        self.level = level
        self.privacyMode = privacyMode
        self.energyContributionToday = energyContributionToday
        self.initials = initials
        self.isLeader = isLeader
        self.role = role
    }

    var energyToday: Int { energyContributionToday }
    var auraEnergyToday: Int { energyContributionToday }
    var visibility: PrivacyMode { privacyMode }
    var isPublicProfile: Bool { privacyMode == .public }

    var visibleDisplayName: String {
        privacyMode == .public ? displayNamePublic : displayNamePrivate
    }

    var resolvedInitials: String {
        if let initials, !initials.isEmpty {
            return initials
        }

        let source = privacyMode == .public ? displayNamePublic : displayNamePrivate
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "tribe.member.initialsFallback".localized }

        let words = trimmed.split(separator: " ").prefix(2)
        if words.count > 1 {
            return words.compactMap(\.first).map(String.init).joined()
        }

        return String(trimmed.prefix(2))
    }
}

struct TribeMission: Identifiable, Codable {
    let id: String
    var title: String
    var targetValue: Int
    var progressValue: Int
    var endsAt: Date
}

enum TribeEventType: String, Codable {
    case contribution
    case spark
    case join
    case shieldUnlocked
    case missionCompleted
    case memberJoined
    case sparkSent
    case challengeCompleted
    case leadChanged
    case challengeSuggested
}

struct TribeEvent: Identifiable, Codable {
    let id: String
    var type: TribeEventType
    var actorId: String
    var actorDisplayName: String
    var message: String
    var value: Int?
    var createdAt: Date
    var payload: [String: String]

    init(
        id: String,
        type: TribeEventType,
        actorId: String,
        actorDisplayName: String,
        message: String,
        value: Int? = nil,
        createdAt: Date,
        payload: [String: String] = [:]
    ) {
        self.id = id
        self.type = type
        self.actorId = actorId
        self.actorDisplayName = actorDisplayName
        self.message = message
        self.value = value
        self.createdAt = createdAt
        self.payload = payload
    }

    var timestamp: Date { createdAt }
}
