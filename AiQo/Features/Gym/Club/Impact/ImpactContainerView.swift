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

    private let filterLabels = ["الملخص", "الإنجازات"]

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
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
            .animation(.spring(response: 0.34, dampingFraction: 0.84), value: selectedTab)

            impactSideFilter
                .frame(width: 58)
        }
    }

    private var impactSideFilter: some View {
        VStack(spacing: 4) {
            ForEach(Array(ImpactSubTab.allCases.enumerated()), id: \.element) { index, tab in
                let isSelected = selectedTab == tab
                let label = filterLabels[index]

                Button {
                    UISelectionFeedbackGenerator().selectionChanged()
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(label)
                        .font(.system(size: 9, weight: isSelected ? .heavy : .medium))
                        .foregroundColor(isSelected ? Color(hex: "1A1A1A") : Color(hex: "AAAAAA"))
                        .frame(width: 44, height: 62)
                        .background {
                            if isSelected {
                                Capsule().fill(Color(hex: "FFE68C"))
                                    .shadow(color: Color(hex: "FFE68C").opacity(0.4), radius: 4, y: 2)
                            } else {
                                Capsule().fill(Color.clear)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color(hex: "F5F5F5"))
        .clipShape(RoundedRectangle(cornerRadius: 25))
        .padding(.top, 120)
        .animation(.easeInOut(duration: 0.3), value: selectedTab)
        .accessibilityLabel(Text(verbatim: L10n.t("club.impact_tabs.accessibility.label")))
    }
}

#Preview("Impact Container RTL") {
    ImpactContainerView(winsStore: WinsStore())
        .environment(\.layoutDirection, .rightToLeft)
}
