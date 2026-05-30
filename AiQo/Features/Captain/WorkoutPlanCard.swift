import SwiftUI

/// Premium workout-plan card surfaced inside the Captain chat whenever the
/// model returns a structured `workoutPlan`. Replaces the v1 chip-grid
/// teaser that read like marketing copy with a full day-by-day, exercise-
/// by-exercise view the user can actually train from.
///
/// Design contract:
///   - The `message` bubble carries the warm intro (≤5 lines) — never the
///     exercise list. The card owns the details.
///   - Every exercise row shows name + sets × reps/duration in a single
///     glanceable line. Monospaced digits keep "4 × 8-10" tightly aligned
///     even with mixed-script labels.
///   - Multi-day plans render every day as its own section; flat plans
///     fall back to a single exercise list.
///   - The CTA at the bottom hands navigation back to the caller. We don't
///     hard-code the runner route here because the same card ships from
///     several screens (main chat, plan flow, Peaks) and they each want a
///     different destination.
struct WorkoutPlanCard: View {
    let plan: WorkoutPlan
    /// Tapped by the user when they want to start training right now. The
    /// caller owns the destination (e.g. the Club's workout runner).
    var onStartTap: (() -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme

    private var isArabic: Bool {
        AppSettingsStore.shared.appLanguage == .arabic
    }

    private var hasDays: Bool {
        (plan.days?.isEmpty == false)
    }

    private var weekBadgeText: String? {
        guard let weeks = plan.durationWeeks, weeks > 1 else { return nil }
        if isArabic {
            return weeks == 2 ? "أسبوعين"
                : weeks <= 10 ? "\(weeks) أسابيع"
                : "\(weeks) أسبوع"
        }
        return "\(weeks) weeks"
    }

    private var startButtonTitle: String {
        isArabic ? "ابدأ التمرين" : "Start Workout"
    }

    private var exercisesSectionTitle: String {
        isArabic ? "التمارين" : "Exercises"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            divider
            content
            divider
            startButton
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(borderGradient, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 8)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "FFF2B5"), Color(hex: "CFF7EC")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: "57411D"))
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(isArabic ? "خطة التمرين" : "Workout Plan")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(AiQoTheme.Colors.textSecondary)
                Text(plan.title.isEmpty
                     ? (isArabic ? "خطة مخصصة من الكابتن" : "Custom plan from Captain")
                     : plan.title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(AiQoTheme.Colors.textPrimary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            if let weekBadgeText {
                Text(weekBadgeText)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(hex: "57411D"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color(hex: "FFF2B5").opacity(0.7))
                    )
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 14)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if let days = plan.days, !days.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                    daySection(day, index: index + 1)
                    if index < days.count - 1 {
                        Rectangle()
                            .fill(Color.white.opacity(0.45))
                            .frame(height: 0.5)
                            .padding(.horizontal, 18)
                    }
                }
            }
            .padding(.vertical, 4)
        } else {
            flatExerciseSection
        }
    }

    private func daySection(_ day: WorkoutDay, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(dayIndexLabel(index))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: "57411D"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color(hex: "FFF2B5").opacity(0.85))
                    )
                Text(day.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(AiQoTheme.Colors.textPrimary)
                    .lineLimit(2)
                Spacer(minLength: 0)
            }

            if let focus = day.focus, !focus.isEmpty {
                Text(focus)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(AiQoTheme.Colors.textSecondary)
            }

            VStack(spacing: 6) {
                ForEach(day.exercises) { exercise in
                    exerciseRow(exercise)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var flatExerciseSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(exercisesSectionTitle)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(AiQoTheme.Colors.textSecondary)

            VStack(spacing: 6) {
                ForEach(plan.exercises) { exercise in
                    exerciseRow(exercise)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func exerciseRow(_ exercise: Exercise) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(exercise.name)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(AiQoTheme.Colors.textPrimary)
                .lineLimit(2)
            Spacer(minLength: 8)
            Text(setsRepsLabel(exercise))
                .font(.system(.footnote, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundStyle(AiQoTheme.Colors.textPrimary.opacity(0.78))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.55))
                )
                .environment(\.layoutDirection, .leftToRight)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func setsRepsLabel(_ exercise: Exercise) -> String {
        "\(exercise.sets) × \(exercise.repsOrDuration)"
    }

    private func dayIndexLabel(_ index: Int) -> String {
        isArabic ? "يوم \(index)" : "Day \(index)"
    }

    // MARK: - Start button

    private var startButton: some View {
        Button {
            onStartTap?()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                Text(startButtonTitle)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
            }
            .foregroundStyle(Color(hex: "0F1721"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [
                        Color(hex: "C4F0DB"),
                        Color(hex: "F8D6A3")
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .opacity(0.92)
            )
        }
        .buttonStyle(.plain)
        .disabled(onStartTap == nil)
        .opacity(onStartTap == nil ? 0.6 : 1)
    }

    // MARK: - Visual primitives

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.55))
            .frame(height: 0.5)
    }

    private var cardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "FFF7E1").opacity(colorScheme == .dark ? 0.10 : 0.55),
                            Color(hex: "DDF7E9").opacity(colorScheme == .dark ? 0.08 : 0.45)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }

    private var borderGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.78),
                Color.aiqoMint.opacity(0.34),
                Color.aiqoLemon.opacity(0.28)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
