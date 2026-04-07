// Supabase hook: keep this view purely presentational and feed it with remote members,
// challenge highlights, and spark events from `GalaxyViewModel`.
import SwiftUI

@MainActor
struct ConstellationCanvasView: View {
    @ObservedObject var viewModel: GalaxyViewModel

    @State private var sparkProgress: CGFloat = 0
    @State private var activeSpark: GalaxySparkEvent?

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let center = point(
                for: CGPoint(x: 0.5, y: 0.40),
                in: size,
                offset: viewModel.dragOffset
            )
            let nodePoints = Dictionary(
                uniqueKeysWithValues: viewModel.visibleNodes.map {
                    ($0.id, point(for: $0.normalizedPosition, in: size, offset: viewModel.dragOffset))
                }
            )

            ZStack {
                Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: true) { context, _ in
                    drawAmbient(in: &context, size: size)
                    drawOrbits(in: &context, center: center, size: size)

                    switch viewModel.connectionStyle {
                    case .spokes:
                        drawSpokes(in: &context, center: center, points: nodePoints)
                    case .constellation:
                        drawEdges(in: &context, points: nodePoints)
                    }

                    drawCenter(in: &context, center: center)
                    drawNodes(in: &context, points: nodePoints)
                    drawSpark(in: &context, center: center, points: nodePoints, size: size)
                }
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .contentShape(Rectangle())
                .gesture(dragGesture)

