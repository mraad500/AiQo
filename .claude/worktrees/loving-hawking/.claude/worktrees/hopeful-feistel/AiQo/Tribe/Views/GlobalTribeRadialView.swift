import SwiftUI

struct GlobalTribeRadialView: View {
    let nodeCount: Int

    @State private var nodes: [RadialSoulNode] = []
    @State private var activePulse: PulseEvent?

    private var clampedNodeCount: Int {
        min(max(nodeCount, 10), 15)
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("المجرة")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))

                    Text("شبكة روحية حيّة تتنفس ببطء، وكل الروابط تعود للمصدر.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                GeometryReader { geometry in
                    let size = geometry.size
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let resolvedNodes = nodes.map { node in
                        ResolvedSoulNode(
                            node: node,
                            point: node.point(in: size, time: time),
                            shimmer: node.shimmer(at: time)
                        )
                    }
                    let pulse = resolvedPulse(at: timeline.date, nodes: resolvedNodes, center: center)

                    ZStack {
                        GlassHaloPane(time: time)
                        AmbientNebulaView(size: size, time: time)

                        GalaxyNetworkCanvas(
                            time: time,
                            center: center,
                            nodes: resolvedNodes,
                            pulse: pulse
                        )

                        LivingCoreView(
                            time: time,
                            pulseImpact: pulse?.impact ?? 0
                        )
                        .position(center)
                    }
                    .frame(width: size.width, height: size.height)
                    .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                    .drawingGroup(opaque: false, colorMode: .linear)
                }
                .frame(height: 420)
            }
        }
        .task(id: clampedNodeCount) {
            await prepareScene()
            await runPulseLoop()
        }
    }

    @MainActor
    private func prepareScene() async {
        nodes = Self.makeNodes(count: clampedNodeCount)
        activePulse = nil
    }

    @MainActor
    private func runPulseLoop() async {
        while !Task.isCancelled {
            let idleDelay = UInt64(Double.random(in: 1.8 ... 3.9) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: idleDelay)

            guard !Task.isCancelled else { break }

            let pulse = triggerPulse()
            guard pulse != nil else { continue }

            try? await Task.sleep(nanoseconds: 2_350_000_000)

            if activePulse == pulse {
                activePulse = nil
            }
        }
    }

    @MainActor
    private func triggerPulse() -> PulseEvent? {
        guard let source = nodes.randomElement() else { return nil }

        let pulse = PulseEvent(nodeID: source.id, startedAt: Date())
        activePulse = pulse
        return pulse
    }

    private func resolvedPulse(
        at date: Date,
        nodes: [ResolvedSoulNode],
        center: CGPoint
    ) -> RenderedPulse? {
        guard let activePulse else { return nil }
        guard let source = nodes.first(where: { $0.node.id == activePulse.nodeID }) else {
            return nil
        }

        let elapsed = date.timeIntervalSince(activePulse.startedAt)
        guard elapsed >= 0, elapsed <= activePulse.duration else {
            return nil
        }

        let rawProgress = min(max(elapsed / activePulse.duration, 0), 1)
        let easedProgress = 1 - pow(1 - rawProgress, 2.25)
        let point = interpolatedPoint(
            from: source.point,
            to: center,
            progress: easedProgress
        )
        let impact = coreImpact(for: rawProgress)

        return RenderedPulse(
            point: point,
            progress: rawProgress,
            impact: impact
        )
    }

    private func coreImpact(for progress: Double) -> Double {
        let highlightWindow = max(0, 1 - abs(progress - 0.92) / 0.16)
        return pow(highlightWindow, 1.6)
    }

    private func interpolatedPoint(
        from start: CGPoint,
        to end: CGPoint,
        progress: Double
    ) -> CGPoint {
        let clamped = CGFloat(min(max(progress, 0), 1))
        return CGPoint(
            x: start.x + (end.x - start.x) * clamped,
            y: start.y + (end.y - start.y) * clamped
        )
    }

    private static func makeNodes(count: Int) -> [RadialSoulNode] {
        (0 ..< count).map { index in
            let baseAngle = (Double(index) / Double(count)) * .pi * 2
            let angle = baseAngle + Double.random(in: -0.24 ... 0.24)

            return RadialSoulNode(
                angle: angle,
                radiusFactor: Double.random(in: 0.30 ... 0.44),
                diameter: CGFloat.random(in: 6 ... 11),
                driftAmplitude: CGFloat.random(in: 8 ... 16),
                driftSpeed: Double.random(in: 0.10 ... 0.22),
                driftPhase: Double.random(in: 0 ... (.pi * 2)),
                secondaryPhase: Double.random(in: 0 ... (.pi * 2)),
                threadPhase: Double.random(in: 0 ... (.pi * 2)),
                luminosity: Double.random(in: 0.68 ... 0.94)
            )
        }
    }
}

