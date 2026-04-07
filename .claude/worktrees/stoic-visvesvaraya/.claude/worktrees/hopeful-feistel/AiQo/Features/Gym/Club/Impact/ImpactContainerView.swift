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
    @State private var selectedTab: ImpactSubTab = .summary

    let winsStore: WinsStore

    private let contentTrailingPadding: CGFloat = ClubChromeLayout.contentTrailingPadding - 10

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
        ClubStandardRightRailContainer(
            items: railItems,
            selection: selectedTabIndex,
            accessibilityLabel: Text(verbatim: L10n.t("club.impact_tabs.accessibility.label"))
        ) {
            ZStack {
                switch selectedTab {
                case .summary:
                    ImpactSummaryView()
                        .transition(.opacity)

                case .achievements:
                    ImpactAchievementsView(winsStore: winsStore)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.trailing, contentTrailingPadding)
            .animation(.spring(response: 0.34, dampingFraction: 0.84), value: selectedTab)
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
}

#Preview("Impact Container RTL") {
    ImpactContainerView(winsStore: WinsStore())
        .environment(\.layoutDirection, .rightToLeft)
}
