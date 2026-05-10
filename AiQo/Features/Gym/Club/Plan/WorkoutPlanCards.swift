import SwiftUI

// MARK: - Active Plan Card
// Rich card shown when a workout plan is pinned. Highlights the plan's
// title, derived badges (duration/difficulty/equipment), and per-exercise
// completion checkboxes wired to the SwiftData `WorkoutTask` rows.

struct ActivePlanCard: View {
    let plan: WorkoutPlan
    let language: AppLanguage
    /// Pre-computed completion states keyed by zero-based exercise index.
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
        VStack(alignment: .leading, spacing: 16) {
            header
            badgeStrip
            progressRow
            startWorkoutButton
            divider
            exerciseList
            footerActions
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.97, green: 0.84, blue: 0.64).opacity(0.55),
                                    Color(red: 0.77, green: 0.94, blue: 0.86).opacity(0.55)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.85),
                                    Color.white.opacity(0.35)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.07), radius: 16, x: 0, y: 8)
        )
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.55), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: max(progress, 0.001))
                    .stroke(
                        LinearGradient(
                            colors: allDone
                                ? [Color(red: 0.45, green: 0.83, blue: 0.78), Color(red: 0.66, green: 0.86, blue: 0.50)]
                                : [Color(red: 0.55, green: 0.72, blue: 0.95), Color(red: 0.45, green: 0.83, blue: 0.78)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)

                Image(systemName: allDone ? "checkmark" : "sparkles")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(allDone ? Color(red: 0.45, green: 0.83, blue: 0.78) : Color(red: 0.36, green: 0.27, blue: 0.16))
            }
            .frame(width: 52, height: 52)
            .shadow(color: .black.opacity(0.08), radius: 6, y: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(isArabic ? "خطة الكابتن" : "Captain's plan")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.6)

                Text(plan.title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 4)

            Menu {
                Button {
                    onRefresh()
                } label: {
                    Label(isArabic ? "حدّث الخطة" : "Refresh plan", systemImage: "arrow.clockwise")
                }
                Button {
                    onShare()
                } label: {
                    Label(isArabic ? "شارك" : "Share", systemImage: "square.and.arrow.up")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(.primary)
                    .padding(8)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
    }

    private var badgeStrip: some View {
        HStack(spacing: 8) {
            badgePill(
                icon: "clock.fill",
                text: "\(insights.prettyDuration) \(isArabic ? "د" : "min")",
                tint: Color(red: 0.45, green: 0.83, blue: 0.78)
            )

            badgePill(
                icon: difficultyIcon,
                text: isArabic ? insights.difficulty.arabicLabel : insights.difficulty.englishLabel,
                tint: insights.difficulty.accent
            )

            if let firstMuscle = insights.primaryMuscleGroups.first {
                badgePill(
                    icon: firstMuscle.icon,
                    text: isArabic ? firstMuscle.arabicLabel : firstMuscle.englishLabel,
                    tint: firstMuscle.accent
                )
            }

            if let firstEquipment = insights.equipmentNeeded.first {
                badgePill(
                    icon: firstEquipment.icon,
                    text: isArabic ? firstEquipment.arabicLabel : firstEquipment.englishLabel,
                    tint: Color(red: 0.65, green: 0.74, blue: 0.92)
                )
            }
        }
    }

    private func badgePill(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .heavy))
            Text(text)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .foregroundStyle(.white)
        .background(
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.95), tint.opacity(0.78)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .shadow(color: tint.opacity(0.35), radius: 5, y: 2)
    }

    private var progressRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(isArabic ? "تقدّم اليوم" : "Today's progress")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.4)

                Spacer()

                Text("\(completedCount)/\(plan.exercises.count)")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.5))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.45, green: 0.83, blue: 0.78),
                                    Color(red: 0.66, green: 0.86, blue: 0.50)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, proxy.size.width * progress))
                        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: progress)
                }
            }
            .frame(height: 8)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.55))
            .frame(height: 1)
            .padding(.vertical, 2)
    }

    private var startWorkoutButton: some View {
        Button(action: onStartWorkout) {
            HStack(spacing: 8) {
                Image(systemName: allDone ? "arrow.clockwise.circle.fill" : "play.fill")
                    .font(.system(size: 15, weight: .heavy))
                Text(allDone
                     ? (isArabic ? "أعد التمرين" : "Run it again")
                     : (isArabic ? "ابدأ التمرين الآن" : "Start workout"))
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: allDone
                                ? [Color(red: 0.66, green: 0.86, blue: 0.50), Color(red: 0.45, green: 0.83, blue: 0.78)]
                                : [Color(red: 0.45, green: 0.83, blue: 0.78), Color(red: 0.55, green: 0.72, blue: 0.95)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .shadow(color: Color(red: 0.45, green: 0.83, blue: 0.78).opacity(0.45), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
    }

    private var exerciseList: some View {
        VStack(spacing: 8) {
            ForEach(Array(plan.exercises.enumerated()), id: \.offset) { index, exercise in
                ActivePlanExerciseRow(
                    exercise: exercise,
                    isCompleted: completionByIndex[index] ?? false,
                    language: language,
                    onTap: { onTapExercise(exercise) },
                    onToggle: { onToggleCompletion(index) }
                )
            }
        }
    }

    private var footerActions: some View {
        HStack(spacing: 10) {
            actionPill(
                icon: "arrow.clockwise",
                title: isArabic ? "خطة جديدة" : "New plan",
                tint: Color(red: 0.55, green: 0.72, blue: 0.95),
                action: onRefresh
            )

            actionPill(
                icon: "square.and.arrow.up",
                title: isArabic ? "شارك" : "Share",
                tint: Color(red: 0.96, green: 0.62, blue: 0.50),
                action: onShare
            )
        }
    }

    private func actionPill(icon: String, title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .heavy))
                Text(title)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.55))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(tint.opacity(0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var difficultyIcon: String {
        switch insights.difficulty {
        case .beginner: "leaf.fill"
        case .intermediate: "flame.fill"
        case .advanced: "bolt.fill"
        }
    }
}

// MARK: - Single exercise row used in the active plan card

private struct ActivePlanExerciseRow: View {
    let exercise: Exercise
    let isCompleted: Bool
    let language: AppLanguage
    let onTap: () -> Void
    let onToggle: () -> Void

    @State private var feedbackTrigger = 0

    private var insights: ExerciseInsights { exercise.insights(language: language) }
    private var isArabic: Bool { language == .arabic }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                feedbackTrigger += 1
                onToggle()
            } label: {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isCompleted ? insights.muscleGroup.accent : Color.primary.opacity(0.3))
                    .symbolEffect(.bounce, value: isCompleted)
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.success, trigger: feedbackTrigger)

            Button(action: onTap) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(insights.muscleGroup.accent.opacity(0.18))
                        Image(systemName: insights.muscleGroup.icon)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(insights.muscleGroup.accent)
                    }
                    .frame(width: 32, height: 32)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(exercise.name)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .strikethrough(isCompleted, color: .secondary)
                            .lineLimit(1)

                        HStack(spacing: 6) {
                            Text("\(exercise.sets) × \(exercise.repsOrDuration)")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)

                            Text("•")
                                .foregroundStyle(.secondary)

                            Image(systemName: "clock")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.secondary)

                            Text(prettyTime(insights.estimatedSeconds))
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer(minLength: 4)

                    Image(systemName: "info.circle")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(isCompleted ? 0.32 : 0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    isCompleted ? insights.muscleGroup.accent.opacity(0.4) : Color.white.opacity(0.45),
                    lineWidth: 1
                )
        )
        .opacity(isCompleted ? 0.78 : 1.0)
        .animation(.easeInOut(duration: 0.18), value: isCompleted)
    }

    private func prettyTime(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)\(isArabic ? "ث" : "s")"
        }
        let minutes = Int((Double(seconds) / 60).rounded())
        return "\(minutes)\(isArabic ? "د" : "m")"
    }
}

