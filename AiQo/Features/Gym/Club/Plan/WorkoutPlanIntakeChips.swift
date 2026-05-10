import SwiftUI

// MARK: - Intake selections

enum PlanIntakeGoal: String, CaseIterable, Identifiable {
    case buildMuscle, cutFat, generalFitness, mobility, eventPrep
    var id: String { rawValue }

    var arabicLabel: String {
        switch self {
        case .buildMuscle: "زيادة عضل"
        case .cutFat: "تنشيف"
        case .generalFitness: "لياقة عامة"
        case .mobility: "مرونة وعلاج"
        case .eventPrep: "تجهيز لحدث"
        }
    }

    var englishLabel: String {
        switch self {
        case .buildMuscle: "Build muscle"
        case .cutFat: "Cut fat"
        case .generalFitness: "General fitness"
        case .mobility: "Mobility & recovery"
        case .eventPrep: "Event prep"
        }
    }

    var icon: String {
        switch self {
        case .buildMuscle: "figure.strengthtraining.traditional"
        case .cutFat: "flame.fill"
        case .generalFitness: "heart.fill"
        case .mobility: "figure.flexibility"
        case .eventPrep: "trophy.fill"
        }
    }

    var accent: Color {
        switch self {
        case .buildMuscle: Color(red: 0.55, green: 0.72, blue: 0.95)
        case .cutFat: Color(red: 0.96, green: 0.50, blue: 0.45)
        case .generalFitness: Color(red: 0.45, green: 0.83, blue: 0.78)
        case .mobility: Color(red: 0.85, green: 0.66, blue: 0.96)
        case .eventPrep: Color(red: 0.99, green: 0.78, blue: 0.45)
        }
    }
}

enum PlanIntakeLevel: String, CaseIterable, Identifiable {
    case beginner, intermediate, advanced
    var id: String { rawValue }

    var arabicLabel: String {
        switch self {
        case .beginner: "مبتدئ"
        case .intermediate: "متوسط"
        case .advanced: "متقدم"
        }
    }

    var englishLabel: String {
        switch self {
        case .beginner: "Beginner"
        case .intermediate: "Intermediate"
        case .advanced: "Advanced"
        }
    }

    var icon: String {
        switch self {
        case .beginner: "leaf.fill"
        case .intermediate: "flame.fill"
        case .advanced: "bolt.fill"
        }
    }
}

enum PlanIntakeDuration: Int, CaseIterable, Identifiable {
    case quick = 15
    case short = 30
    case medium = 45
    case long = 60
    var id: Int { rawValue }

    func label(arabic: Bool) -> String {
        arabic ? "\(rawValue) دقيقة" : "\(rawValue) min"
    }

    var icon: String {
        switch self {
        case .quick: "bolt.fill"
        case .short: "clock"
        case .medium: "stopwatch.fill"
        case .long: "hourglass"
        }
    }
}

enum PlanIntakeEquipment: String, CaseIterable, Identifiable {
    case bodyweight, dumbbells, fullGym
    var id: String { rawValue }

    var arabicLabel: String {
        switch self {
        case .bodyweight: "بدون معدّات"
        case .dumbbells: "دامبل بس"
        case .fullGym: "نادي كامل"
        }
    }

    var englishLabel: String {
        switch self {
        case .bodyweight: "Bodyweight only"
        case .dumbbells: "Dumbbells only"
        case .fullGym: "Full gym"
        }
    }

    var icon: String {
        switch self {
        case .bodyweight: "figure.stand"
        case .dumbbells: "dumbbell.fill"
        case .fullGym: "building.2.fill"
        }
    }
}

struct PlanIntakeSelection {
    var goal: PlanIntakeGoal?
    var level: PlanIntakeLevel?
    var duration: PlanIntakeDuration?
    var equipment: PlanIntakeEquipment?

    var isComplete: Bool {
        goal != nil && level != nil && duration != nil && equipment != nil
    }

    func composedMessage(language: AppLanguage) -> String {
        let isArabic = language == .arabic
        let goalText = isArabic ? (goal?.arabicLabel ?? "") : (goal?.englishLabel ?? "")
        let levelText = isArabic ? (level?.arabicLabel ?? "") : (level?.englishLabel ?? "")
        let durationText = duration?.label(arabic: isArabic) ?? ""
        let equipmentText = isArabic ? (equipment?.arabicLabel ?? "") : (equipment?.englishLabel ?? "")

        if isArabic {
            return "أبني خطة تمرين شخصية: هدفي \(goalText)، مستواي \(levelText)، عندي \(durationText) باليوم، والمعدّات المتاحة \(equipmentText). اعطني خطة بتمارين واضحة بمجاميع وعدّات."
        }
        return "Build me a personalized workout plan. Goal: \(goalText). Level: \(levelText). Available time: \(durationText). Equipment: \(equipmentText). Give a clean plan with sets and reps."
    }
}

