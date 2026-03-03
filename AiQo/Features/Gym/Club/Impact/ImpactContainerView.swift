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
}

extension ClubTopTab: ClubSegmentedTabItem {}
extension ImpactSubTab: ClubSegmentedTabItem {}

struct ImpactContainerView: View {
    @State private var selectedTab: ImpactSubTab = .summary

    let winsStore: WinsStore

    var body: some View {
        VStack(spacing: 8) {
            SecondarySegmentedTabs(selection: $selectedTab)
                .padding(.horizontal, 16)

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
            .animation(.easeInOut(duration: 0.22), value: selectedTab)
        }
    }
}

#Preview("Impact Container RTL") {
    ImpactContainerView(winsStore: WinsStore())
        .environment(\.layoutDirection, .rightToLeft)
}
