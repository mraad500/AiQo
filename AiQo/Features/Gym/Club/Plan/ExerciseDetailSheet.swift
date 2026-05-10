import SwiftUI

struct ExerciseDetailSheet: View {
    let exercise: Exercise
    let language: AppLanguage

    @Environment(\.dismiss) private var dismiss

    private var insights: ExerciseInsights {
        exercise.insights(language: language)
    }

    private var muscleAccent: Color { insights.muscleGroup.accent }
    private var isArabic: Bool { language == .arabic }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                heroHeader
                badgeStrip

                section(
                    title: isArabic ? "نصايح الفورم" : "Form cues",
                    icon: "lightbulb.fill"
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(insights.formCues.enumerated()), id: \.offset) { _, cue in
                            cueRow(cue)
                        }
                    }
                }

                section(
                    title: isArabic ? "بدائل" : "Alternatives",
                    icon: "rectangle.stack.fill"
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(insights.alternatives.enumerated()), id: \.offset) { _, alt in
                            alternativeRow(alt)
                        }
                    }
                }

                section(
                    title: isArabic ? "إيقاع التمرين" : "Pacing",
                    icon: "metronome.fill"
                ) {
                    pacingGrid
                }
            }
            .padding(20)
        }
        .background(
            LinearGradient(
                colors: [
                    muscleAccent.opacity(0.16),
                    Color(.systemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(.primary)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .padding(16)
        }
    }

    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [muscleAccent.opacity(0.95), muscleAccent.opacity(0.55)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: insights.muscleGroup.icon)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 56, height: 56)
                .shadow(color: muscleAccent.opacity(0.45), radius: 12, x: 0, y: 6)

                VStack(alignment: .leading, spacing: 4) {
                    Text(isArabic ? insights.muscleGroup.arabicLabel : insights.muscleGroup.englishLabel)
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(muscleAccent.opacity(0.95))
                        .textCase(.uppercase)

                    Text(exercise.name)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 16)

            Text(exercise.repsOrDuration)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    private var badgeStrip: some View {
        HStack(spacing: 8) {
            badge(
                icon: "repeat",
                label: isArabic ? "مجاميع" : "Sets",
                value: "\(exercise.sets)"
            )

            badge(
                icon: "clock",
                label: isArabic ? "زمن تقريبي" : "Approx",
                value: prettyDuration(insights.estimatedSeconds)
            )

            badge(
                icon: "pause.circle",
                label: isArabic ? "راحة" : "Rest",
                value: "\(insights.restSeconds)\(isArabic ? "ث" : "s")"
            )

            badge(
                icon: insights.equipment.icon,
                label: isArabic ? "معدّات" : "Equip",
                value: isArabic ? insights.equipment.arabicLabel : insights.equipment.englishLabel
            )
        }
    }

    private func badge(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(muscleAccent)
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.42), lineWidth: 1)
                )
        )
    }

    private func section<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(muscleAccent)
                Text(title)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)
                    .textCase(.uppercase)
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.45), lineWidth: 1)
                )
        )
    }

    private func cueRow(_ cue: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(muscleAccent)
                .frame(width: 7, height: 7)
                .padding(.top, 7)
            Text(cue)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func alternativeRow(_ alt: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.triangle.swap")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(muscleAccent)
                .frame(width: 22, height: 22)
                .background(
                    Circle()
                        .fill(muscleAccent.opacity(0.18))
                )
            Text(alt)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
    }

    private var pacingGrid: some View {
        let primaryMuscle = isArabic ? insights.muscleGroup.arabicLabel : insights.muscleGroup.englishLabel
        let totalReps = exercise.sets

        return HStack(spacing: 10) {
            pacingCard(
                title: isArabic ? "الإجمالي" : "Total",
                value: prettyDuration(insights.estimatedSeconds)
            )
            pacingCard(
                title: isArabic ? "بين المجاميع" : "Between sets",
                value: "\(insights.restSeconds)\(isArabic ? "ث" : "s")"
            )
            pacingCard(
                title: isArabic ? "العضلة" : "Muscle",
                value: primaryMuscle
            )
            pacingCard(
                title: isArabic ? "المجاميع" : "Sets",
                value: "\(totalReps)"
            )
        }
    }

    private func pacingCard(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(muscleAccent.opacity(0.14))
        )
    }

    private func prettyDuration(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)\(isArabic ? "ث" : "s")"
        }
        let minutes = Int((Double(seconds) / 60).rounded())
        return "\(minutes)\(isArabic ? "د" : "m")"
    }
}
