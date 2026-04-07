import SwiftUI
import UIKit

struct WorkoutCardItem: Identifiable, Hashable {
    let id: UUID
    let title: String
    let subtitle: String?
    let iconName: String
    let themeColor: Color

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String? = nil,
        iconName: String,
        themeColor: Color
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.iconName = iconName
        self.themeColor = themeColor
    }
}

struct WorkoutCategoriesView: View {
    let onSelectExercise: (GymExercise) -> Void

    // Matches the current rendered height of the club top chrome so cards slide directly under it.
    private let renderedTopChromeHeight: CGFloat = 116
    private let contentLeadingPadding: CGFloat = 14
    private let contentTrailingPadding: CGFloat = ClubChromeLayout.contentTrailingPadding - 8
    private let topContentSpacing: CGFloat = 4

    @State private var selection = 0
    @State private var visibleCardIDs = Set<UUID>()
    @State private var animationSeed = 0

    private var selectedCategory: WorkoutCategory {
        WorkoutCategory(rawValue: selection) ?? .cardio
    }

    private var currentItems: [WorkoutCardItem] {
        WorkoutCategoriesCatalog.items(for: selectedCategory)
    }

    private var topScrollOverlap: CGFloat {
        renderedTopChromeHeight + ClubChromeLayout.contentTopPadding
    }

    private var topContentInset: CGFloat {
        renderedTopChromeHeight + topContentSpacing
    }

    private var railItems: [RailItem] {
        WorkoutCategory.allCases.map {
            RailItem(
                id: "\($0.rawValue)",
                title: $0.title,
                icon: $0.railIcon,
                tint: .aiqoAccent
            )
        }
    }

    var body: some View {
        ClubStandardRightRailContainer(
            items: railItems,
            selection: $selection,
            accessibilityLabel: Text("فئات التمارين")
        ) {
            WorkoutCategoriesBackdrop()
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 20) {
                    ForEach(Array(currentItems.enumerated()), id: \.element.id) { index, item in
                        let backgroundColor = cardBackgroundColor(for: index)

                        NavigationLink {
                            WorkoutPlaceholderDetailView(
                                item: item,
                                backgroundColor: backgroundColor,
                                linkedExercise: WorkoutCategoriesCatalog.linkedExercise(for: item),
                                onSelectExercise: onSelectExercise
                            )
                        } label: {
                            GlassWorkoutCard(
                                item: item,
                                backgroundColor: backgroundColor,
                                isVisible: visibleCardIDs.contains(item.id)
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(GlassCardPressStyle())
                        .accessibilityHint(Text("افتح تفاصيل \(item.title)"))
                    }
                }
                .padding(.top, topContentInset)
                .padding(.leading, contentLeadingPadding)
                .padding(.trailing, contentTrailingPadding)
                .padding(.bottom, 120)
                .offset(x: -1)
            }
            .padding(.top, -topScrollOverlap)
            .contentMargins(.top, 0, for: .scrollContent)
            .contentMargins(.top, 0, for: .scrollIndicators)
        }
        .onAppear {
            animateCards(for: currentItems)
        }
        .onChange(of: selection) { _, _ in
            animateCards(for: currentItems)
        }
    }

    private func animateCards(for items: [WorkoutCardItem]) {
        animationSeed += 1
        let currentSeed = animationSeed
        visibleCardIDs.removeAll()

        for (index, item) in items.enumerated() {
            let delay = 0.05 * Double(index)

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard currentSeed == animationSeed else { return }

                _ = withAnimation(.spring(response: 0.58, dampingFraction: 0.84)) {
                    visibleCardIDs.insert(item.id)
                }
            }
        }
    }

    private func cardBackgroundColor(for index: Int) -> Color {
        index.isMultiple(of: 2) ? GymTheme.mint : GymTheme.beige
    }
}

struct GlassSegmentedControl: View {
    let tabs: [String]
    @Binding var selection: Int

    @Namespace private var selectionAnimation

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, title in
                Button {
                    UISelectionFeedbackGenerator().selectionChanged()

                    withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                        selection = index
                    }
                } label: {
                    Text(title)
                        .font(.system(size: 16, weight: selection == index ? .bold : .medium, design: .rounded))
                        .foregroundStyle(labelColor(for: index))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(segmentBackground(for: index))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(title))
                .accessibilityAddTraits(selection == index ? [.isSelected] : [])
            }
        }
        .padding(6)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.18),
                                    AiQoColors.mint.opacity(0.10),
                                    AiQoColors.beige.opacity(0.10)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 0.8)
                )
        )
        .shadow(color: Color.black.opacity(0.06), radius: 18, x: 0, y: 10)
        .shadow(color: AiQoColors.mint.opacity(0.12), radius: 24, x: 0, y: 12)
    }

    private func labelColor(for index: Int) -> Color {
        selection == index ? Color.black.opacity(0.82) : Color.primary.opacity(0.68)
    }

    @ViewBuilder
    private func segmentBackground(for index: Int) -> some View {
        if selection == index {
            selectedSegmentBackground(for: index)
                .matchedGeometryEffect(id: "workoutCategorySelection", in: selectionAnimation)
        } else {
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(0.24)
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.6)
                )
        }
    }

    private func selectedSegmentBackground(for index: Int) -> some View {
        let fillColor = selectedBackgroundColor(for: index)

        return Capsule(style: .continuous)
            .fill(fillColor)
            .overlay(
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(0.22)
            )
            .overlay(
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.18),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.28), lineWidth: 0.8)
            )
    }

    private func selectedBackgroundColor(for index: Int) -> Color {
        switch index {
        case 1:
            return AiQoColors.beige
        default:
            return AiQoColors.mint
        }
    }
}

