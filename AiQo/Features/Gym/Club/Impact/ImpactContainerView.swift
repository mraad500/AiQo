import SwiftUI

enum ImpactSubTab: String, CaseIterable, Identifiable {
    case summary
    case achievements

    var id: Self { self }

    var titleKey: String {
        switch self {
        case .summary: return "impact_summary"
        case .achievements: return "impact_achievements"
        }
    }

    var accessibilityLabelKey: String {
        switch self {
        case .summary: return "club.impact.summary.accessibility.label"
        case .achievements: return "club.impact.achievements.accessibility.label"
        }
    }

    var accessibilityHintKey: String {
        switch self {
        case .summary: return "club.impact.summary.accessibility.hint"
        case .achievements: return "club.impact.achievements.accessibility.hint"
        }
    }

    var railIcon: String {
        switch self {
        case .summary: return "chart.bar"
        case .achievements: return "medal"
        }
    }

    var railTint: Color {
        switch self {
        case .summary: return AiQoColors.mint
        case .achievements: return AiQoColors.beige
        }
    }
}

extension ClubTopTab: ClubSegmentedTabItem {}
extension ImpactSubTab: ClubSegmentedTabItem {}

struct ImpactContainerView: View {
    @Environment(\.layoutDirection) private var layoutDirection

    @State private var selectedTab: ImpactSubTab = .summary
    @State private var isRailCollapsed = true
    @State private var isRailHidden = false
    @State private var previousScrollOffset: CGFloat = 0

    let winsStore: WinsStore

    private var railItems: [RailItem] {
        ImpactSubTab.allCases.map {
            RailItem(
                id: $0.rawValue,
                title: L10n.t($0.titleKey),
                icon: $0.railIcon,
                tint: $0.railTint
            )
        }
    }

    var body: some View {
        ZStack {
            ZStack {
                switch selectedTab {
                case .summary:
                    ImpactSummaryView(onScrollOffsetChange: handleRailScroll)
                        .transition(.opacity)

                case .achievements:
                    ImpactAchievementsView(
                        winsStore: winsStore,
                        onScrollOffsetChange: handleRailScroll
                    )
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .clubPhysicalRightContentInset(layoutDirection: layoutDirection)
            .animation(.spring(response: 0.34, dampingFraction: 0.84), value: selectedTab)
        }
        .clubRightRailOverlay {
            RightSideVerticalRail(
                items: railItems,
                selection: selectedTabIndex,
                isCollapsed: $isRailCollapsed,
                isHidden: $isRailHidden
            )
            .accessibilityLabel(Text(verbatim: L10n.t("club.impact_tabs.accessibility.label")))
        }
    }

    private var selectedTabIndex: Binding<Int> {
        Binding(
            get: {
                ImpactSubTab.allCases.firstIndex(of: selectedTab) ?? 0
            },
            set: { newValue in
                guard ImpactSubTab.allCases.indices.contains(newValue) else { return }
                selectedTab = ImpactSubTab.allCases[newValue]
            }
        )
    }

    private func handleRailScroll(offset: CGFloat) {
        let delta = offset - previousScrollOffset

        if delta <= -15 {
            withAnimation(.easeOut(duration: 0.25)) {
                isRailHidden = true
            }
        } else if delta >= 15 || offset >= -8 {
            withAnimation(.easeOut(duration: 0.25)) {
                isRailHidden = false
            }
        }

        if offset <= -180, !isRailCollapsed {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                isRailCollapsed = true
            }
        }

        previousScrollOffset = offset
    }
}

#Preview("Impact Container RTL") {
    ImpactContainerView(winsStore: WinsStore())
        .environment(\.layoutDirection, .rightToLeft)
}