private struct GlassHaloPane: View {
    let time: TimeInterval

    private let mint = Color(red: 0.78, green: 0.97, blue: 0.91)

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 34, style: .continuous)
        let startPoint = UnitPoint(
            x: CGFloat(0.18 + (sin(time * 0.11) * 0.05)),
            y: CGFloat(0.14 + (cos(time * 0.09) * 0.05))
        )
        let endPoint = UnitPoint(
            x: CGFloat(0.82 + (cos(time * 0.12) * 0.04)),
            y: CGFloat(0.86 + (sin(time * 0.10) * 0.04))
        )

        shape
            .fill(.ultraThinMaterial)
            .overlay {
                shape.fill(Color.white.opacity(0.02))
            }
            .overlay {
                shape
                    .strokeBorder(
                        RadialGradient(
                            colors: [
                                mint.opacity(0.28),
                                Color.white.opacity(0.08),
                                .clear
                            ],
                            center: .center,
                            startRadius: 24,
                            endRadius: 360
                        ),
                        lineWidth: 1.2
                    )
            }
            .overlay {
                shape
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.18),
                                mint.opacity(0.16),
                                Color.white.opacity(0.06)
                            ],
                            startPoint: startPoint,
                            endPoint: endPoint
                        ),
                        lineWidth: 0.8
                    )
            }
            .shadow(color: mint.opacity(0.08), radius: 22, x: 0, y: 12)
    }
}

private struct AmbientNebulaView: View {
    let size: CGSize
    let time: TimeInterval

    private let mint = Color(red: 0.75, green: 0.96, blue: 0.89)
    private let silver = Color(red: 0.93, green: 0.97, blue: 0.99)

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [
                    mint.opacity(0.16),
                    mint.opacity(0.06),
                    .clear
                ],
                center: .center,
                startRadius: 16,
                endRadius: size.width * 0.42
            )
            .frame(width: size.width * 0.62, height: size.width * 0.62)
            .position(
                x: size.width * CGFloat(0.26 + (sin(time * 0.14) * 0.04)),
                y: size.height * CGFloat(0.28 + (cos(time * 0.12) * 0.05))
            )
            .blur(radius: 12)

            RadialGradient(
                colors: [
                    silver.opacity(0.14),
                    mint.opacity(0.04),
                    .clear
                ],
                center: .center,
                startRadius: 12,
                endRadius: size.width * 0.38
            )
            .frame(width: size.width * 0.54, height: size.width * 0.54)
            .position(
                x: size.width * CGFloat(0.76 + (cos(time * 0.16) * 0.03)),
                y: size.height * CGFloat(0.68 + (sin(time * 0.13) * 0.04))
            )
            .blur(radius: 16)

            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.12),
                            mint.opacity(0.03),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size.width * 0.80, height: size.height * 0.60)
                .rotationEffect(.degrees(time * 3.5))
                .offset(y: -10)
                .blur(radius: 20)
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }
}

private struct GalaxyNetworkCanvas: View {
    let time: TimeInterval
    let center: CGPoint
    let nodes: [ResolvedSoulNode]
    let pulse: RenderedPulse?

    private let mint = Color(red: 0.78, green: 0.97, blue: 0.91)

