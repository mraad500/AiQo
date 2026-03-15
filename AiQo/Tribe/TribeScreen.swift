import SwiftUI

private enum TribeScreenLayout {
    static let headerTopPadding: CGFloat = 0
    static let headerBottomPadding: CGFloat = 2
    static let headerOverlayTopInset: CGFloat = 0
    static let contentTopPadding: CGFloat = 18
    static let loadingIndicatorTopPadding: CGFloat = 62
}

@MainActor
struct TribeScreen: View {
    @StateObject private var viewModel: TribeModuleViewModel
    @State private var isProfilePresented = false

    init(allowsPreviewAccess: Bool = false) {
        _viewModel = StateObject(
            wrappedValue: TribeModuleViewModel(allowsPreviewAccess: allowsPreviewAccess)
        )
    }

    private var hasLoadedTribeContent: Bool {
        viewModel.tribeStats.isEmpty == false || viewModel.featuredMembers.contains(where: { $0.isVacant == false })
    }

    var body: some View {
        ZStack {
            TribeScreenBackground()

            contentLayer
                .padding(.top, TribeScreenLayout.contentTopPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .ignoresSafeArea(edges: .top)
        .overlay(alignment: .top) {
            topHeaderBar
                .padding(.top, TribeScreenLayout.headerOverlayTopInset)
                .ignoresSafeArea(edges: .top)
        }
        .environment(\.layoutDirection, .rightToLeft)
        .task {
            await viewModel.loadIfNeeded()
        }
        .overlay(alignment: .top) {
            if viewModel.isLoading && hasLoadedTribeContent {
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.small)
                    .tint(TribeModernPalette.mintDeep)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule(style: .continuous))
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(TribeModernPalette.border, lineWidth: 1)
                    }
                    .padding(.top, TribeScreenLayout.loadingIndicatorTopPadding)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .aiqoTopTrailingProfileButton(isPresented: $isProfilePresented)
    }

    private var topHeaderBar: some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: AiQoProfileButtonLayout.reservedLaneWidth)

            TribeTopSegmentedControl(selection: $viewModel.selectedTab)
                .environment(\.layoutDirection, .rightToLeft)

            Color.clear
                .frame(width: AiQoProfileButtonLayout.reservedLaneWidth)
        }
        .environment(\.layoutDirection, .leftToRight)
        .padding(.horizontal, TribePremiumTokens.horizontalPadding)
        .padding(.top, TribeScreenLayout.headerTopPadding)
        .padding(.bottom, TribeScreenLayout.headerBottomPadding)
    }

    @ViewBuilder
    private var contentLayer: some View {
        if viewModel.isLoading && hasLoadedTribeContent == false {
            TribeLoadingView()
                .padding(.horizontal, TribePremiumTokens.horizontalPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else {
            activeTabView
        }
    }

    @ViewBuilder
    private var activeTabView: some View {
        switch viewModel.selectedTab {
        case .tribe:
            TribeView(
                heroSummary: viewModel.heroSummary,
                featuredMembers: viewModel.featuredMembers,
                onRefresh: viewModel.refresh
            )
            .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.98)), removal: .opacity))

        case .arena:
            ArenaView(
                heroSummary: viewModel.arenaHeroSummary,
                challenges: viewModel.arenaCompactChallenges,
                onRefresh: viewModel.refresh
            )
            .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.98)), removal: .opacity))

        case .global:
            GlobalView(
                timeFilter: $viewModel.globalTimeFilter,
                topThree: viewModel.globalTopThree,
                selfRankSummary: viewModel.globalSelfRankSummary,
                rankings: viewModel.globalRankingRows,
                onRefresh: viewModel.refresh
            )
            .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.98)), removal: .opacity))
        }
    }
}

#Preview {
    NavigationStack {
        TribeScreen(allowsPreviewAccess: true)
    }
}
