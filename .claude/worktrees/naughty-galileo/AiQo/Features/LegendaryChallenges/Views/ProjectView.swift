import SwiftUI

// MARK: - Project View (Active project tracking)

struct ProjectView: View {
    @ObservedObject var viewModel: LegendaryChallengesViewModel
    let project: LegendaryProject

    @State private var checkpointInput: String = ""
    @State private var showCheckpointConfirmation = false

    private var record: LegendaryRecord? {
        viewModel.record(for: project)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                projectHeaderCard
                weeklyPlanSection
                weeklyCheckpointCard
                captainMotivationCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .background(Color.white.ignoresSafeArea())
        .navigationTitle(NSLocalizedString("project.title", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.layoutDirection, .rightToLeft)
    }

    // MARK: - Project Header Card

    // DESIGN: Sand background, rounded, with progress arc and week info
    private var projectHeaderCard: some View {
        VStack(spacing: 16) {
            if let record {
                Text(record.titleAr)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.primary)

                // Progress ring
                ZStack {
                    Circle()
                        .stroke(Color.primary.opacity(0.08), lineWidth: 8)

                    Circle()
                        .trim(from: 0, to: project.progressFraction)
                        .stroke(GymTheme.mint, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 2) {
                        Text("\(Int(project.progressFraction * 100))%")
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.primary)

                        Text(String(format: NSLocalizedString("project.weekOf", comment: ""), project.currentWeek, project.targetWeeks))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.primary.opacity(0.45))
                    }
                }
                .frame(width: 120, height: 120)

                // Personal best vs target
                HStack(spacing: 20) {
                    VStack(spacing: 4) {
                        Text(NSLocalizedString("project.bestPerformance", comment: ""))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.primary.opacity(0.45))
                        Text("\(formatValue(project.personalBest)) \(record.unit)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.primary)
                    }

                    Rectangle()
                        .fill(Color.primary.opacity(0.1))
                        .frame(width: 1, height: 30)

                    VStack(spacing: 4) {
                        Text(NSLocalizedString("project.goal", comment: ""))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.primary.opacity(0.45))
                        Text("\(record.formattedTarget) \(record.unit)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(GymTheme.mint)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(GymTheme.beige.opacity(0.2))
        )
    }

    // MARK: - Weekly Plan Section

    private var weeklyPlanSection: some View {
        VStack(alignment: .trailing, spacing: 12) {
            Text(NSLocalizedString("project.weekPlan", comment: ""))
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.primary)

            ForEach(project.dailyTasks) { task in
                taskRow(task)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    // DESIGN: Task row with checkmark circle, matching existing خطة اليوم style
    private func taskRow(_ task: DailyTask) -> some View {
        Button {
            viewModel.toggleTask(task.id)
        } label: {
            HStack(spacing: 12) {
                // Checkmark circle
                ZStack {
                    Circle()
                        .stroke(task.isCompleted ? GymTheme.mint : Color.primary.opacity(0.15), lineWidth: 2)
                        .frame(width: 24, height: 24)

                    if task.isCompleted {
                        Circle()
                            .fill(GymTheme.mint)
                            .frame(width: 24, height: 24)

                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }

                Spacer()

                // Task info
                VStack(alignment: .trailing, spacing: 3) {
                    Text(task.titleAr)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(task.isCompleted ? Color.primary.opacity(0.4) : Color.primary)
                        .strikethrough(task.isCompleted, color: Color.primary.opacity(0.3))

                    Text(task.targetValue)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.4))
                }

                // Day number
                Text(String(format: NSLocalizedString("project.dayNumber", comment: ""), task.dayNumber))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary.opacity(0.35))
                    .frame(width: 40)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(task.isCompleted ? GymTheme.mint.opacity(0.08) : Color(hex: "F7F7F7"))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Weekly Checkpoint Card

    // DESIGN: Appears once per week — user logs their current attempt
    private var weeklyCheckpointCard: some View {
        VStack(alignment: .trailing, spacing: 12) {
            Text(NSLocalizedString("project.weekMeasure", comment: ""))
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.primary)

            if let record {
                Text(String(format: NSLocalizedString("project.howMuch", comment: ""), record.unit))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.55))
            }

            HStack(spacing: 12) {
                Button {
                    if let value = Double(checkpointInput) {
                        viewModel.logCheckpoint(weekNumber: project.currentWeek, value: value)
                        checkpointInput = ""
                        showCheckpointConfirmation = true

                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            showCheckpointConfirmation = false
                        }
                    }
                } label: {
                    Text(NSLocalizedString("project.record", comment: ""))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.primary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(GymTheme.mint.opacity(0.4))
                        )
                }
                .buttonStyle(.plain)

                TextField(NSLocalizedString("project.numberPlaceholder", comment: ""), text: $checkpointInput)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(hex: "F2F2F2"))
                    )
            }

            if showCheckpointConfirmation {
                Text(NSLocalizedString("project.recorded", comment: ""))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(GymTheme.mint)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(GymTheme.beige.opacity(0.15))
        )
    }

    // MARK: - Captain Motivation Card

    // DESIGN: Small card with captain avatar + motivational message
    private var captainMotivationCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "bubble.left.fill")
                .font(.system(size: 14))
                .foregroundStyle(GymTheme.mint)

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(NSLocalizedString("project.captainHamoudi", comment: ""))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary.opacity(0.5))

                Text(motivationalMessage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.7))
                    .multilineTextAlignment(.trailing)
                    .lineSpacing(3)
            }

            // Captain avatar placeholder
            Circle()
                .fill(GymTheme.beige.opacity(0.4))
                .frame(width: 40, height: 40)
                .overlay(
                    Text("🏋️")
                        .font(.system(size: 18))
                )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(hex: "F7F7F7"))
        )
    }

    // MARK: - Helpers

    private var motivationalMessage: String {
        let week = project.currentWeek
        if week <= 2 {
            return "بداية قوية! خلّك ملتزم بالخطة وبتشوف الفرق بسرعة 💪"
        } else if project.progressFraction > 0.5 {
            return "نص الطريق وأنت ماشي صح! كمّل ولا تلتفت 🔥"
        } else {
            return "كل يوم تتمرن فيه هو خطوة للأمام. ثق بالعملية 🚀"
        }
    }

    private func formatValue(_ value: Double) -> String {
        if value == value.rounded() {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }
}

#Preview {
    NavigationStack {
        ProjectView(
            viewModel: LegendaryChallengesViewModel(),
            project: LegendaryProject(
                id: "preview",
                recordId: "pushup_1min",
                startDate: Date().addingTimeInterval(-14 * 86400),
                targetWeeks: 16,
                weeklyCheckpoints: [],
                dailyTasks: [
                    DailyTask(id: "1", dayNumber: 1, titleAr: "إحماء + ضغط", targetValue: "3 مجاميع × 10", isCompleted: true),
                    DailyTask(id: "2", dayNumber: 2, titleAr: "تمارين مساعدة", targetValue: "3 مجاميع × 12", isCompleted: false),
                ],
                personalBest: 45,
                isCompleted: false
            )
        )
    }
    .environment(\.layoutDirection, .rightToLeft)
}
