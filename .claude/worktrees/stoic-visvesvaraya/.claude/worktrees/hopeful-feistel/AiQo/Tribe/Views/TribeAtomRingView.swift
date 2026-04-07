import SwiftUI

struct TribeAtomRingView: View {
    let layers: [TribeAtomRingLayer]
    var size: CGFloat = 148

    private var hasSelection: Bool {
        layers.contains(where: \.isSelected)
    }

    private var animationTrigger: [String] {
        layers.map { "\($0.id)-\($0.isSelected)" }
    }

    var body: some View {
        ZStack {
            ForEach(layers) { layer in
                ringLayerImage(for: layer)
                    .zIndex(zIndex(for: layer))
            }
        }
        .frame(width: size, height: size)
        .shadow(
            color: TribeModernPalette.shadow.opacity(hasSelection ? 0.08 : 0.05),
            radius: size * 0.06,
            x: 0,
            y: size * 0.035
        )
        .animation(.spring(response: 0.36, dampingFraction: 0.84), value: animationTrigger)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private func ringLayerImage(for layer: TribeAtomRingLayer) -> some View {
        let isSelected = layer.isSelected
        let resolvedOpacity = hasSelection ? (isSelected ? 1.0 : 0.42) : 0.75
        let resolvedScale: CGFloat = hasSelection && isSelected ? 1.03 : 1.0
        let shadowRadius = hasSelection && isSelected ? 12.0 : 0.0

        Image(layer.ringAssetName)
            .resizable()
            .interpolation(.high)
            .antialiased(true)
            .scaledToFit()
            .frame(width: size, height: size)
            .opacity(resolvedOpacity)
            .scaleEffect(resolvedScale)
            .shadow(color: layer.accentColor.opacity(isSelected ? 0.42 : 0), radius: shadowRadius, x: 0, y: 0)
            .shadow(color: layer.accentColor.opacity(isSelected ? 0.20 : 0), radius: shadowRadius + 2, x: 0, y: 0)
            .overlay {
                if isSelected {
                    Image(layer.ringAssetName)
                        .resizable()
                        .interpolation(.high)
                        .antialiased(true)
                        .scaledToFit()
                        .frame(width: size, height: size)
                        .opacity(0.16)
                        .blur(radius: 2.5)
                        .blendMode(.plusLighter)
                }
            }
    }

    private func zIndex(for layer: TribeAtomRingLayer) -> Double {
        let baseIndex = Double(TribeSectorColor.atomVisualOrder.firstIndex(where: { $0.rawValue == layer.id }) ?? 0)
        return layer.isSelected ? 100 + baseIndex : baseIndex
    }

    private var accessibilityLabel: String {
        guard let selectedLayer = layers.first(where: \.isSelected) else {
            return "حلقة القبيلة بخمس طبقات"
        }

        return "حلقة القبيلة، \(selectedLayer.layerName) مضيئة للعضو \(selectedLayer.memberName)"
    }
}

#Preview {
    ZStack {
        TribeModernPalette.backgroundBase
            .ignoresSafeArea()

        TribeAtomRingView(
            layers: [
                TribeRingMember(
                    member: TribeMember(
                        id: "preview-01",
                        displayName: "ليان",
                        level: 19,
                        privacyMode: .public,
                        energyContributionToday: 82,
                        role: .owner
                    ),
                    sectorColor: .green,
                    isCurrentUser: false
                ),
                TribeRingMember(
                    member: TribeMember(
                        id: "preview-02",
                        displayName: "سكون",
                        level: 17,
                        privacyMode: .public,
                        energyContributionToday: 74,
                        role: .admin
                    ),
                    sectorColor: .yellow,
                    isCurrentUser: false
                ),
                TribeRingMember(
                    member: TribeMember(
                        id: "preview-03",
                        displayName: "أنت",
                        level: 16,
                        privacyMode: .public,
                        energyContributionToday: 68
                    ),
                    sectorColor: .blue,
                    isCurrentUser: true
                ),
                TribeRingMember(
                    member: TribeMember(
                        id: "preview-04",
                        displayName: "نور",
                        level: 15,
                        privacyMode: .public,
                        energyContributionToday: 49
                    ),
                    sectorColor: .red,
                    isCurrentUser: false
                ),
                TribeRingMember(
                    member: TribeMember(
                        id: "preview-05",
                        displayName: "رنا",
                        level: 14,
                        privacyMode: .public,
                        energyContributionToday: 41
                    ),
                    sectorColor: .purple,
                    isCurrentUser: false
                )
            ]
            .atomRingLayers(selectedMemberID: "preview-03"),
            size: 240
        )
        .padding(32)
    }
}
