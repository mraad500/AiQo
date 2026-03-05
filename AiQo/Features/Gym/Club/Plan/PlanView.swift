import SwiftUI

struct PlanView: View {
    @State private var railSelection = 0

    private let contentTrailingPadding: CGFloat = ClubChromeLayout.contentTrailingPadding

    private var railItems: [RailItem] {
        [
            RailItem(
                id: "plan_day",
                title: "اليوم",
                icon: "sun.max",
                tint: AiQoColors.beige
            ),
            RailItem(
                id: "plan_month",
                title: "الشهر",
                icon: "calendar",
                tint: AiQoColors.mint
            ),
            RailItem(
                id: "plan_year",
                title: "السنة",
                icon: "sparkles",
                tint: AiQoColors.beige
            )
        ]
    }

    var body: some View {
        ZStack {
            MyPlanView()
                .padding(.trailing, contentTrailingPadding)

            SlimRightSideRail(
                items: railItems,
                selection: $railSelection
            )
            .accessibilityLabel(Text("فلاتر الخطة"))
        }
    }
}
