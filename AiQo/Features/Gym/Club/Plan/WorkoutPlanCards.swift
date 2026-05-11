import SwiftUI

// MARK: - Active Plan Card
//
// World-class minimal layout — built on the AiQo brand palette only
// (mint, sand, lavender, lemon). Strict typography hierarchy, generous
// whitespace, hairline borders, no saturated shadows. The plan title +
// progress chip live up top; metadata reads as a calm row of brand-tinted
// text pills; exercises render as a clean numbered list; one primary CTA
// anchors the bottom.

struct ActivePlanCard: View {
    let plan: WorkoutPlan
    let language: AppLanguage
    let completionByIndex: [Int: Bool]
    let onToggleCompletion: (Int) -> Void
    let onTapExercise: (Exercise) -> Void
    let onStartWorkout: () -> Void
    let onRefresh: () -> Void
    let onShare: () -> Void

    private var insights: WorkoutPlanInsights { plan.insights(language: language) }
    private var isArabic: Bool { language == .arabic }
    private var completedCount: Int { completionByIndex.values.filter { $0 }.count }
    private var progress: Double {
        guard !plan.exercises.isEmpty else { return 0 }
        return Double(completedCount) / Double(plan.exercises.count)
    }
    private var allDone: Bool { progress >= 1.0 && !plan.exercises.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            metaRow
            divider
            exerciseList
            startButton
        }
        .padding(20)
        .background(cardSurface)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(isArabic ? "خطة اليوم" : "Today's plan")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)

                Text(plan.title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            ProgressChip(progress: progress, allDone: allDone, isArabic: isArabic)

            Menu {
                Button {
                    onRefresh()
                } label: {
                    Label(isArabic ? "خطة جديدة" : "New plan", systemImage: "arrow.clockwise")
                }
                Button {
                    onShare()
                } label: {
                    Label(isArabic ? "شارك" : "Share", systemImage: "square.and.arrow.up")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .background(
                        Circle()
                            .stroke(PlanPalette.hairline, lineWidth: 1)
                    )
            }
        }
    }

    // MARK: Meta row (text-driven, no fills)

    private var metaRow: some View {
        HStack(spacing: 18) {
            metaCell(
                value: "\(insights.prettyDuration)",
                unit: isArabic ? "د" : "min",
                label: isArabic ? "زمن" : "Time"
            )
            metaDivider
            metaCell(
                value: "\(plan.exercises.count)",
                unit: nil,
                label: isArabic ? "تمارين" : "moves"
            )
            metaDivider
            metaCell(
                value: "\(insights.totalSets)",
                unit: nil,
                label: isArabic ? "مجاميع" : "sets"
            )
            metaDivider
            metaCellLabel(
                value: isArabic ? insights.difficulty.arabicLabel : insights.difficulty.englishLabel,
                label: isArabic ? "مستوى" : "Level",
                ink: insights.difficulty.ink
            )
            Spacer(minLength: 0)
        }
    }

    private func metaCell(value: String, unit: String?, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)
                if let unit {
                    Text(unit)
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.4)
        }
    }

    private func metaCellLabel(value: String, label: String, ink: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(ink)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.4)
        }
    }

    private var metaDivider: some View {
        Rectangle()
            .fill(PlanPalette.hairline)
            .frame(width: 1, height: 28)
    }

    // MARK: Divider + exercise list

    private var divider: some View {
        Rectangle()
            .fill(PlanPalette.hairline)
            .frame(height: 1)
    }

    private var exerciseList: some View {
        VStack(spacing: 0) {
            ForEach(Array(plan.exercises.enumerated()), id: \.offset) { index, exercise in
                ActivePlanExerciseRow(
                    index: index,
                    exercise: exercise,
                    isCompleted: completionByIndex[index] ?? false,
                    language: language,
                    onTap: { onTapExercise(exercise) },
                    onToggle: { onToggleCompletion(index) }
                )
                if index < plan.exercises.count - 1 {
                    Rectangle()
                        .fill(PlanPalette.hairline)
                        .frame(height: 1)
                        .padding(.leading, 50)
                }
            }
        }
    }

    // MARK: Start CTA

    private var startButton: some View {
        Button(action: onStartWorkout) {
            HStack(spacing: 10) {
                Image(systemName: allDone ? "arrow.clockwise" : "play.fill")
                    .font(.system(size: 14, weight: .heavy))
                Text(allDone
                     ? (isArabic ? "أعد التمرين" : "Run it again")
                     : (isArabic ? "ابدأ التمرين" : "Start workout"))
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(PlanPalette.mintDeep)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                Capsule(style: .continuous)
                    .fill(PlanPalette.mint)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Card surface — beige base, subtle hairline border

    private var cardSurface: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        PlanPalette.sand.opacity(0.6),
                        PlanPalette.sand.opacity(0.4)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
            )
    }
}

