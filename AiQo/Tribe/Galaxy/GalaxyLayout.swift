// README: Replace the static layout seed in this file with backend-driven rank and
// contribution metadata when Supabase graph payloads are available.
import CoreGraphics
import Foundation

enum GalaxyLayout {
    static func makeNodes(from members: [TribeMember], limit: Int = 12) -> [GalaxyNode] {
        let rankedMembers = members
            .sorted { lhs, rhs in
                if lhs.auraEnergyToday == rhs.auraEnergyToday {
                    return lhs.level > rhs.level
                }
                return lhs.auraEnergyToday > rhs.auraEnergyToday
            }
            .prefix(limit)

        let innerAngles = [-94.0, -14.0, 64.0, 152.0]
        let outerAngles = [-58.0, -6.0, 42.0, 102.0, 162.0, 222.0, 276.0, 328.0]
        let center = CGPoint(x: 0.5, y: 0.42)

        var positions = rankedMembers.enumerated().map { index, member in
            let orbit = index < 4 ? 0 : 1
            let angleSet = orbit == 0 ? innerAngles : outerAngles
            let slotIndex = orbit == 0 ? index : index - 4
            let baseAngle = angleSet[slotIndex % angleSet.count]
            let angleJitter = (stableUnit(for: member.id, salt: slotIndex + 7) * 18) - 9
            let radius = orbit == 0 ? 0.22 : 0.34
            let angle = (baseAngle + angleJitter) * .pi / 180

            return CGPoint(
                x: center.x + CGFloat(cos(angle) * radius),
                y: center.y + CGFloat(sin(angle) * radius)
            )
        }

        resolveCollisions(in: &positions, around: center)

        return zip(Array(rankedMembers.enumerated()), positions).map { pair, position in
            let (index, member) = pair
            return GalaxyNode(
                id: member.id,
                member: member,
                rank: index + 1,
                orbit: index < 4 ? 0 : 1,
                normalizedPosition: position,
                hue: 0.54 + (Double((index + 1) % 5) * 0.03)
            )
        }
    }

    static func makeEdges(for nodes: [GalaxyNode], style: GalaxyLayoutStyle) -> [GalaxyEdge] {
        guard style == .network else { return [] }

        var seenPairs = Set<String>()
        var edges: [GalaxyEdge] = []

        for node in nodes {
            let neighbors = nodes
                .filter { $0.id != node.id }
                .sorted { lhs, rhs in
                    distance(from: node.normalizedPosition, to: lhs.normalizedPosition) <
                    distance(from: node.normalizedPosition, to: rhs.normalizedPosition)
                }
                .prefix(node.rank <= 3 ? 3 : 2)

            for neighbor in neighbors {
                let pair = [node.id, neighbor.id].sorted().joined(separator: "::")
                guard seenPairs.insert(pair).inserted else { continue }

                let gap = distance(from: node.normalizedPosition, to: neighbor.normalizedPosition)
                edges.append(
                    GalaxyEdge(
                        fromId: node.id,
                        toId: neighbor.id,
                        weight: max(0.24, 1 - (gap * 2.15))
                    )
                )
            }
        }

        return edges
    }

    private static func resolveCollisions(in positions: inout [CGPoint], around center: CGPoint) {
        guard positions.count > 1 else { return }

        let minimumGap: CGFloat = 0.105

        for _ in 0..<10 {
            for lhsIndex in positions.indices {
                for rhsIndex in positions.indices where rhsIndex > lhsIndex {
                    let dx = positions[rhsIndex].x - positions[lhsIndex].x
                    let dy = positions[rhsIndex].y - positions[lhsIndex].y
                    let distance = sqrt((dx * dx) + (dy * dy))

                    guard distance > 0, distance < minimumGap else { continue }

                    let overlap = (minimumGap - distance) * 0.5
                    let normalX = dx / distance
                    let normalY = dy / distance

                    positions[lhsIndex].x -= normalX * overlap
                    positions[lhsIndex].y -= normalY * overlap
                    positions[rhsIndex].x += normalX * overlap
                    positions[rhsIndex].y += normalY * overlap

                    positions[lhsIndex] = clamp(positions[lhsIndex], around: center)
                    positions[rhsIndex] = clamp(positions[rhsIndex], around: center)
                }
            }
        }
    }

    private static func clamp(_ point: CGPoint, around center: CGPoint) -> CGPoint {
        let vector = CGVector(dx: point.x - center.x, dy: point.y - center.y)
        let distance = sqrt((vector.dx * vector.dx) + (vector.dy * vector.dy))
        let maxDistance: CGFloat = 0.38
        let scale = distance > maxDistance && distance > 0 ? maxDistance / distance : 1

        let normalized = CGPoint(
            x: center.x + (vector.dx * scale),
            y: center.y + (vector.dy * scale)
        )

        return CGPoint(
            x: min(max(normalized.x, 0.12), 0.88),
            y: min(max(normalized.y, 0.10), 0.80)
        )
    }

    private static func stableUnit(for value: String, salt: Int) -> Double {
        let scalarSum = value.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let mixed = (scalarSum * 137 + salt * 97) % 10_000
        return Double(mixed) / 10_000
    }

    private static func distance(from lhs: CGPoint, to rhs: CGPoint) -> Double {
        let dx = Double(lhs.x - rhs.x)
        let dy = Double(lhs.y - rhs.y)
        return sqrt((dx * dx) + (dy * dy))
    }
}