    var body: some View {
        Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: true) { context, _ in
            context.blendMode = .screen

            for entry in nodes {
                drawThread(for: entry, in: &context)
            }

            for entry in nodes {
                drawNode(for: entry, in: &context)
            }

            if let pulse {
                drawPulse(pulse, in: &context)
            }
        }
        .allowsHitTesting(false)
    }

    private func drawThread(
        for entry: ResolvedSoulNode,
        in context: inout GraphicsContext
    ) {
        let phase = entry.node.threadPhase + (time * 0.9)
        let startPoint = CGPoint(
            x: entry.point.x + CGFloat(cos(phase)) * 26,
            y: entry.point.y + CGFloat(sin(phase * 1.1)) * 18
        )
        let endPoint = CGPoint(
            x: center.x + CGFloat(sin(phase * 0.8)) * 14,
            y: center.y + CGFloat(cos(phase * 0.7)) * 14
        )

        var path = Path()
        path.move(to: entry.point)
        path.addLine(to: center)

        context.stroke(
            path,
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: mint.opacity(0.02), location: 0),
                    .init(color: Color.white.opacity(0.07 + (0.05 * entry.shimmer)), location: 0.32),
                    .init(color: mint.opacity(0.12 + (0.10 * entry.shimmer)), location: 0.72),
                    .init(color: Color.white.opacity(0.18 + (0.10 * entry.shimmer)), location: 1)
                ]),
                startPoint: startPoint,
                endPoint: endPoint
            ),
            style: StrokeStyle(
                lineWidth: 1.05,
                lineCap: .round,
                lineJoin: .round
            )
        )
    }

    private func drawNode(
        for entry: ResolvedSoulNode,
        in context: inout GraphicsContext
    ) {
        let glowDiameter = entry.node.diameter + CGFloat(10 + (entry.shimmer * 6))
        let glowRect = CGRect(
            x: entry.point.x - glowDiameter / 2,
            y: entry.point.y - glowDiameter / 2,
            width: glowDiameter,
            height: glowDiameter
        )
        let coreRect = CGRect(
            x: entry.point.x - entry.node.diameter / 2,
            y: entry.point.y - entry.node.diameter / 2,
            width: entry.node.diameter,
            height: entry.node.diameter
        )

        context.fill(
            Path(ellipseIn: glowRect),
            with: .color(mint.opacity(0.08 + (0.08 * entry.shimmer)))
        )

        context.fill(
            Path(ellipseIn: coreRect),
            with: .color(Color.white.opacity(entry.node.luminosity))
        )

        let sparkDiameter = max(entry.node.diameter * 0.32, 1.4)
        let sparkRect = CGRect(
            x: entry.point.x - sparkDiameter / 2,
            y: entry.point.y - sparkDiameter / 2,
            width: sparkDiameter,
            height: sparkDiameter
        )

        context.fill(
            Path(ellipseIn: sparkRect),
            with: .color(Color.white.opacity(0.9))
        )
    }

    private func drawPulse(
        _ pulse: RenderedPulse,
        in context: inout GraphicsContext
    ) {
        let glowDiameter = CGFloat(18 + (pulse.impact * 10))
        let glowRect = CGRect(
            x: pulse.point.x - glowDiameter / 2,
            y: pulse.point.y - glowDiameter / 2,
            width: glowDiameter,
            height: glowDiameter
        )
        let coreDiameter = CGFloat(8 + (pulse.impact * 4))
        let coreRect = CGRect(
            x: pulse.point.x - coreDiameter / 2,
            y: pulse.point.y - coreDiameter / 2,
            width: coreDiameter,
            height: coreDiameter
        )

        context.fill(
            Path(ellipseIn: glowRect),
            with: .color(mint.opacity(0.18 + (0.18 * pulse.impact)))
        )

        context.fill(
            Path(ellipseIn: coreRect),
            with: .color(Color.white.opacity(0.95))
        )
    }
}

private struct LivingCoreView: View {
    let time: TimeInterval
    let pulseImpact: Double

    private let mint = Color(red: 0.79, green: 0.98, blue: 0.92)
    private let deepMint = Color(red: 0.57, green: 0.86, blue: 0.78)