// MARK: - Progress chip (compact, brand-tinted)

private struct ProgressChip: View {
    let progress: Double
    let allDone: Bool
    let isArabic: Bool

    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(PlanPalette.hairline, lineWidth: 3)
                Circle()
                    .trim(from: 0, to: max(progress, 0.001))
                    .stroke(
                        allDone ? PlanPalette.mintDeep : PlanPalette.mintDeep.opacity(0.85),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5, dampingFraction: 0.85), value: progress)
                if allDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(PlanPalette.mintDeep)
                }
            }
            .frame(width: 22, height: 22)

            Text("\(Int((progress * 100).rounded()))%")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(PlanPalette.mintDeep)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(PlanPalette.mint.opacity(0.55))
        )
    }
}

// MARK: - Single exercise row used in the active plan card

struct ActivePlanExerciseRow: View {
    let index: Int
    let exercise: Exercise
    let isCompleted: Bool
    let language: AppLanguage
    let onTap: () -> Void
    let onToggle: () -> Void

    @State private var feedbackTrigger = 0

    private var insights: ExerciseInsights { exercise.insights(language: language) }
    private var isArabic: Bool { language == .arabic }

    var body: some View {
        HStack(spacing: 14) {
            // Numbered ordinal — clean, brand-tinted on completion
            ZStack {
                Circle()
                    .fill(isCompleted ? PlanPalette.mint : Color.clear)
                Circle()
                    .stroke(
                        isCompleted ? PlanPalette.mint : PlanPalette.hairline,
                        lineWidth: 1.5
                    )
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(PlanPalette.mintDeep)
                } else {
                    Text("\(index + 1)")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 28, height: 28)

            // Tappable body — just text, no colored background
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(exercise.name)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .strikethrough(isCompleted, color: .secondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 8) {
                        Text("\(exercise.sets) × \(exercise.repsOrDuration)")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Text("•")
                            .font(.system(size: 12))
                            .foregroundStyle(PlanPalette.hairline)

                        Text(isArabic ? insights.muscleGroup.arabicLabel : insights.muscleGroup.englishLabel)
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundStyle(insights.muscleGroup.ink)
                            .textCase(.uppercase)
                            .tracking(0.4)
                    }
                }
            }
            .buttonStyle(.plain)
            .opacity(isCompleted ? 0.55 : 1.0)

            Spacer(minLength: 8)

            // Toggle — large tap target, calm visual weight
            Button {
                feedbackTrigger += 1
                onToggle()
            } label: {
                Image(systemName: isCompleted ? "circle.fill" : "circle")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(isCompleted ? PlanPalette.mintDeep : PlanPalette.hairline)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.success, trigger: feedbackTrigger)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .animation(.easeInOut(duration: 0.18), value: isCompleted)
    }
}

// MARK: - Pending plan preview card (chat-side)

struct PendingPlanPreviewCard: View {
    let plan: WorkoutPlan
    let language: AppLanguage
    let onTapExercise: (Exercise) -> Void

    private var insights: WorkoutPlanInsights { plan.insights(language: language) }
    private var isArabic: Bool { language == .arabic }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(isArabic ? "خطة جاهزة للتثبيت" : "Plan ready to pin")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(PlanPalette.mintDeep)
                    .textCase(.uppercase)
                    .tracking(0.6)

                Text(plan.title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }

            HStack(spacing: 14) {
                metaInline(value: "\(insights.prettyDuration)", unit: isArabic ? "د" : "min")
                metaDot
                metaInline(value: "\(plan.exercises.count)", unit: isArabic ? "تمارين" : "moves")
                metaDot
                Text(isArabic ? insights.difficulty.arabicLabel : insights.difficulty.englishLabel)
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(insights.difficulty.ink)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer(minLength: 0)
            }

            Rectangle()
                .fill(PlanPalette.hairline)
                .frame(height: 1)

