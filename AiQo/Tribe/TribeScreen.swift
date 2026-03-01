import SwiftUI

@MainActor
struct TribeScreen: View {
    @StateObject private var tribeStore = TribeStore.shared
    @StateObject private var premiumStore = PremiumStore.shared
    @StateObject private var accessManager = AccessManager.shared
    @StateObject private var arenaStore = ArenaStore()
    @StateObject private var galaxyStore = GalaxyStore()
    @StateObject private var logStore = TribeLogStore()

    let allowsPreviewAccess: Bool

    @State private var selectedTab: TribeScreenTab = .hub
    @State private var presentationMode = false
    @State private var didBootstrap = false
    @State private var lastBootstrapSignature = ""
    @State private var isDeveloperPanelPresented = false

    init(allowsPreviewAccess: Bool = false) {
        self.allowsPreviewAccess = allowsPreviewAccess
    }

    private var hasFeatureAccess: Bool {
        allowsPreviewAccess || accessManager.canAccessTribe
    }

    private var usesMockPreviewData: Bool {
        allowsPreviewAccess || (accessManager.isPreviewModeActive && accessManager.useMockTribeData)
    }

    private var bootstrapSignature: String {
        "\(allowsPreviewAccess)-\(accessManager.configurationSignature)"
    }

    private var activeMemberId: String? {
        tribeStore.members.first(where: { $0.id == "tribe-self" || $0.userId == "tribe-self" })?.id ?? tribeStore.members.first?.id
    }

    private var privacyBinding: Binding<PrivacyMode> {
        Binding(
            get: { tribeStore.currentPrivacyMode },
            set: {
                tribeStore.updateMyPrivacy(mode: $0)
                refreshDerivedStores()
            }
        )
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                header

                if accessManager.isPreviewModeActive {
                    previewBanner
                }

                tabSelector

                if hasFeatureAccess {
                    contentView
                } else {
                    PremiumPaywallView()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .background(TribeGalaxyBackground().ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isDeveloperPanelPresented) {
            DeveloperPanelView()
        }
        .task(id: bootstrapSignature) {
            await bootstrapIfNeeded(signature: bootstrapSignature)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text("tribe.screen.title".localized)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(TribePalette.textPrimary)

                Text("tribe.screen.subtitle".localized)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(TribePalette.textSecondary)
            }
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: 5) {
                guard accessManager.allowsDeveloperOverrides else { return }
                isDeveloperPanelPresented = true
            }

            Spacer(minLength: 0)

            Button {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                    presentationMode.toggle()
                }
            } label: {
                Text("tribe.presentationMode".localized)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(TribePalette.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(TribePalette.surfaceStrong))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 2)
    }

    private var previewBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(TribePalette.textSecondary)

            Text("debug.preview.banner".localized)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(TribePalette.textPrimary)

            if let activePlan = accessManager.activePlan {
                Text(activePlan.title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(TribePalette.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(TribePalette.surfaceStrong))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(TribePalette.surfaceStrong)
                .overlay(
                    Capsule()
                        .stroke(TribePalette.border, lineWidth: 1)
                )
        )
    }

    private var tabSelector: some View {
        TribeSegmentedPill(
            options: TribeScreenTab.allCases,
            selection: $selectedTab,
            title: { $0.title }
        )
    }

    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case .hub:
            TribeHubView(
                tribe: tribeStore.currentTribe,
                members: tribeStore.members,
                missions: tribeStore.missions,
                currentMemberId: activeMemberId,
                privacyMode: privacyBinding,
                presentationMode: presentationMode,
                onOpenGalaxy: {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                        selectedTab = .galaxy
                    }
                },
                onSpark: handleMemberSpark
            )
        case .arena:
            VStack(alignment: .leading, spacing: 12) {
                if let message = arenaStore.statusMessage {
                    statusPill(message)
                }

                TribeArenaView(
                    store: arenaStore,
                    members: tribeStore.members,
                    presentationMode: presentationMode,
                    onContribute: handleArenaContribution
                )
            }
        case .log:
            TribeLogView(events: logStore.latestEvents, presentationMode: presentationMode)
        case .galaxy:
            GalaxyView(
                store: galaxyStore,
                arenaStore: arenaStore,
                presentationMode: presentationMode,
                onOpenArena: {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                        selectedTab = .arena
                    }
                }
            )
        }
    }

    private func statusPill(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(TribePalette.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Capsule().fill(TribePalette.chip))
    }

    private func bootstrapIfNeeded(signature: String) async {
        premiumStore.start()

        guard !didBootstrap || lastBootstrapSignature != signature else {
            refreshDerivedStores()
            return
        }

        didBootstrap = true
        lastBootstrapSignature = signature

        let tribeRepository = selectedTribeRepository()
        await tribeStore.loadFromRepository(tribeRepository)
        await arenaStore.load(using: selectedChallengeRepository())
        refreshDerivedStores()
    }

    private func selectedTribeRepository() -> any TribeRepositoryProtocol {
        if usesMockPreviewData {
            return MockTribeRepository()
        }
        return TribeRepositoryFactory.makeTribeRepository()
    }

    private func selectedChallengeRepository() -> any ChallengeRepositoryProtocol {
        if usesMockPreviewData {
            return MockChallengeRepository()
        }
        return TribeRepositoryFactory.makeChallengeRepository()
    }

    private func refreshDerivedStores() {
        galaxyStore.load(members: tribeStore.members)
        logStore.load(from: tribeStore.events)
    }

    private func handleMemberSpark(_ member: TribeMember) {
        tribeStore.sendSpark(to: member.id)
        galaxyStore.select(node: galaxyStore.nodes.first(where: { $0.id == member.id }) ?? galaxyStore.nodes.first ?? GalaxyNode(
            id: member.id,
            member: member,
            rank: 1,
            orbit: 0,
            normalizedPosition: CGPoint(x: 0.5, y: 0.5),
            hue: 0.56
        ))
        galaxyStore.sendSpark()
        refreshDerivedStores()
    }

    private func handleArenaContribution(_ challenge: TribeChallenge) {
        guard let activeMemberId else { return }
        tribeStore.addContribution(amount: max(1, challenge.metricType.defaultIncrement / (challenge.metricType == .steps ? 250 : 1)), from: activeMemberId)
        galaxyStore.sendSpark()
        refreshDerivedStores()
    }
}

#Preview {
    NavigationStack {
        TribeScreen(allowsPreviewAccess: true)
    }
    .environment(\.layoutDirection, .rightToLeft)
}
