import SwiftUI

struct TribeRingView: View {
    let size: CGFloat
    let members: [TribeRingMember]
    let segmentTarget: Int
    let highlightedSector: TribeSectorColor?

    init(
        size: CGFloat = 150,
        members: [TribeRingMember],
        segmentTarget: Int,
        highlightedSector: TribeSectorColor? = nil
    ) {
        self.size = size
        self.members = members
        self.segmentTarget = max(segmentTarget, 1)
        self.highlightedSector = highlightedSector
    }

    private var membersBySector: [TribeSectorColor: TribeRingMember] {
        Dictionary(uniqueKeysWithValues: members.map { ($0.sectorColor, $0) })
    }

    var body: some View {
        ZStack {
            ForEach(TribeRingLayerLayout.layers) { layer in
                let progress = progress(for: layer.sectorColor)
                let isHighlighted = highlightedSector == nil || highlightedSector == layer.sectorColor

                ZStack {
                    Image(layer.assetName)
                        .resizable()
                        .interpolation(.high)
                        .antialiased(true)
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .scaleEffect(layer.scale)
                        .offset(layer.offset)
                        .clipped()
                        .opacity(layer.trackOpacity)

                    Image(layer.assetName)
                        .resizable()
                        .interpolation(.high)
                        .antialiased(true)
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .scaleEffect(layer.scale)
                        .offset(layer.offset)
                        .clipped()
                        .mask {
                            TribeRingSweepMask(
                                progress: progress,
                                startAngle: TribeRingLayerLayout.startAngle
                            )
                            .frame(width: size, height: size)
                        }
                        .opacity(progress > 0 ? 1 : 0)
                }
                .opacity(isHighlighted ? 1 : 0.42)
                .scaleEffect(isHighlighted ? 1 : 0.985)
                .zIndex(layer.zIndex)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: TribeModernPalette.shadow.opacity(0.05), radius: size * 0.045, x: 0, y: size * 0.035)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("حلقة القبيلة")
    }

    private func progress(for sectorColor: TribeSectorColor) -> Double {
        guard let member = membersBySector[sectorColor], member.isVacant == false else {
            return 0
        }

        return min(max(Double(member.energyToday) / Double(segmentTarget), 0), 1)
    }
}

private struct TribeRingLayerVisual: Identifiable {
    let sectorColor: TribeSectorColor
    let zIndex: Double
    let scale: CGFloat
    let offset: CGSize
    let trackOpacity: Double

    var id: TribeSectorColor { sectorColor }
    var assetName: String { sectorColor.assetName }
}

private enum TribeRingLayerLayout {
    static let startAngle = Angle.degrees(-90)

    static let layers: [TribeRingLayerVisual] = TribeSectorColor.ringVisualOrder.enumerated().map { index, sectorColor in
        TribeRingLayerVisual(
            sectorColor: sectorColor,
            zIndex: Double(index),
            scale: scale(for: sectorColor),
            offset: offset(for: sectorColor),
            trackOpacity: 0.18
        )
    }

    private static func scale(for sectorColor: TribeSectorColor) -> CGFloat {
        switch sectorColor {
        case .yellow:
            return 1
        case .purple:
            return 1
        case .blue:
            return 1
        case .green:
            return 1
        case .red:
            return 0.925
        }
    }

    private static func offset(for sectorColor: TribeSectorColor) -> CGSize {
        switch sectorColor {
        case .yellow, .purple, .blue, .green:
            return .zero
        case .red:
            return CGSize(width: 0, height: -8.5)
        }
    }
}

private struct TribeRingSweepMask: Shape {
    let progress: Double
    let startAngle: Angle

    func path(in rect: CGRect) -> Path {
        let clampedProgress = min(max(progress, 0), 1)
        guard clampedProgress > 0 else { return Path() }

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = max(rect.width, rect.height) * 0.72
        let endAngle = startAngle + .degrees(360 * clampedProgress)

        var path = Path()
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

#Preview {
    ZStack {
        TribeModernPalette.backgroundBase
            .ignoresSafeArea()

        TribeRingView(
            size: 220,
            members: [
                TribeRingMember(
                    member: TribeMember(
                        id: "preview-01",
                        displayName: "أنت",
                        level: 1,
                        privacyMode: .public,
                        energyContributionToday: 120
                    ),
                    sectorColor: .blue,
                    isCurrentUser: true
                ),
                TribeRingMember(
                    member: TribeMember(
                        id: "preview-02",
                        displayName: "ليان",
                        level: 19,
                        privacyMode: .public,
                        energyContributionToday: 46,
                        role: .owner
                    ),
                    sectorColor: .green,
                    isCurrentUser: false
                ),
                TribeRingMember(
                    member: TribeMember(
                        id: "preview-03",
                        displayName: "سكون",
                        level: 17,
                        privacyMode: .public,
                        energyContributionToday: 38,
                        role: .admin
                    ),
                    sectorColor: .yellow,
                    isCurrentUser: false
                ),
                TribeRingMember(
                    member: TribeMember(
                        id: "preview-04",
                        displayName: "أن",
                        level: 16,
                        privacyMode: .public,
                        energyContributionToday: 34
                    ),
                    sectorColor: .red,
                    isCurrentUser: false
                ),
                TribeRingMember(
                    member: TribeMember(
                        id: "preview-05",
                        displayName: "نور",
                        level: 14,
                        privacyMode: .public,
                        energyContributionToday: 29
                    ),
                    sectorColor: .purple,
                    isCurrentUser: false
                )
            ],
            segmentTarget: 120
        )
    }
}
