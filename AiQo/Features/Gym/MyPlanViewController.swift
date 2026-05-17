import SwiftUI

// =========================
// File: Features/Gym/MyPlanView.swift
// Thin entry surface for the Plan tab.
//
// The legacy sample content — "نظرة عامة" (hardcoded steps/calories/water
// stats), "تمارين اليوم" (hardcoded push-ups/squats/plank), and
// "قوالب التمارين" (manual template list) — was removed. It was static
// placeholder data with no persistence and predated the Captain plan
// flow. The real, world-class plan experience lives in
// `WorkoutPlanDashboard`, reached through the entry card below.
// =========================

// MARK: - My Plan View
struct MyPlanView: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.t("plan.title"))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .padding(.top, 18)

                workoutPlanEntryCard
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 40)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
    }

    private var workoutPlanEntryCard: some View {
        NavigationLink {
            WorkoutPlanDashboard()
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text("🏋️‍♂️")
                            .font(.system(size: 24))

                        Text(L10n.t("gym.myplan.title"))
                            .font(.system(size: 21, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                    }

                    Text(L10n.t("gym.myplan.subtitle"))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 6)

                Image(systemName: "chevron.left.circle.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.75))
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.97, green: 0.84, blue: 0.64), Color(red: 0.97, green: 0.84, blue: 0.64).opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
            .environment(\.colorScheme, .light)
        }
        .buttonStyle(.plain)
        .padding(.top, 10)
    }
}

// MARK: - Preview
#Preview {
    MyPlanView()
}
