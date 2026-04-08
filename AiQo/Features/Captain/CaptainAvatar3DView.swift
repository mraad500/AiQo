//
//  CaptainAvatar3DView.swift
//  AiQo
//
//  3D Avatar using RealityKit - replaces the 2D captain image
//

import SwiftUI
import RealityKit

struct CaptainAvatar3DView: View {
    @State private var anchor = AnchorEntity()

    var body: some View {
        TimelineView(.animation) { timeline in
            avatar3DContent(time: timeline.date.timeIntervalSinceReferenceDate)
        }
        .allowsHitTesting(false)
    }

    private func avatar3DContent(time: TimeInterval) -> some View {
        RealityView { content in
            await loadModel(into: content)
        } update: { content in
            applyIdleAnimation(in: content, time: time)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @MainActor
    private func loadModel(into content: some RealityViewContentProtocol) async {
        let entity: Entity
        if let loaded = try? await Entity.load(named: "my") {
            entity = loaded
        } else if let url = Bundle.main.url(forResource: "my", withExtension: "usdz"),
                  let loaded = try? await Entity.load(contentsOf: url) {
            entity = loaded
        } else {
            return
        }

        // Scale and position
        let bounds = entity.visualBounds(relativeTo: nil)
        let maxDim = max(bounds.extents.x, bounds.extents.y, bounds.extents.z)
        let s: Float = 0.35 / maxDim
        entity.scale = SIMD3<Float>(repeating: s)

        let c = bounds.center
        entity.position = SIMD3<Float>(-c.x * s, -c.y * s + 0.02, -c.z * s)
        entity.name = "captainFace"

        anchor.addChild(entity)

        // Key light
        let keyLight = DirectionalLight()
        keyLight.light.intensity = 1000
        keyLight.light.color = .white
        keyLight.look(at: .zero, from: SIMD3<Float>(0.5, 0.8, 1.0), relativeTo: nil)
        anchor.addChild(keyLight)

        // Fill light
        let fillLight = DirectionalLight()
        fillLight.light.intensity = 500
        fillLight.light.color = UIColor(white: 0.9, alpha: 1.0)
        fillLight.look(at: .zero, from: SIMD3<Float>(-0.5, 0.3, 0.8), relativeTo: nil)
        anchor.addChild(fillLight)

        content.add(anchor)
    }

    private func applyIdleAnimation(in content: some RealityViewContentProtocol, time: TimeInterval) {
        guard let face = anchor.children.first(where: { $0.name == "captainFace" }) else { return }

        let breathY: Float = Float(sin(time * 0.7)) * 0.003 + 0.02
        let rotY: Float = Float(sin(time * 0.5)) * 0.04

        face.position.y = breathY
        face.orientation = simd_quatf(angle: rotY, axis: SIMD3<Float>(0, 1, 0))
    }
}
