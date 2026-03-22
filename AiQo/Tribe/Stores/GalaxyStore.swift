// README: Keep this store as the single graph state owner. Later, map Supabase members,
// challenge highlights, and spark mutations here instead of mutating the view directly.
import SwiftUI
import UIKit
import Combine

@MainActor
final class GalaxyStore: ObservableObject {
    @Published private(set) var members: [TribeMember] = []
    @Published private(set) var nodes: [GalaxyNode] = []
    @Published private(set) var edges: [GalaxyEdge] = []
    @Published var selectedNodeId: String?
    @Published var layoutStyle: GalaxyLayoutStyle = .network
    @Published var dragOffset: CGSize = .zero
    @Published var zoomScale: CGFloat = 1
    @Published var toastMessage: String?
    @Published var sparkEvent: GalaxySparkEvent?

    var selectedNode: GalaxyNode? {
        nodes.first(where: { $0.id == selectedNodeId }) ?? nodes.first
    }

    var topNodes: [GalaxyNode] {
        Array(nodes.prefix(3))
    }

    func load(members: [TribeMember]) {
        self.members = Array(members.prefix(20))
        dragOffset = .zero
        zoomScale = 1
        toastMessage = nil
        sparkEvent = nil
        rebuildGraph()
    }

    func setLayoutStyle(_ style: GalaxyLayoutStyle) {
        guard layoutStyle != style else { return }
        layoutStyle = style
        rebuildGraph()
        impact(.soft)
    }

    func select(node: GalaxyNode) {
        selectedNodeId = node.id
        impact(.light)
    }

    func sendSpark() {
        sparkEvent = GalaxySparkEvent(sourceNodeId: selectedNodeId)
        impact(.medium)
        showToast("tribe.toast.sparkSent".localized)
    }

    func updatePan(_ translation: CGSize) {
        let limit: CGFloat = 34
        dragOffset = CGSize(
            width: min(max(translation.width, -limit), limit),
            height: min(max(translation.height, -limit), limit)
        )
    }

    func resetPan() {
        dragOffset = .zero
    }

    func updateZoom(_ scale: CGFloat) {
        zoomScale = min(max(scale, 0.90), 1.24)
    }

    func resetTransientStateIfNeeded() {
        if let selectedNodeId, nodes.contains(where: { $0.id == selectedNodeId }) == false {
            self.selectedNodeId = nodes.first?.id
        } else if selectedNodeId == nil {
            selectedNodeId = nodes.first?.id
        }
    }

    private func rebuildGraph() {
        nodes = GalaxyLayout.makeNodes(from: members)
        edges = GalaxyLayout.makeEdges(for: nodes, style: layoutStyle)
        resetTransientStateIfNeeded()
    }

    private func showToast(_ message: String) {
        toastMessage = message

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_300_000_000)
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
}
