import SwiftUI

struct PlanView: View {
    @EnvironmentObject private var globalBrain: CaptainViewModel
    @State private var railSelection = 0
    @State private var activeRecordProject: RecordProject?
    @State private var navigateToRecordProject = false

    private let periods = ["اليوم", "الشهر", "السنة"]

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // بطاقة مشروع كسر الرقم المثبتة
                    if let project = activeRecordProject, project.isPinnedToPlan {
                        pinnedRecordProjectCard(project)
                            .padding(.horizontal, 12)
                            .padding(.top, 10)
                    }

                    if let plan = globalBrain.currentWorkoutPlan {
                        CaptainLiveWorkoutPlanCard(plan: plan)
                            .padding(.horizontal, 12)
                            .padding(.top, 10)
                    }

                    MyPlanView()
                }
            }

            planSideFilter
                .frame(width: 58)
        }
        .onAppear {
            activeRecordProject = RecordProjectManager.shared.activeProject()
        }
        .navigationDestination(isPresented: $navigateToRecordProject) {
            if let project = activeRecordProject {
                RecordProjectView(project: project)
            }
        }
    }

    // MARK: - بطاقة المشروع المثبتة

    private func pinnedRecordProjectCard(_ project: RecordProject) -> some View {
        Button {
            navigateToRecordProject = true
        } label: {
            HStack(spacing: 14) {
                // Progress ring صغير
                ZStack {
                    Circle()
                        .stroke(Color.primary.opacity(0.08), lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: project.progressFraction)
                        .stroke(GymTheme.mint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(project.progressFraction * 100))%")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("🏆")
                            .font(.system(size: 12))
                        Text("مشروع كسر الرقم")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    Text(project.recordTitle)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text("الأسبوع \(project.currentWeek) من \(project.totalWeeks)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(GymTheme.mint.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(GymTheme.mint.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var planSideFilter: some View {
        VStack(spacing: 4) {
            ForEach(Array(periods.enumerated()), id: \.element) { index, period in
                let isSelected = railSelection == index

                Button {
                    UISelectionFeedbackGenerator().selectionChanged()
                    withAnimation(.easeInOut(duration: 0.3)) {
                        railSelection = index
                    }
                } label: {
                    Text(period)
                        .font(.system(size: 11, weight: isSelected ? .heavy : .medium))
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
        .animation(.easeInOut(duration: 0.3), value: railSelection)
        .accessibilityLabel(Text("فلاتر الخطة"))
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
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.97, green: 0.84, blue: 0.64), Color(red: 0.97, green: 0.84, blue: 0.64).opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .shadow(color: Color.black.opacity(0.04), radius: 2, y: 1)
    }
}