    var body: some View {
        let breathing = 0.5 + (sin(time * 0.9) * 0.5)
        let secondaryBreath = 0.5 + (cos(time * 0.6) * 0.5)
        let impact = pulseImpact

        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            mint.opacity(0.28 + (0.14 * impact)),
                            deepMint.opacity(0.10 + (0.08 * breathing)),
                            .clear
                        ],
                        center: .center,
                        startRadius: 12,
                        endRadius: 118
                    )
                )
                .frame(width: 234, height: 234)
                .blur(radius: 28)
                .scaleEffect(CGFloat(0.96 + (breathing * 0.08) + (impact * 0.08)))
                .blendMode(.plusLighter)

            Circle()
                .fill(
                    AngularGradient(
                        colors: [
                            Color.white.opacity(0.04),
                            mint.opacity(0.24),
                            Color.white.opacity(0.10),
                            deepMint.opacity(0.18),
                            Color.white.opacity(0.04)
                        ],
                        center: .center,
                        angle: .degrees(time * 18)
                    )
                )
                .frame(width: 172, height: 172)
                .blur(radius: 14)
                .scaleEffect(CGFloat(0.94 + (secondaryBreath * 0.08)))
                .blendMode(.screen)

            Circle()
                .trim(from: 0.08, to: 0.92)
                .stroke(
                    AngularGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            mint.opacity(0.26),
                            Color.white.opacity(0.18),
                            deepMint.opacity(0.12),
                            Color.white.opacity(0.06)
                        ],
                        center: .center,
                        angle: .degrees(-time * 24)
                    ),
                    style: StrokeStyle(
                        lineWidth: CGFloat(1.2 + impact),
                        lineCap: .round
                    )
                )
                .frame(width: 126, height: 126)
                .rotationEffect(.degrees(time * 8))
                .blur(radius: 0.4)
                .blendMode(.screen)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.94),
                            mint.opacity(0.88),
                            deepMint.opacity(0.34)
                        ],
                        center: .center,
                        startRadius: 6,
                        endRadius: 68
                    )
                )
                .frame(
                    width: 92 + CGFloat((secondaryBreath * 8) + (impact * 10)),
                    height: 92 + CGFloat((secondaryBreath * 8) + (impact * 10))
                )
                .shadow(
                    color: mint.opacity(0.34 + (0.16 * impact)),
                    radius: CGFloat(18 + (impact * 10)),
                    x: 0,
                    y: 0
                )
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.24), lineWidth: 0.8)
                }
                .blendMode(.plusLighter)
        }
        .frame(width: 250, height: 250)
        .compositingGroup()
    }
}

private struct RadialSoulNode: Identifiable {
    let id = UUID()
    let angle: Double
    let radiusFactor: Double
    let diameter: CGFloat
    let driftAmplitude: CGFloat
    let driftSpeed: Double
    let driftPhase: Double
    let secondaryPhase: Double
    let threadPhase: Double
    let luminosity: Double

    func basePosition(in size: CGSize) -> CGPoint {
        let orbitRadius = min(size.width, size.height) * CGFloat(radiusFactor)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        return CGPoint(
            x: center.x + CGFloat(cos(angle)) * orbitRadius,
            y: center.y + CGFloat(sin(angle)) * orbitRadius
        )
    }

    func point(in size: CGSize, time: TimeInterval) -> CGPoint {
        let base = basePosition(in: size)
        let driftX = CGFloat(cos((time * driftSpeed) + driftPhase)) * driftAmplitude
        let driftY = CGFloat(sin((time * driftSpeed * 0.82) + secondaryPhase)) * (driftAmplitude * 0.82)

        return CGPoint(
            x: base.x + driftX,
            y: base.y + driftY
        )
    }

    func shimmer(at time: TimeInterval) -> Double {
        let wave = sin((time * (driftSpeed * 4.2)) + threadPhase)
        return 0.5 + (wave * 0.5)
    }
}

private struct ResolvedSoulNode {
    let node: RadialSoulNode
    let point: CGPoint
    let shimmer: Double
}

private struct PulseEvent: Equatable {
    let nodeID: UUID
    let startedAt: Date
    let duration: TimeInterval = 2
}

private struct RenderedPulse {
    let point: CGPoint
    let progress: Double
    let impact: Double
}