            VStack(spacing: 0) {
                ForEach(Array(plan.exercises.prefix(5).enumerated()), id: \.offset) { idx, exercise in
                    Button {
                        onTapExercise(exercise)
                    } label: {
                        previewRow(index: idx, exercise: exercise)
                    }
                    .buttonStyle(.plain)
                    if idx < min(plan.exercises.count, 5) - 1 {
                        Rectangle()
                            .fill(PlanPalette.hairline)
                            .frame(height: 1)
                            .padding(.leading, 38)
                    }
                }

                if plan.exercises.count > 5 {
                    HStack {
                        Text(String(format: isArabic ? "+%d تمرين إضافي" : "+%d more", plan.exercises.count - 5))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.top, 10)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(PlanPalette.mint, lineWidth: 1.5)
                )
        )
    }

    private func metaInline(value: String, unit: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(.primary)
            Text(unit)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    private var metaDot: some View {
        Circle()
            .fill(PlanPalette.hairline)
            .frame(width: 3, height: 3)
    }

    private func previewRow(index: Int, exercise: Exercise) -> some View {
        let info = exercise.insights(language: language)
        return HStack(spacing: 12) {
            Text("\(index + 1)")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
                .background(
                    Circle().stroke(PlanPalette.hairline, lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text("\(exercise.sets) × \(exercise.repsOrDuration)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text(isArabic ? info.muscleGroup.arabicLabel : info.muscleGroup.englishLabel)
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(info.muscleGroup.ink)
                        .textCase(.uppercase)
                        .tracking(0.4)
                }
            }

            Spacer(minLength: 4)

            Image(systemName: "chevron.left")
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(PlanPalette.hairline)
        }
        .padding(.vertical, 10)
    }
}

// MARK: - Weekly progress strip

struct WeeklyProgressStrip: View {
    let days: [DayProgress]
    let language: AppLanguage

    private var isArabic: Bool { language == .arabic }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(isArabic ? "هاي الأسبوع" : "This week")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Spacer()

                if streakDays > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(PlanPalette.lemonDeep)
                        Text(isArabic ? "سلسلة \(streakDays) أيام" : "\(streakDays)-day streak")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundStyle(PlanPalette.lemonDeep)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous).fill(PlanPalette.lemon.opacity(0.55))
                    )
                }
            }

            HStack(spacing: 6) {
                ForEach(days) { day in
                    dayPill(day)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(PlanPalette.hairline, lineWidth: 1)
                )
        )
    }

    private func dayPill(_ day: DayProgress) -> some View {
        VStack(spacing: 6) {
            Text(day.shortLabel)
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(day.isToday ? PlanPalette.mintDeep : .secondary)
                .textCase(.uppercase)

            ZStack {
                Circle()
                    .fill(dayFill(day))
                Circle()
                    .stroke(dayStroke(day), lineWidth: day.isToday ? 1.5 : 1)

                if day.completionRatio >= 1 {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(PlanPalette.mintDeep)
                } else if day.completionRatio > 0 {
                    Circle()
                        .fill(PlanPalette.mintDeep)
                        .frame(width: 6, height: 6)
                } else if day.isToday {
                    Circle()
                        .fill(PlanPalette.mintDeep.opacity(0.4))
                        .frame(width: 5, height: 5)
                }
            }
            .frame(width: 30, height: 30)
        }
        .frame(maxWidth: .infinity)
    }

    private func dayFill(_ day: DayProgress) -> Color {
        if day.completionRatio >= 1 { return PlanPalette.mint }
        if day.completionRatio > 0 { return PlanPalette.mint.opacity(0.4) }
        if day.isToday { return PlanPalette.mint.opacity(0.18) }
        return Color.clear
    }

    private func dayStroke(_ day: DayProgress) -> Color {
        if day.isToday { return PlanPalette.mintDeep }
        if day.completionRatio >= 1 { return PlanPalette.mintDeep.opacity(0.4) }
        return PlanPalette.hairline
    }

    private var streakDays: Int {
        var count = 0
        for day in days.reversed() {
            if day.completionRatio > 0 { count += 1 } else if !day.isUpcoming { break }
        }
        return count
    }
}

struct DayProgress: Identifiable {
    let id: String
    let shortLabel: String
    let date: Date
    let completionRatio: Double
    let isToday: Bool
    let isUpcoming: Bool
}