struct GlassWorkoutCard: View {
    let item: WorkoutCardItem
    let backgroundColor: Color
    let isVisible: Bool

    private let cornerRadius: CGFloat = 30

    var body: some View {
        HStack(spacing: 14) {
            textContent

            Spacer(minLength: 0)

            iconChip
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, minHeight: 118)
        .background(cardBackground)
        .shadow(color: Color.black.opacity(0.035), radius: 10, x: 0, y: 6)
        .shadow(color: backgroundColor.opacity(0.12), radius: 14, x: 0, y: 8)
        .opacity(isVisible ? 1 : 0.001)
        .offset(y: isVisible ? 0 : 22)
        .scaleEffect(isVisible ? 1 : 0.96)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityLabel))
    }

    private var textContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Color.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)

            if let subtitle = item.subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.primary.opacity(0.70))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var iconChip: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.22),
                            Color.white.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .stroke(Color.white.opacity(0.24), lineWidth: 0.8)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.30),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(3)
                .blur(radius: 1.5)

            Image(systemName: item.iconName)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(Color.black.opacity(0.75))
                .flipsForRightToLeftLayoutDirection(false)
        }
        .frame(width: 58, height: 58)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        .accessibilityHidden(true)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var accessibilityLabel: String {
        if let subtitle = item.subtitle, !subtitle.isEmpty {
            return "\(item.title)، \(subtitle)"
        }

        return item.title
    }
}

private struct WorkoutPlaceholderDetailView: View {
    let item: WorkoutCardItem
    let backgroundColor: Color
    let linkedExercise: GymExercise?
    let onSelectExercise: (GymExercise) -> Void

    var body: some View {
        ZStack {
            WorkoutCategoriesBackdrop()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    GlassWorkoutCard(item: item, backgroundColor: backgroundColor, isVisible: true)
                        .padding(.top, 16)

                    VStack(spacing: 14) {
                        Text(item.title)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if let subtitle = item.subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.primary.opacity(0.72))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Text("واجهة تفصيلية تجريبية لهذا النشاط داخل النادي.")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.primary.opacity(0.68))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, 10)

                    if let linkedExercise {
                        Button {
                            onSelectExercise(linkedExercise)
                        } label: {
                            Text("ابدأ الجلسة")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(backgroundColor)
                                        .overlay(
                                            Capsule(style: .continuous)
                                                .fill(.ultraThinMaterial.opacity(0.18))
                                        )
                                        .overlay(
                                            Capsule(style: .continuous)
                                                .stroke(Color.white.opacity(0.22), lineWidth: 0.8)
                                        )
                                )
                        }
                        .buttonStyle(GlassCardPressStyle())
                        .accessibilityLabel(Text("ابدأ جلسة \(item.title)"))
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 36)
            }
        }
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct WorkoutCategoriesBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AiQoColors.mint.opacity(0.24),
                    AiQoColors.beige.opacity(0.18),
                    Color(uiColor: .systemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(AiQoColors.mint.opacity(0.18))
                .frame(width: 260, height: 260)
                .blur(radius: 44)
                .offset(x: 120, y: -180)

            Circle()
                .fill(AiQoColors.beige.opacity(0.20))
                .frame(width: 280, height: 280)
                .blur(radius: 56)
                .offset(x: -140, y: 220)
        }
        .allowsHitTesting(false)
    }
}

private struct GlassCardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .rotation3DEffect(
                .degrees(configuration.isPressed ? 1.2 : 0),
                axis: (x: 1, y: 0, z: 0)
            )
            .animation(.spring(response: 0.24, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

private enum WorkoutCategory: Int, CaseIterable, Identifiable {
    case cardio
    case strength
    case clarity

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .cardio:
            return "كارديو"
        case .strength:
            return "قوة"
        case .clarity:
            return "صفاء"
        }
    }

    var railIcon: String {
        switch self {
        case .cardio:
            return "figure.run"
        case .strength:
            return "dumbbell"
        case .clarity:
            return "sparkles"
        }
    }

    var railTint: Color {
        switch self {
        case .strength:
            return AiQoColors.beige
        case .cardio, .clarity:
            return AiQoColors.mint
        }
    }
}

private struct WorkoutSeed: Hashable {
    let item: WorkoutCardItem
    let exerciseKey: String?
}