// MARK: - Intake chip flow view

struct PlanIntakeChipsView: View {
    @Binding var selection: PlanIntakeSelection
    let language: AppLanguage
    let onSubmit: () -> Void

    private var isArabic: Bool { language == .arabic }
    private var isComplete: Bool { selection.isComplete }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(red: 0.45, green: 0.83, blue: 0.78))
                Text(isArabic ? "اختر بسرعة، وارسلها لي" : "Pick fast — I'll handle the rest")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.4)
                Spacer(minLength: 0)
            }

            section(title: isArabic ? "الهدف" : "Goal") {
                wrap {
                    ForEach(PlanIntakeGoal.allCases) { goal in
                        chip(
                            isSelected: selection.goal == goal,
                            icon: goal.icon,
                            text: isArabic ? goal.arabicLabel : goal.englishLabel,
                            tint: goal.accent
                        ) {
                            selection.goal = goal
                        }
                    }
                }
            }

            section(title: isArabic ? "المستوى" : "Level") {
                wrap {
                    ForEach(PlanIntakeLevel.allCases) { level in
                        chip(
                            isSelected: selection.level == level,
                            icon: level.icon,
                            text: isArabic ? level.arabicLabel : level.englishLabel,
                            tint: Color(red: 0.66, green: 0.86, blue: 0.50)
                        ) {
                            selection.level = level
                        }
                    }
                }
            }

            section(title: isArabic ? "الوقت المتاح" : "Available time") {
                wrap {
                    ForEach(PlanIntakeDuration.allCases) { duration in
                        chip(
                            isSelected: selection.duration == duration,
                            icon: duration.icon,
                            text: duration.label(arabic: isArabic),
                            tint: Color(red: 0.55, green: 0.72, blue: 0.95)
                        ) {
                            selection.duration = duration
                        }
                    }
                }
            }

            section(title: isArabic ? "المعدّات" : "Equipment") {
                wrap {
                    ForEach(PlanIntakeEquipment.allCases) { equipment in
                        chip(
                            isSelected: selection.equipment == equipment,
                            icon: equipment.icon,
                            text: isArabic ? equipment.arabicLabel : equipment.englishLabel,
                            tint: Color(red: 0.85, green: 0.66, blue: 0.96)
                        ) {
                            selection.equipment = equipment
                        }
                    }
                }
            }

            Button(action: onSubmit) {
                HStack(spacing: 8) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 14, weight: .heavy))
                    Text(isComplete
                         ? (isArabic ? "اطلب الخطة من الكابتن" : "Generate my plan")
                         : (isArabic ? "اختر الباقي حتى أبدأ" : "Pick the rest to begin"))
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: isComplete
                                    ? [Color(red: 0.45, green: 0.83, blue: 0.78), Color(red: 0.55, green: 0.72, blue: 0.95)]
                                    : [Color.gray.opacity(0.6), Color.gray.opacity(0.5)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .shadow(
                    color: (isComplete ? Color(red: 0.45, green: 0.83, blue: 0.78) : Color.gray).opacity(0.3),
                    radius: 12,
                    y: 6
                )
            }
            .buttonStyle(.plain)
            .disabled(!isComplete)
            .padding(.top, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.55), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.07), radius: 14, y: 7)
    }

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            content()
        }
    }

    private func chip(isSelected: Bool, icon: String, text: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .heavy))
                Text(text)
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? .white : tint)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(
                        isSelected
                            ? AnyShapeStyle(LinearGradient(colors: [tint, tint.opacity(0.78)], startPoint: .leading, endPoint: .trailing))
                            : AnyShapeStyle(tint.opacity(0.12))
                    )
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(tint.opacity(isSelected ? 0 : 0.4), lineWidth: 1)
            )
            .shadow(color: tint.opacity(isSelected ? 0.4 : 0), radius: 7, y: 3)
        }
        .buttonStyle(.plain)
    }

    private func wrap<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        FlowLayout(spacing: 7) {
            content()
        }
    }
}

// MARK: - FlowLayout — wrapping HStack used for chip groups

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widestRow: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth {
                widestRow = max(widestRow, rowWidth - spacing)
                totalHeight += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        widestRow = max(widestRow, rowWidth - spacing)
        totalHeight += rowHeight
        return CGSize(width: widestRow, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
