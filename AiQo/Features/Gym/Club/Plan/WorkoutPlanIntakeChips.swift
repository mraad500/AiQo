import PhotosUI
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

    var family: PlanPalette.Family {
        switch self {
        case .buildMuscle: .sand
        case .cutFat: .lemon
        case .generalFitness: .mint
        case .mobility: .lavender
        case .eventPrep: .sand
        }
    }

    var accent: Color { family.pastel }
    var ink: Color { family.ink }
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

enum PlanIntakePlanLength: Int, CaseIterable, Identifiable {
    case oneWeek = 1
    case twoWeeks = 2
    case fourWeeks = 4
    case eightWeeks = 8
    var id: Int { rawValue }

    func label(arabic: Bool) -> String {
        if arabic {
            switch self {
            case .oneWeek: return "أسبوع"
            case .twoWeeks: return "أسبوعين"
            case .fourWeeks: return "٤ أسابيع"
            case .eightWeeks: return "٨ أسابيع"
            }
        }
        switch self {
        case .oneWeek: return "1 week"
        case .twoWeeks: return "2 weeks"
        case .fourWeeks: return "4 weeks"
        case .eightWeeks: return "8 weeks"
        }
    }

    var trainingDaysPerWeek: Int {
        switch self {
        case .oneWeek: return 3
        case .twoWeeks: return 4
        case .fourWeeks: return 4
        case .eightWeeks: return 5
        }
    }
}

struct PlanIntakeSelection {
    var goal: PlanIntakeGoal?
    var level: PlanIntakeLevel?
    var duration: PlanIntakeDuration?
    var equipment: PlanIntakeEquipment?
    var planLength: PlanIntakePlanLength?
    /// Optional body photo the user attached. Lives only in-memory for the
    /// duration of the intake flow — never written to disk. Cleared once the
    /// plan request is dispatched.
    var bodyImage: UIImage?

    var isComplete: Bool {
        goal != nil && level != nil && duration != nil && equipment != nil && planLength != nil
    }

    var hasBodyImage: Bool { bodyImage != nil }

    func composedMessage(language: AppLanguage) -> String {
        let isArabic = language == .arabic
        let goalText = isArabic ? (goal?.arabicLabel ?? "") : (goal?.englishLabel ?? "")
        let levelText = isArabic ? (level?.arabicLabel ?? "") : (level?.englishLabel ?? "")
        let durationText = duration?.label(arabic: isArabic) ?? ""
        let equipmentText = isArabic ? (equipment?.arabicLabel ?? "") : (equipment?.englishLabel ?? "")
        let lengthText = planLength?.label(arabic: isArabic) ?? ""
        let weeks = planLength?.rawValue ?? 1
        let daysPerWeek = planLength?.trainingDaysPerWeek ?? 3

        if isArabic {
            return "أبني خطة تمرين شخصية مدتها \(lengthText): هدفي \(goalText)، مستواي \(levelText)، عندي \(durationText) باليوم، والمعدّات المتاحة \(equipmentText). رجّع الخطة مقسّمة على \(daysPerWeek) أيام تدريب بالأسبوع، كل يوم بي اسم وتركيز عضلي وتمارين بمجاميع وعدّات واضحة. اعتبرها خطة لـ \(weeks) أسبوع."
        }
        return "Build me a personalized \(lengthText) workout plan. Goal: \(goalText). Level: \(levelText). Available time per session: \(durationText). Equipment: \(equipmentText). Return the plan split into \(daysPerWeek) training days per week — each day with a name, muscle focus, and exercises with explicit sets and reps. Plan length: \(weeks) week(s)."
    }
}

// MARK: - Intake chip flow view

struct PlanIntakeChipsView: View {
    @Binding var selection: PlanIntakeSelection
    let language: AppLanguage
    let onSubmit: () -> Void

    @State private var pickerItem: PhotosPickerItem?
    @State private var isLoadingImage = false

    private var isArabic: Bool { language == .arabic }
    private var isComplete: Bool { selection.isComplete }