private enum WorkoutCategoriesCatalog {
    private static let cardioSeeds: [WorkoutSeed] = [
        WorkoutSeed(
            item: WorkoutCardItem(
                title: "كارديو ويا الكابتن حمّودي",
                subtitle: "نبض Zone 2 لحرق دهون مثالي",
                iconName: "figure.run",
                themeColor: AiQoColors.beige
            ),
            exerciseKey: "gym.exercise.cardio_captain_hamoudi"
        ),
        WorkoutSeed(
            item: WorkoutCardItem(
                title: "الجري",
                iconName: "figure.run",
                themeColor: AiQoColors.mint
            ),
            exerciseKey: "gym.exercise.running"
        ),
        WorkoutSeed(
            item: WorkoutCardItem(
                title: "المشي",
                iconName: "figure.walk",
                themeColor: AiQoColors.beige
            ),
            exerciseKey: "gym.exercise.walking"
        ),
        WorkoutSeed(
            item: WorkoutCardItem(
                title: "الدراجات",
                iconName: "figure.outdoor.cycle",
                themeColor: AiQoColors.mint
            ),
            exerciseKey: "gym.exercise.cycling"
        ),
        WorkoutSeed(
            item: WorkoutCardItem(
                title: "السباحة",
                iconName: "figure.pool.swim",
                themeColor: AiQoColors.beige
            ),
            exerciseKey: "gym.exercise.swimming"
        )
    ]

    private static let strengthSeeds: [WorkoutSeed] = [
        WorkoutSeed(
            item: WorkoutCardItem(
                title: "تمارين القوة",
                iconName: "dumbbell.fill",
                themeColor: AiQoColors.beige
            ),
            exerciseKey: "gym.exercise.strength"
        ),
        WorkoutSeed(
            item: WorkoutCardItem(
                title: "تمارين HIIT",
                iconName: "flame.fill",
                themeColor: AiQoColors.mint
            ),
            exerciseKey: "gym.exercise.hiit"
        ),
        WorkoutSeed(
            item: WorkoutCardItem(
                title: "الفروسية",
                iconName: "figure.equestrian.sports",
                themeColor: AiQoColors.beige
            ),
            exerciseKey: "gym.exercise.equestrian"
        ),
        WorkoutSeed(
            item: WorkoutCardItem(
                title: "تمارين وزن الجسم",
                iconName: "figure.strengthtraining.traditional",
                themeColor: AiQoColors.mint
            ),
            exerciseKey: "gym.exercise.calisthenics"
        )
    ]

    private static let claritySeeds: [WorkoutSeed] = [
        WorkoutSeed(
            item: WorkoutCardItem(
                title: "تنفّس",
                subtitle: "تهدئة الجهاز العصبي",
                iconName: "wind",
                themeColor: AiQoColors.mint
            ),
            exerciseKey: nil
        ),
        WorkoutSeed(
            item: WorkoutCardItem(
                title: "الامتنان",
                subtitle: "إعادة ضبط الأنا",
                iconName: "heart.text.square.fill",
                themeColor: AiQoColors.beige
            ),
            exerciseKey: "gym.exercise.gratitude"
        ),
        WorkoutSeed(
            item: WorkoutCardItem(
                title: "يوغا",
                subtitle: "حركة + صفاء",
                iconName: "figure.yoga",
                themeColor: AiQoColors.mint
            ),
            exerciseKey: "gym.exercise.yoga"
        ),
        WorkoutSeed(
            item: WorkoutCardItem(
                title: "شحن الهالة",
                subtitle: "طاقتك نظيفة",
                iconName: "sparkles",
                themeColor: AiQoColors.beige
            ),
            exerciseKey: nil
        ),
        WorkoutSeed(
            item: WorkoutCardItem(
                title: "صفاء الأعماق",
                subtitle: "افصل عن العالم واتصل بنفسك",
                iconName: "water.waves",
                themeColor: AiQoColors.mint
            ),
            exerciseKey: nil
        )
    ]

    private static let linkedExercisesByKey = Dictionary(
        uniqueKeysWithValues: GymExercise.samples.map { ($0.titleKey, $0) }
    )

    static func items(for category: WorkoutCategory) -> [WorkoutCardItem] {
        seeds(for: category).map(\.item)
    }

    static func linkedExercise(for item: WorkoutCardItem) -> GymExercise? {
        guard let key = allSeeds.first(where: { $0.item.id == item.id })?.exerciseKey else {
            return nil
        }

        return linkedExercisesByKey[key]
    }

    private static var allSeeds: [WorkoutSeed] {
        cardioSeeds + strengthSeeds + claritySeeds
    }

    private static func seeds(for category: WorkoutCategory) -> [WorkoutSeed] {
        switch category {
        case .cardio:
            return cardioSeeds
        case .strength:
            return strengthSeeds
        case .clarity:
            return claritySeeds
        }
    }
}

#Preview("Workout Categories RTL") {
    NavigationStack {
        WorkoutCategoriesView(onSelectExercise: { _ in })
            .environment(\.layoutDirection, .rightToLeft)
    }
}
