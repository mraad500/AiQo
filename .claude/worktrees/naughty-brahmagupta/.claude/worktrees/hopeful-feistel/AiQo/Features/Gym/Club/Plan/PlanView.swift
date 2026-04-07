import SwiftUI

struct PlanView: View {
    @EnvironmentObject private var globalBrain: CaptainViewModel
    @State private var railSelection = 0

    private let contentTrailingPadding: CGFloat = ClubChromeLayout.contentTrailingPadding - 14

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
                .safeAreaInset(edge: .top, spacing: 14) {
                    if let plan = globalBrain.currentWorkoutPlan {
                        CaptainLiveWorkoutPlanCard(plan: plan)
                            .padding(.leading, 12)
                            .padding(.trailing, contentTrailingPadding)
                            .padding(.top, 10)
                    }
                }

            SlimRightSideRail(
                items: railItems,
                selection: $railSelection
            )
            .accessibilityLabel(Text("فلاتر الخطة"))
        }
    }
}

private struct CaptainLiveWorkoutPlanCard: View {
    let plan: WorkoutPlan

    private var exerciseListHeight: CGFloat {
        let rowHeight: CGFloat = 82
        return min(max(CGFloat(plan.exercises.count) * rowHeight, 110), 320)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    AiQoColors.beige.opacity(0.92),
                                    AiQoColors.mint.opacity(0.82)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.black.opacity(0.72))
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Captain Hamoudi Plan")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Text(plan.title)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("التمارين المقترحة")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)

                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        ForEach(plan.exercises) { exercise in
                            HStack(alignment: .center, spacing: 14) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(exercise.name)
                                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.primary)

                                    Text(exercise.repsOrDuration)
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }

                                Spacer(minLength: 12)

                                Text("\(exercise.sets) Sets")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(.primary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(Color.white.opacity(0.32))
                                    )
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color.white.opacity(0.20))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                                            .stroke(Color.white.opacity(0.34), lineWidth: 1)
                                    )
                            )
                        }
                    }
                    .padding(.trailing, 4)
                }
                .frame(height: exerciseListHeight)
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.84),
                                    AiQoColors.beige.opacity(0.42),
                                    AiQoColors.mint.opacity(0.38)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 8)
    }
}