                ForEach(viewModel.visibleNodes) { node in
                    if let point = nodePoints[node.id] {
                        nodeHitTarget(for: node)
                            .position(point)
                    }
                }
            }
            .onChange(of: viewModel.sparkEvent?.id) {
                triggerSpark()
            }
        }
        .frame(height: 350)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                viewModel.updateDragOffset(value.translation)
            }
            .onEnded { _ in
                withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                    viewModel.resetDragOffset()
                }
            }
    }

    private func nodeHitTarget(for node: GalaxyNode) -> some View {
        Color.clear
            .frame(width: 60, height: 60)
            .contentShape(Circle())
            .onTapGesture {
                viewModel.select(node: node)
            }
            .onLongPressGesture(minimumDuration: 0.35) {
                viewModel.select(node: node)
                viewModel.sendSparkFromSelected()
            }
            .accessibilityElement()
            .accessibilityLabel(accessibilityLabel(for: node))
            .accessibilityAddTraits(.isButton)
    }

    private func accessibilityLabel(for node: GalaxyNode) -> String {
        let energyText = node.visibleEnergy.map { "، طاقة \($0)" } ?? ""
        return "\(node.title)، المستوى \(node.member.level)\(energyText)"
    }

    private func point(for normalized: CGPoint, in size: CGSize, offset: CGSize) -> CGPoint {
        CGPoint(
            x: (normalized.x * size.width) + offset.width,
            y: (normalized.y * size.height) + offset.height
        )
    }

    private func drawAmbient(in context: inout GraphicsContext, size: CGSize) {
        let haze = CGRect(x: size.width * 0.18, y: 18, width: size.width * 0.64, height: size.height * 0.46)
        let lowGlow = CGRect(x: size.width * 0.16, y: size.height * 0.42, width: size.width * 0.52, height: size.height * 0.34)

        context.fill(
            Path(ellipseIn: haze),
            with: .radialGradient(
                Gradient(colors: [
                    Color(red: 0.26, green: 0.36, blue: 0.56).opacity(0.14),
                    .clear
                ]),
                center: CGPoint(x: haze.midX, y: haze.midY),
                startRadius: 8,
                endRadius: haze.width * 0.5
            )
        )

        context.fill(
            Path(ellipseIn: lowGlow),
            with: .radialGradient(
                Gradient(colors: [
                    Color(red: 0.20, green: 0.28, blue: 0.44).opacity(0.08),
                    .clear
                ]),
                center: CGPoint(x: lowGlow.midX, y: lowGlow.midY),
                startRadius: 8,
                endRadius: lowGlow.width * 0.44
            )
        )

        for index in 0..<18 {
            let x = CGFloat((index * 37) % 100) / 100
            let y = CGFloat((index * 19 + 11) % 100) / 100
            let rect = CGRect(
                x: x * size.width,
                y: y * size.height,
                width: index.isMultiple(of: 4) ? 2.2 : 1.4,
                height: index.isMultiple(of: 4) ? 2.2 : 1.4
            )
            context.fill(
                Path(ellipseIn: rect),
                with: .color(Color.white.opacity(index.isMultiple(of: 3) ? 0.14 : 0.08))
            )
        }
    }

    private func drawOrbits(in context: inout GraphicsContext, center: CGPoint, size: CGSize) {
        let radii = [
            min(size.width, size.height) * 0.18,
            min(size.width, size.height) * 0.28,
            min(size.width, size.height) * 0.38
        ]

        for radius in radii {
            let rect = CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            )

            context.stroke(
                Path(ellipseIn: rect),
                with: .color(Color.white.opacity(0.045)),
                style: StrokeStyle(lineWidth: 0.8, dash: [1.5, 8], dashPhase: radius * 0.22)
            )
        }
    }

    private func drawSpokes(
        in context: inout GraphicsContext,
        center: CGPoint,
        points: [String: CGPoint]
    ) {
        for node in viewModel.visibleNodes {
            guard let point = points[node.id] else { continue }

            let emphasized = viewModel.highlightNodeIDs.contains(node.id) && viewModel.cardMode == .arena
            let opacity = emphasized ? 0.16 : 0.07

            var path = Path()
            path.move(to: point)
            path.addLine(to: center)

            context.stroke(
                path,
                with: .linearGradient(
                    Gradient(colors: [
                        Color.white.opacity(opacity * 0.6),
                        Color(hue: node.hue, saturation: 0.30, brightness: 0.96).opacity(opacity)
                    ]),
                    startPoint: point,
                    endPoint: center
                ),
                style: StrokeStyle(lineWidth: emphasized ? 1.1 : 0.7, lineCap: .round)
            )
        }
    }

    private func drawEdges(
        in context: inout GraphicsContext,
        points: [String: CGPoint]
    ) {
        for edge in viewModel.visibleEdges {
            guard let from = points[edge.fromId], let to = points[edge.toId] else { continue }

            let emphasized = viewModel.highlightNodeIDs.contains(edge.fromId) || viewModel.highlightNodeIDs.contains(edge.toId)
            let alpha = emphasized && viewModel.cardMode == .arena ? 0.14 : 0.05

            var path = Path()
            path.move(to: from)
            path.addLine(to: to)

            context.stroke(
                path,
                with: .color(Color.white.opacity(alpha)),
                style: StrokeStyle(lineWidth: 0.6 + (edge.weight * 0.6), lineCap: .round)
            )
        }
    }

    private func drawCenter(in context: inout GraphicsContext, center: CGPoint) {
        let accent = Color(hue: viewModel.activeAccentHue, saturation: 0.34, brightness: 0.96)
        let outer = CGRect(x: center.x - 58, y: center.y - 58, width: 116, height: 116)
        let middle = CGRect(x: center.x - 34, y: center.y - 34, width: 68, height: 68)
        let inner = CGRect(x: center.x - 20, y: center.y - 20, width: 40, height: 40)

        context.fill(
            Path(ellipseIn: outer),
            with: .radialGradient(
                Gradient(colors: [
                    accent.opacity(viewModel.cardMode == .arena ? 0.24 : 0.18),
                    accent.opacity(0.04),
                    .clear
                ]),
                center: center,
                startRadius: 6,
                endRadius: 58
            )
        )

        context.fill(
            Path(ellipseIn: middle),
            with: .linearGradient(
                Gradient(colors: [
                    Color.white.opacity(0.20),
                    accent.opacity(0.14),
                    Color.white.opacity(0.04)
                ]),
                startPoint: CGPoint(x: middle.minX, y: middle.minY),
                endPoint: CGPoint(x: middle.maxX, y: middle.maxY)
            )
        )

        context.stroke(
            Path(ellipseIn: middle),
            with: .color(Color.white.opacity(0.12)),
            style: StrokeStyle(lineWidth: 1)
        )

        context.fill(
            Path(ellipseIn: inner),
            with: .radialGradient(
                Gradient(colors: [
                    Color.white.opacity(0.96),
                    Color(red: 0.78, green: 0.88, blue: 0.98).opacity(0.82),
                    accent.opacity(0.30)
                ]),
                center: center,
                startRadius: 2,
                endRadius: 24
            )
        )

        var label = context.resolve(
            Text(viewModel.sourceTitle)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
        )
        label.shading = .color(.white.opacity(0.76))
        context.draw(label, at: CGPoint(x: center.x, y: center.y + 46), anchor: .center)
    }

    private func drawNodes(
        in context: inout GraphicsContext,
        points: [String: CGPoint]
    ) {
        for node in viewModel.visibleNodes {
            guard let point = points[node.id] else { continue }

            let isSelected = node.id == viewModel.selectedNodeId
            let isHighlighted = viewModel.highlightNodeIDs.contains(node.id)
            let radius: CGFloat = node.rank <= 2 ? 20 : 17
            let glowSize = radius * 2 + (isSelected ? 22 : isHighlighted ? 18 : 12)
            let glowRect = CGRect(
                x: point.x - (glowSize / 2),
                y: point.y - (glowSize / 2),
                width: glowSize,
                height: glowSize
            )
            let nodeRect = CGRect(
                x: point.x - radius,
                y: point.y - radius,
                width: radius * 2,
                height: radius * 2
            )
            let glowStrength = max(0.12, min(0.30, CGFloat(node.member.energyToday) / 100))
            let haloColor = Color(hue: node.hue, saturation: 0.28, brightness: 0.96)

            context.fill(
                Path(ellipseIn: glowRect),
                with: .radialGradient(
                    Gradient(colors: [
                        haloColor.opacity((isSelected ? 0.30 : glowStrength) + (isHighlighted ? 0.05 : 0)),
                        haloColor.opacity(0.03),
                        .clear
                    ]),
                    center: point,
                    startRadius: 4,
                    endRadius: glowSize * 0.5
                )
            )

            context.fill(
                Path(ellipseIn: nodeRect),
                with: .linearGradient(
                    Gradient(colors: [
                        Color.white.opacity(isSelected ? 0.18 : 0.12),
                        Color.white.opacity(0.05),
                        Color.black.opacity(0.03)
                    ]),
                    startPoint: CGPoint(x: nodeRect.minX, y: nodeRect.minY),
                    endPoint: CGPoint(x: nodeRect.maxX, y: nodeRect.maxY)
                )
            )

            context.stroke(
                Path(ellipseIn: nodeRect),
                with: .color(Color.white.opacity(isSelected ? 0.18 : 0.08)),
                style: StrokeStyle(lineWidth: 0.9)
            )

            if node.member.privacyMode == .public {
                var text = context.resolve(
                    Text(node.member.resolvedInitials)
                        .font(.system(size: radius * 0.72, weight: .bold, design: .rounded))
                )
                text.shading = .color(.white.opacity(0.92))
                context.draw(text, at: point, anchor: .center)
            } else {
                var image = context.resolve(Image(systemName: "person.fill"))
                image.shading = .color(.white.opacity(0.84))
                context.draw(
                    image,
                    in: CGRect(
                        x: point.x - radius * 0.52,
                        y: point.y - radius * 0.56,
                        width: radius * 1.04,
                        height: radius * 1.04
                    )
                )
            }

            if node.rank <= 2 {
                drawRankBadge(for: node, at: point, in: &context)
            }
        }
    }

    private func drawRankBadge(for node: GalaxyNode, at point: CGPoint, in context: inout GraphicsContext) {
        let rect = CGRect(x: point.x + 9, y: point.y - 20, width: 18, height: 18)
        let tint = node.rank == 1 ? Color(red: 0.82, green: 0.70, blue: 0.44) : Color.white.opacity(0.86)

        context.fill(
            Path(ellipseIn: rect),
            with: .linearGradient(
                Gradient(colors: [
                    tint.opacity(0.18),
                    Color.white.opacity(0.08)
                ]),
                startPoint: CGPoint(x: rect.minX, y: rect.minY),
                endPoint: CGPoint(x: rect.maxX, y: rect.maxY)
            )
        )

        context.stroke(
            Path(ellipseIn: rect),
            with: .color(Color.white.opacity(0.10)),
            style: StrokeStyle(lineWidth: 0.8)
        )

        var text = context.resolve(
            Text("\(node.rank)")
                .font(.system(size: 9, weight: .bold, design: .rounded))
        )
        text.shading = .color(.white.opacity(0.94))
        context.draw(text, at: CGPoint(x: rect.midX, y: rect.midY), anchor: .center)
    }

    private func drawSpark(
        in context: inout GraphicsContext,
        center: CGPoint,
        points: [String: CGPoint],
        size: CGSize
    ) {
        guard let activeSpark else { return }

        let start = activeSpark.sourceNodeId.flatMap { points[$0] } ??
            CGPoint(x: size.width * 0.5, y: size.height - 26)

        let current = sparkPoint(from: start, to: center, progress: sparkProgress)
        let trail = CGRect(x: current.x - 4, y: current.y - 4, width: 8, height: 8)

        var path = Path()
        path.move(to: start)
        path.addLine(to: current)

        context.stroke(
            path,
            with: .color(Color.white.opacity(0.12)),
            style: StrokeStyle(lineWidth: 1.2, lineCap: .round)
        )

        context.fill(
            Path(ellipseIn: CGRect(x: current.x - 12, y: current.y - 12, width: 24, height: 24)),
            with: .radialGradient(
                Gradient(colors: [
                    Color.white.opacity(0.32),
                    .clear
                ]),
                center: current,
                startRadius: 2,
                endRadius: 12
            )
        )

        context.fill(Path(ellipseIn: trail), with: .color(Color.white.opacity(0.92)))
    }

    private func sparkPoint(from start: CGPoint, to end: CGPoint, progress: CGFloat) -> CGPoint {
        let arc = sin(progress * .pi) * 24

        return CGPoint(
            x: start.x + ((end.x - start.x) * progress),
            y: start.y + ((end.y - start.y) * progress) - arc
        )
    }

    private func triggerSpark() {
        guard let event = viewModel.sparkEvent else { return }

        activeSpark = event
        sparkProgress = 0

        withAnimation(.easeInOut(duration: 0.8)) {
            sparkProgress = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.82) {
            activeSpark = nil
            sparkProgress = 0
        }
    }
}
