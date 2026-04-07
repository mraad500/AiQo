import SwiftUI

struct GalaxyView: View {
    @ObservedObject var store: GalaxyStore
    @ObservedObject var arenaStore: ArenaStore
    let presentationMode: Bool
    let onOpenArena: () -> Void

    @State private var sparkProgress: CGFloat = 0
    @State private var sparkSourceNodeId: String?
    @State private var baseZoomScale: CGFloat = 1
    @State private var isComposerPresented = false
    @State private var challengeTitle = ""
    @State private var challengeCadence: ChallengeCadence = .daily
    @State private var challengeMetricType: TribeChallengeMetricType = .steps

    private var visibleNodes: [GalaxyNode] {
        Array(store.nodes.prefix(presentationMode ? 10 : 12))
    }

    private var visibleEdges: [GalaxyEdge] {
        let nodeIDs = Set(visibleNodes.map(\.id))
        return store.edges.filter { nodeIDs.contains($0.fromId) && nodeIDs.contains($0.toId) }
    }

    private var highlightedNodeIDs: Set<String> {
        Set(store.topNodes.map(\.id))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let toastMessage = store.toastMessage {
                Text(toastMessage)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(TribePalette.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(TribePalette.chip))
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            TribeGlassCard(cornerRadius: 32, padding: 18, tint: TribePalette.surfaceMint) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("tribe.galaxy.title".localized)
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundStyle(TribePalette.textPrimary)

                            Text("tribe.galaxy.subtitle".localized)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(TribePalette.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 12)

                        TribeSegmentedPill(
                            options: GalaxyLayoutStyle.allCases,
                            selection: Binding(
                                get: { store.layoutStyle },
                                set: { store.setLayoutStyle($0) }
                            ),
                            title: { $0.title }
                        )
                        .frame(maxWidth: 180)
                    }

                    canvasSurface

                    Text("tribe.galaxy.caption".localized)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(TribePalette.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .animation(.spring(response: 0.36, dampingFraction: 0.86), value: store.toastMessage)
        .sheet(isPresented: $isComposerPresented) {
            galaxyChallengeComposer
        }
        .onChange(of: store.sparkEvent?.id) {
            triggerSpark()
        }
    }

    private var canvasSurface: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let center = CGPoint(
                x: (size.width * 0.5) + store.dragOffset.width,
                y: (size.height * 0.42) + store.dragOffset.height
            )
            let points = Dictionary(uniqueKeysWithValues: visibleNodes.map { node in
                (node.id, point(for: node, center: center, in: size))
            })

            ZStack(alignment: .bottom) {
                Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: true) { context, _ in
                    drawAmbient(in: &context, size: size)
                    drawOrbits(in: &context, center: center, size: size)

                    if store.layoutStyle == .spokes {
                        drawSpokes(in: &context, center: center, points: points)
                    } else {
                        drawEdges(in: &context, points: points)
                    }

                    drawCenter(in: &context, center: center)
                    drawNodes(in: &context, points: points)
                    drawSpark(in: &context, center: center, points: points)
                }
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .contentShape(Rectangle())
                .gesture(dragGesture)
                .simultaneousGesture(magnificationGesture)

                ForEach(visibleNodes) { node in
                    if let point = points[node.id] {
                        nodeButton(for: node)
                            .position(point)
                    }
                }

                if let selectedNode = store.selectedNode {
                    selectionSheet(for: selectedNode)
                        .padding(8)
                }
            }
        }
        .frame(height: presentationMode ? 410 : 460)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                store.updatePan(value.translation)
            }
            .onEnded { _ in
                withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                    store.resetPan()
                }
            }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                store.updateZoom(baseZoomScale * value)
            }
            .onEnded { value in
                withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                    store.updateZoom(baseZoomScale * value)
                }
                baseZoomScale = store.zoomScale
            }
    }

    private func point(for node: GalaxyNode, center: CGPoint, in size: CGSize) -> CGPoint {
        let axis = min(size.width, size.height)
        let vector = CGVector(
            dx: (node.normalizedPosition.x - 0.5) * axis * store.zoomScale,
            dy: (node.normalizedPosition.y - 0.42) * axis * store.zoomScale
        )

        return CGPoint(
            x: center.x + vector.dx,
            y: center.y + vector.dy
        )
    }

    private func nodeButton(for node: GalaxyNode) -> some View {
        let isSelected = store.selectedNodeId == node.id
        let rankVisible = node.rank <= 3

        return Button {
            store.select(node: node)
        } label: {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 68, height: 68)

                Group {
                    if node.member.visibility == .public {
                        Text(node.member.resolvedInitials)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(TribePalette.textPrimary.opacity(isSelected ? 0.96 : 0.78))
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(TribePalette.textSecondary)
                    }
                }
                .offset(y: 1)

                if rankVisible {
                    Text("\(node.rank)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(TribePalette.textPrimary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(TribePalette.actionPrimary))
                        .offset(x: 12, y: -8)
                }
            }
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.35).onEnded { _ in
                store.select(node: node)
                store.sendSpark()
            }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(for: node))
    }

    private func accessibilityLabel(for node: GalaxyNode) -> String {
        if node.member.visibility == .public {
            return String(
                format: "tribe.galaxy.node.accessibility.public".localized,
                locale: Locale.current,
                node.member.visibleDisplayName,
                node.member.level,
                node.member.auraEnergyToday
            )
        }
        return String(
            format: "tribe.galaxy.node.accessibility.private".localized,
            locale: Locale.current,
            node.member.level
        )
    }

    private func selectionSheet(for node: GalaxyNode) -> some View {
        let featuredChallenge = arenaStore.featuredGalaxyChallenges(for: .daily).first

        return TribeGlassCard(cornerRadius: 24, padding: 14, tint: TribePalette.surfaceSand) {
            VStack(alignment: .leading, spacing: 10) {
                Text(node.member.visibility == .public ? node.member.visibleDisplayName : "tribe.member.anonymous".localized)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(TribePalette.textPrimary)

                HStack(spacing: 8) {
                    Text(
                        String(
                            format: "tribe.member.level".localized,
                            locale: Locale.current,
                            node.member.level
                        )
                    )
                    Text(
                        node.member.visibility == .public
                        ? String(
                            format: "tribe.galaxy.node.energy".localized,
                            locale: Locale.current,
                            node.member.auraEnergyToday
                        )
                        : "tribe.galaxy.node.private".localized
                    )
                }
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(TribePalette.textSecondary)

                if let featuredChallenge {
                    Text(
                        String(
                            format: "tribe.galaxy.quickSuggestion".localized,
                            locale: Locale.current,
                            featuredChallenge.title
                        )
                    )
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(TribePalette.textTertiary)
                        .lineLimit(2)
                }

                HStack(spacing: 10) {
                    Button {
                        store.sendSpark()
                    } label: {
                        Text("tribe.action.spark".localized)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(TribePalette.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(TribePalette.actionPrimary))
                    }
                    .buttonStyle(.plain)

                    Button {
                        isComposerPresented = true
                    } label: {
                        Text("tribe.galaxy.createChallenge".localized)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(TribePalette.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(TribePalette.actionSecondary))
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    onOpenArena()
                } label: {
                    Text("tribe.galaxy.openArena".localized)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(TribePalette.textSecondary)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var galaxyChallengeComposer: some View {
        NavigationStack {
            Form {
                Section("tribe.galaxy.sheet.section".localized) {
                    TextField("tribe.arena.composer.title".localized, text: $challengeTitle)

                    Picker("tribe.arena.composer.cadence".localized, selection: $challengeCadence) {
                        ForEach(ChallengeCadence.allCases) { cadence in
                            Text(cadence.title).tag(cadence)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("tribe.arena.composer.type".localized, selection: $challengeMetricType) {
                        ForEach(TribeChallengeMetricType.allCases) { metricType in
                            Text(metricType.title).tag(metricType)
                        }
                    }
                }

                Section {
                    Button("tribe.galaxy.sheet.createInTribe".localized) {
                        arenaStore.createChallenge(
                            scope: .tribe,
                            cadence: challengeCadence,
                            metricType: challengeMetricType,
                            title: challengeTitle,
                            subtitle: "tribe.galaxy.sheet.createdFromGalaxy".localized
                        )
                        isComposerPresented = false
                    }

                    Button("tribe.action.suggestGalaxy".localized) {
                        arenaStore.suggestGalaxyChallenge(
                            title: challengeTitle.isEmpty ? "tribe.arena.composer.suggestionFallback".localized : challengeTitle,
                            metricType: challengeMetricType,
                            cadence: challengeCadence
                        )
                        isComposerPresented = false
                    }
                }
            }
            .navigationTitle("tribe.arena.newChallenge".localized)
            .navigationBarTitleDisplayMode(.inline)
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    private func drawAmbient(in context: inout GraphicsContext, size: CGSize) {
        for index in 0..<24 {
            let x = CGFloat((index * 19) % 100) / 100
            let y = CGFloat((index * 31 + 7) % 100) / 100
            let rect = CGRect(
                x: x * size.width,
                y: y * size.height,
                width: index.isMultiple(of: 5) ? 2.2 : 1.3,
                height: index.isMultiple(of: 5) ? 2.2 : 1.3
            )
            context.fill(Path(ellipseIn: rect), with: .color(TribePalette.star.opacity(index.isMultiple(of: 3) ? 0.14 : 0.08)))
        }
    }

    private func drawOrbits(in context: inout GraphicsContext, center: CGPoint, size: CGSize) {
        let base = min(size.width, size.height)
        let radii = [base * 0.20, base * 0.29, base * 0.38]

        for radius in radii {
            let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            context.stroke(
                Path(ellipseIn: rect),
                with: .color(TribePalette.chip.opacity(0.52)),
                style: StrokeStyle(lineWidth: 0.8, dash: [2, 7], dashPhase: radius * 0.16)
            )
        }
    }

    private func drawSpokes(
        in context: inout GraphicsContext,
        center: CGPoint,
        points: [String: CGPoint]
    ) {
        for node in visibleNodes {
            guard let point = points[node.id] else { continue }

            var path = Path()
            path.move(to: center)
            path.addLine(to: point)

            context.stroke(
                path,
                with: .linearGradient(
                    Gradient(colors: [
                        TribePalette.chip.opacity(0.60),
                        Color(hue: node.hue, saturation: 0.22, brightness: 0.86).opacity(highlightedNodeIDs.contains(node.id) ? 0.22 : 0.12)
                    ]),
                    startPoint: center,
                    endPoint: point
                ),
                style: StrokeStyle(lineWidth: highlightedNodeIDs.contains(node.id) ? 1.1 : 0.7, lineCap: .round)
            )
        }
    }

    private func drawEdges(
        in context: inout GraphicsContext,
        points: [String: CGPoint]
    ) {
        for edge in visibleEdges {
            guard let from = points[edge.fromId], let to = points[edge.toId] else { continue }

            let emphasis = highlightedNodeIDs.contains(edge.fromId) || highlightedNodeIDs.contains(edge.toId)

            var path = Path()
            path.move(to: from)
            path.addLine(to: to)

            context.stroke(
                path,
                with: .color(TribePalette.border.opacity(emphasis ? 1 : 0.65)),
                style: StrokeStyle(lineWidth: 0.6 + (edge.weight * 0.6), lineCap: .round)
            )
        }
    }

    private func drawCenter(in context: inout GraphicsContext, center: CGPoint) {
        let outer = CGRect(x: center.x - 62, y: center.y - 62, width: 124, height: 124)
        let middle = CGRect(x: center.x - 35, y: center.y - 35, width: 70, height: 70)
        let inner = CGRect(x: center.x - 18, y: center.y - 18, width: 36, height: 36)

        context.fill(
            Path(ellipseIn: outer),
            with: .radialGradient(
                Gradient(colors: [
                    TribePalette.glowMint,
                    .clear
                ]),
                center: center,
                startRadius: 6,
                endRadius: 62
            )
        )

        context.fill(
            Path(ellipseIn: middle),
            with: .linearGradient(
                Gradient(colors: [
                    TribePalette.surfaceStrong,
                    TribePalette.surfaceMint
                ]),
                startPoint: CGPoint(x: middle.minX, y: middle.minY),
                endPoint: CGPoint(x: middle.maxX, y: middle.maxY)
            )
        )

        context.stroke(Path(ellipseIn: middle), with: .color(TribePalette.border), lineWidth: 1)

        context.fill(
            Path(ellipseIn: inner),
            with: .radialGradient(
                Gradient(colors: [
                    Color.white.opacity(0.98),
                    Color.aiqoMint.opacity(0.90),
                    Color.aiqoSand.opacity(0.36)
                ]),
                center: center,
                startRadius: 2,
                endRadius: 22
            )
        )

        var label = context.resolve(
            Text("tribe.galaxy.source".localized)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
        )
        label.shading = .color(TribePalette.textSecondary)
        context.draw(label, at: CGPoint(x: center.x, y: center.y + 48), anchor: .center)
    }

    private func drawNodes(
        in context: inout GraphicsContext,
        points: [String: CGPoint]
    ) {
        for node in visibleNodes {
            guard let point = points[node.id] else { continue }

            let isSelected = node.id == store.selectedNodeId
            let emphasized = highlightedNodeIDs.contains(node.id)
            let radius: CGFloat = node.rank <= 2 ? 21 : 17
            let glowRadius = radius + (isSelected ? 14 : emphasized ? 10 : 7)
            let glowRect = CGRect(x: point.x - glowRadius, y: point.y - glowRadius, width: glowRadius * 2, height: glowRadius * 2)
            let bodyRect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)

            let baseGlow = min(max(CGFloat(node.member.auraEnergyToday) / 100, 0.10), 0.24)
            let glowOpacity = isSelected ? 0.30 : baseGlow + (emphasized ? 0.04 : 0)
            let nodeColor = Color(hue: node.hue, saturation: 0.18, brightness: 0.82)

            context.fill(
                Path(ellipseIn: glowRect),
                with: .radialGradient(
                    Gradient(colors: [
                        nodeColor.opacity(glowOpacity),
                        .clear
                    ]),
                    center: point,
                    startRadius: 4,
                    endRadius: glowRadius
                )
            )

            context.fill(
                Path(ellipseIn: bodyRect),
                with: .linearGradient(
                    Gradient(colors: [
                        Color.white.opacity(isSelected ? 0.92 : 0.84),
                        nodeColor.opacity(0.16)
                    ]),
                    startPoint: CGPoint(x: bodyRect.minX, y: bodyRect.minY),
                    endPoint: CGPoint(x: bodyRect.maxX, y: bodyRect.maxY)
                )
            )

            context.stroke(
                Path(ellipseIn: bodyRect),
                with: .color(TribePalette.border.opacity(isSelected ? 1 : 0.7)),
                lineWidth: 1
            )
        }
    }

    private func drawSpark(
        in context: inout GraphicsContext,
        center: CGPoint,
        points: [String: CGPoint]
    ) {
        guard sparkProgress > 0,
              let sparkSourceNodeId,
              let start = points[sparkSourceNodeId] else { return }

        let travel = CGPoint(
            x: start.x + ((center.x - start.x) * sparkProgress),
            y: start.y + ((center.y - start.y) * sparkProgress)
        )
        let trailRect = CGRect(x: travel.x - 6, y: travel.y - 6, width: 12, height: 12)
        let glowRect = CGRect(x: travel.x - 18, y: travel.y - 18, width: 36, height: 36)

        context.fill(
            Path(ellipseIn: glowRect),
            with: .radialGradient(
                Gradient(colors: [TribePalette.glowSand, .clear]),
                center: travel,
                startRadius: 2,
                endRadius: 18
            )
        )

        context.fill(
            Path(ellipseIn: trailRect),
            with: .color(TribePalette.progressFill)
        )
    }

    private func triggerSpark() {
        sparkSourceNodeId = store.sparkEvent?.sourceNodeId ?? store.selectedNodeId
        sparkProgress = 0.01

        withAnimation(.easeOut(duration: 0.7)) {
            sparkProgress = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            sparkProgress = 0
            sparkSourceNodeId = nil
        }
    }
}

private struct GalaxyViewPreviewContainer: View {
    @StateObject private var galaxyStore = GalaxyStore()
    @StateObject private var arenaStore = ArenaStore()

    var body: some View {
        ZStack {
            TribeGalaxyBackground()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                GalaxyView(
                    store: galaxyStore,
                    arenaStore: arenaStore,
                    presentationMode: false,
                    onOpenArena: { }
                )
                .padding(16)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .task {
            let snapshot = await MockTribeRepository().loadSnapshot()
            galaxyStore.load(members: snapshot.members)
            await arenaStore.load()
        }
    }
}

#Preview {
    GalaxyViewPreviewContainer()
}
