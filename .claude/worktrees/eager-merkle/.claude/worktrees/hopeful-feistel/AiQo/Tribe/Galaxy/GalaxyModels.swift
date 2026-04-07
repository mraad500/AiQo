// Supabase hook: replace the preview factories in this file with decoded network models
// once the Tribe endpoints are available.
import CoreGraphics
import Foundation

enum GalaxyConnectionStyle: String, CaseIterable, Identifiable {
    case spokes
    case constellation

    var id: String { rawValue }

    var title: String {
        switch self {
        case .spokes:
            return "مصدرية"
        case .constellation:
            return "ترابط"
        }
    }
}

struct GalaxyNode: Identifiable {
    let id: String
    let member: TribeMember
    let rank: Int
    let orbit: Int
    let normalizedPosition: CGPoint
    let hue: Double

    var title: String {
        member.privacyMode == .public ? member.displayName : "عضو"
    }

    var visibleEnergy: Int? {
        member.privacyMode == .public ? member.energyToday : nil
    }
}

struct GalaxyEdge: Identifiable, Equatable, Hashable {
    let fromId: String
    let toId: String
    let weight: Double

    var id: String { "\(fromId)-\(toId)" }
}

struct GalaxyLogEvent: Identifiable, Equatable {
    let id: String
    let iconName: String
    let title: String
    let detail: String
    let timestamp: Date
}

struct GalaxySparkEvent: Equatable {
    let id = UUID()
    let sourceNodeId: String?
}