    private let totalSteps = 5
    private var answeredCount: Int {
        [selection.goal != nil,
         selection.level != nil,
         selection.duration != nil,
         selection.planLength != nil,
         selection.equipment != nil].filter { $0 }.count
    }
    private var remainingCount: Int { max(totalSteps - answeredCount, 0) }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header
            progressBar
            goalSection
            levelSection
            sessionTimeSection
            planLengthSection
            equipmentSection
            bodyPhotoSection
            cta
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 18, x: 0, y: 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(PlanPalette.hairline, lineWidth: 1)
                )
        )
        .animation(.easeInOut(duration: 0.22), value: answeredCount)
    }

    // MARK: Sections (extracted to keep `body` cheap for the type-checker)

    private var goalSection: some View {
        sectionBlock(
            icon: "target",
            tint: .mint,
            title: isArabic ? "الهدف" : "Goal",
            answered: selection.goal != nil
        ) {
            wrap {
                ForEach(PlanIntakeGoal.allCases) { goal in
                    chip(
                        isSelected: selection.goal == goal,
                        text: isArabic ? goal.arabicLabel : goal.englishLabel,
                        family: goal.family
                    ) {
                        selection.goal = goal
                    }
                }
            }
        }
    }

    private var levelSection: some View {
        sectionBlock(
            icon: "chart.line.uptrend.xyaxis",
            tint: .lavender,
            title: isArabic ? "المستوى" : "Level",
            answered: selection.level != nil
        ) {
            wrap {
                ForEach(PlanIntakeLevel.allCases) { level in
                    chip(
                        isSelected: selection.level == level,
                        text: isArabic ? level.arabicLabel : level.englishLabel,
                        family: .mint
                    ) {
                        selection.level = level
                    }
                }
            }
        }
    }

    private var sessionTimeSection: some View {
        sectionBlock(
            icon: "clock.fill",
            tint: .sand,
            title: isArabic ? "الوقت بالجلسة" : "Per-session time",
            answered: selection.duration != nil
        ) {
            wrap {
                ForEach(PlanIntakeDuration.allCases) { duration in
                    chip(
                        isSelected: selection.duration == duration,
                        text: duration.label(arabic: isArabic),
                        family: .sand
                    ) {
                        selection.duration = duration
                    }
                }
            }
        }
    }

    private var planLengthSection: some View {
        sectionBlock(
            icon: "calendar",
            tint: .lemon,
            title: isArabic ? "مدة الخطة" : "Plan length",
            answered: selection.planLength != nil
        ) {
            wrap {
                ForEach(PlanIntakePlanLength.allCases) { length in
                    chip(
                        isSelected: selection.planLength == length,
                        text: length.label(arabic: isArabic),
                        family: .lemon
                    ) {
                        selection.planLength = length
                    }
                }
            }
        }
    }

    private var equipmentSection: some View {
        sectionBlock(
            icon: "dumbbell.fill",
            tint: .lavender,
            title: isArabic ? "المعدّات" : "Equipment",
            answered: selection.equipment != nil
        ) {
            wrap {
                ForEach(PlanIntakeEquipment.allCases) { equipment in
                    chip(
                        isSelected: selection.equipment == equipment,
                        text: isArabic ? equipment.arabicLabel : equipment.englishLabel,
                        family: .lavender
                    ) {
                        selection.equipment = equipment
                    }
                }
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(isArabic ? "ابنِ خطتك" : "Build your plan")
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Spacer(minLength: 8)

                Text("\(answeredCount)/\(totalSteps)")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(isComplete ? PlanPalette.mintDeep : .secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(isComplete ? PlanPalette.mint.opacity(0.6) : PlanPalette.surfaceTint)
                    )
            }

            Text(isArabic
                 ? "اختر الخيارات وكابتن حمّودي يبنيلك خطة بثواني"
                 : "Pick your options — Captain builds it in seconds")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Progress bar

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(index < answeredCount ? PlanPalette.mintDeep : PlanPalette.hairline)
                    .frame(height: 5)
            }
        }
    }

    // MARK: Primary CTA

    private var cta: some View {
        Button(action: onSubmit) {
            HStack(spacing: 9) {
                Image(systemName: isComplete ? "paperplane.fill" : "hand.tap.fill")
                    .font(.system(size: 14, weight: .heavy))
                Text(isComplete
                     ? (isArabic ? "اطلب الخطة من الكابتن" : "Generate my plan")
                     : (isArabic
                        ? "اختر \(remainingCount) بعد حتى أبدأ"
                        : "Pick \(remainingCount) more to begin"))
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(isComplete ? PlanPalette.mintDeep : PlanPalette.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Capsule(style: .continuous)
                    .fill(isComplete ? PlanPalette.mint : PlanPalette.surfaceTint)
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(isComplete ? Color.clear : PlanPalette.hairline, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!isComplete)
        .padding(.top, 2)
    }

    @ViewBuilder
    private var bodyPhotoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                sectionIcon("person.crop.rectangle.stack", tint: .lavender)
                Text(isArabic ? "صورة جسم" : "Body photo")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(isArabic ? "اختياري" : "optional")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(PlanPalette.lavenderDeep)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule(style: .continuous)
                            .fill(PlanPalette.lavender.opacity(0.35))
                    )
                Spacer(minLength: 0)
                if selection.hasBodyImage {
                    Button {
                        selection.bodyImage = nil
                        pickerItem = nil
                    } label: {
                        Text(isArabic ? "إزالة" : "Remove")
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundStyle(PlanPalette.lavenderDeep)
                    }
                    .buttonStyle(.plain)
                }
            }

            PhotosPicker(
                selection: $pickerItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                HStack(spacing: 12) {
                    if let image = selection.bodyImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 46, height: 46)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else if isLoadingImage {
                        ProgressView()
                            .frame(width: 46, height: 46)
                    } else {
                        Image(systemName: "plus.viewfinder")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(PlanPalette.lavenderDeep)
                            .frame(width: 46, height: 46)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(PlanPalette.lavender.opacity(0.3))
                            )
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(selection.hasBodyImage
                             ? (isArabic ? "صورة مرفقة ✓" : "Photo attached ✓")
                             : (isArabic ? "أرفق صورة لتفصيل الخطة" : "Attach a photo to tailor the plan"))
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(selection.hasBodyImage ? PlanPalette.lavenderDeep : PlanPalette.textPrimary)
                            .lineLimit(1)
                        Text(isArabic
                             ? "تُرسل لـ Google Gemini مرة واحدة وتُحذف بعد التحليل."
                             : "Sent once to Google Gemini, discarded after analysis.")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.forward")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(selection.hasBodyImage ? PlanPalette.lavender.opacity(0.16) : PlanPalette.surfaceTint)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(selection.hasBodyImage ? PlanPalette.lavender.opacity(0.5) : PlanPalette.hairline, lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .onChange(of: pickerItem) { _, newItem in
                Task { await loadPickerImage(newItem) }
            }
        }
    }

    private func loadPickerImage(_ item: PhotosPickerItem?) async {
        guard let item else {
            selection.bodyImage = nil
            return
        }
        await MainActor.run { isLoadingImage = true }
        defer { Task { @MainActor in isLoadingImage = false } }

        if let data = try? await item.loadTransferable(type: Data.self),
           let image = UIImage(data: data) {
            await MainActor.run { selection.bodyImage = image }
        }
    }

    private func sectionIcon(_ symbol: String, tint: PlanPalette.Family) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(tint.ink)
            .frame(width: 30, height: 30)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(tint.pastel.opacity(0.55))
            )
    }

    private func sectionBlock<Content: View>(
        icon: String,
        tint: PlanPalette.Family,
        title: String,
        answered: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 10) {
                sectionIcon(icon, tint: tint)
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
                if answered {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(PlanPalette.mintDeep)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            content()
        }
    }

    private func chip(isSelected: Bool, text: String, family: PlanPalette.Family, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .black))
                }
                Text(text)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? family.ink : PlanPalette.textPrimary.opacity(0.8))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? family.pastel : PlanPalette.surfaceTint)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(isSelected ? family.ink.opacity(0.25) : PlanPalette.hairline, lineWidth: 1)
            )
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