// MARK: - Pending plan preview card (shown inside Captain chat)

struct PendingPlanPreviewCard: View {
    let plan: WorkoutPlan
    let language: AppLanguage
    let onTapExercise: (Exercise) -> Void

    private var insights: WorkoutPlanInsights { plan.insights(language: language) }
    private var isArabic: Bool { language == .arabic }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.00, green: 0.93, blue: 0.72),
                                    Color(red: 0.77, green: 0.94, blue: 0.86)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "list.bullet.clipboard.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(red: 0.36, green: 0.27, blue: 0.16))
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text(isArabic ? "🎯 خطة جاهزة للتثبيت" : "🎯 Plan ready to pin")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.4)

                    Text(plan.title)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }
            }

            HStack(spacing: 6) {
                metaPill(
                    icon: "clock.fill",
                    text: "\(insights.prettyDuration) \(isArabic ? "د" : "min")"
                )

                metaPill(
                    icon: "repeat",
                    text: "\(plan.exercises.count) \(isArabic ? "تمارين" : "exercises")"
                )

                metaPill(
                    icon: "flame.fill",
                    text: isArabic ? insights.difficulty.arabicLabel : insights.difficulty.englishLabel
                )

                Spacer(minLength: 0)
            }

            VStack(spacing: 7) {
                ForEach(Array(plan.exercises.prefix(4).enumerated()), id: \.offset) { _, exercise in
                    Button {
                        onTapExercise(exercise)
                    } label: {
                        previewRow(for: exercise)
                    }
                    .buttonStyle(.plain)
                }

                if plan.exercises.count > 4 {
                    Text(String(format: isArabic ? "+%d تمارين إضافية" : "+%d more exercises", plan.exercises.count - 4))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.55), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.06), radius: 14, y: 6)
    }

    private func metaPill(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .heavy))
            Text(text)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.65))
        )
        .foregroundStyle(.primary.opacity(0.85))
    }

    private func previewRow(for exercise: Exercise) -> some View {
        let info = exercise.insights(language: language)
        return HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(info.muscleGroup.accent.opacity(0.22))
                Image(systemName: info.muscleGroup.icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(info.muscleGroup.accent)
            }
            .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text("\(exercise.sets) × \(exercise.repsOrDuration)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Image(systemName: "chevron.left")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .opacity(0.7)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.45))
        )
    }
}

