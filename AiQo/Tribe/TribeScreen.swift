import SwiftUI

@MainActor
struct TribeScreen: View {
    @StateObject private var viewModel: TribeModuleViewModel

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

            VStack(spacing: 18) {
                TribeSegmentedControl(selection: $viewModel.selectedTab)
                    .padding(.horizontal, TribePremiumTokens.horizontalPadding)
                    .padding(.top, 8)

                if viewModel.isLoading && hasLoadedTribeContent == false {
                    TribeLoadingView()
                        .padding(.horizontal, TribePremiumTokens.horizontalPadding)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                } else {
                    activeTabView
                }
            }
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
                    .padding(.top, 64)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private var activeTabView: some View {
        switch viewModel.selectedTab {
        case .tribe:
            TribeOverviewPage(
                heroSummary: viewModel.heroSummary,
                stats: viewModel.tribeStats,
                featuredMembers: viewModel.featuredMembers,
                onRefresh: viewModel.refresh
            )
            .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.98)), removal: .opacity))

        case .arena:
            TribePhasePlaceholderPage(
                title: "الارينا",
                subtitle: "هذا التبويب سيبنى في المرحلة التالية.",
                systemImage: "sparkles"
            )
            .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.98)), removal: .opacity))

        case .global:
            TribePhasePlaceholderPage(
                title: "العالمي",
                subtitle: "سيتم بناء هذا التبويب لاحقًا ضمن مرحلة مستقلة.",
                systemImage: "globe"
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
