import SwiftUI

private enum TribeScreenLayout {
    static let headerTopPadding: CGFloat = AiQoScreenHeaderMetrics.topPadding
    static let headerBottomPadding: CGFloat = AiQoScreenHeaderMetrics.bottomPadding
    static let contentTopPadding: CGFloat = 8
    static let loadingIndicatorTopPadding: CGFloat =
        AiQoScreenHeaderMetrics.topPadding
        + AiQoProfileButtonLayout.hitTargetDiameter
        + AiQoScreenHeaderMetrics.bottomPadding
        + 6
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
        .safeAreaInset(edge: .top, spacing: 0) {
            topHeaderBar
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
        .aiqoProfileSheet(isPresented: $isProfilePresented)
    }

    private var topHeaderBar: some View {
        AiQoScreenTopChrome(
            leadingReservedWidth: 0,
            itemSpacing: 8,
            horizontalInset: 12,
            topPadding: TribeScreenLayout.headerTopPadding,
            bottomPadding: TribeScreenLayout.headerBottomPadding,
            contentMaxWidth: nil,
            contentAlignment: .center,
            onProfileTap: { isProfilePresented = true }
        ) {
            TribeTopSegmentedControl(selection: $viewModel.selectedTab)
                .environment(\.layoutDirection, .rightToLeft)
        }
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