// MARK: - Weekly progress strip

struct WeeklyProgressStrip: View {
    let days: [DayProgress]
    let language: AppLanguage

    private var isArabic: Bool { language == .arabic }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(isArabic ? "هاي الأسبوع" : "This week")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.4)

                Spacer()

                Text(streakLabel)
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(streakAccent)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(streakAccent.opacity(0.16))
                    )
            }

            HStack(spacing: 8) {
                ForEach(days) { day in
                    dayPill(day)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.45), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.06), radius: 10, y: 5)
    }

    private func dayPill(_ day: DayProgress) -> some View {
        VStack(spacing: 5) {
            Text(day.shortLabel)
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            ZStack {
                Circle()
                    .fill(day.tint.opacity(day.isToday ? 0.95 : 0.6))
                    .frame(width: 32, height: 32)

                if day.completionRatio > 0 {
                    Circle()
                        .trim(from: 0, to: day.completionRatio)
                        .stroke(
                            Color.white,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 32, height: 32)
                        .rotationEffect(.degrees(-90))
                }

                Image(systemName: day.symbol)
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(.white)
            }

            if day.isToday {
                Capsule()
                    .fill(Color(red: 0.45, green: 0.83, blue: 0.78))
                    .frame(width: 14, height: 3)
            } else {
                Capsule()
                    .fill(Color.clear)
                    .frame(width: 14, height: 3)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var streakDays: Int {
        var count = 0
        for day in days.reversed() {
            if day.completionRatio > 0 { count += 1 } else if !day.isUpcoming { break }
        }
        return count
    }

    private var streakLabel: String {
        let n = streakDays
        if n == 0 { return isArabic ? "ابدأ سلسلة جديدة" : "Start a new streak" }
        return isArabic ? "🔥 سلسلة \(n) أيام" : "🔥 \(n)-day streak"
    }

    private var streakAccent: Color {
        streakDays > 0 ? Color(red: 0.96, green: 0.50, blue: 0.20) : Color(red: 0.55, green: 0.55, blue: 0.62)
    }
}

struct DayProgress: Identifiable {
    let id: String
    let shortLabel: String
    let date: Date
    let completionRatio: Double  // 0...1
    let isToday: Bool
    let isUpcoming: Bool

    var symbol: String {
        if isUpcoming { return "circle.dashed" }
        if completionRatio >= 1.0 { return "checkmark" }
        if completionRatio > 0 { return "circle.lefthalf.filled" }
        if isToday { return "circle.fill" }
        return "circle"
    }

    var tint: Color {
        if completionRatio >= 1.0 { return Color(red: 0.45, green: 0.83, blue: 0.78) }
        if completionRatio > 0 { return Color(red: 0.95, green: 0.78, blue: 0.45) }
        if isToday { return Color(red: 0.55, green: 0.72, blue: 0.95) }
        if isUpcoming { return Color(red: 0.78, green: 0.78, blue: 0.84) }
        return Color(red: 0.67, green: 0.67, blue: 0.74)
    }
}
