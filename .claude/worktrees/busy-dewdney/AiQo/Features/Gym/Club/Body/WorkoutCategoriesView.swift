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

    @State private var selection = 0
    @State private var visibleCardIDs = Set<UUID>()
    @State private var animationSeed = 0

    private var selectedCategory: WorkoutCategory {
        WorkoutCategory(rawValue: selection) ?? .cardio
    }

    private var currentItems: [WorkoutCardItem] {
        WorkoutCategoriesCatalog.items(for: selectedCategory)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Cards (scrollable) — left side
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 14) {
                    ForEach(Array(currentItems.enumerated()), id: \.element.id) { index, item in
                        let isFeatured = selectedCategory == .cardio && index == 0

                        Button {
                            if let exercise = WorkoutCategoriesCatalog.linkedExercise(for: item) {
                                onSelectExercise(exercise)
                            }
                        } label: {
                            ClubWorkoutCard(
                                item: item,
                                isFeatured: isFeatured,
                                useMint: index.isMultiple(of: 2),
                                isVisible: visibleCardIDs.contains(item.id)
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(GlassCardPressStyle())
                        .accessibilityHint(Text("افتح جلسة \(item.title)"))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.trailing, 8)
                .padding(.top, 18)
                .padding(.bottom, 100)
            }

            // Vertical side filter — right side
            clubSideFilter
                .frame(width: 58)
        }
        .environment(\.layoutDirection, .leftToRight)
        .onAppear {
            animateCards(for: currentItems)
        }
        .onChange(of: selection) { _, _ in
            animateCards(for: currentItems)
        }
    }

    private var clubSideFilter: some View {
        VStack(spacing: 4) {
            ForEach(Array(WorkoutCategory.allCases.enumerated()), id: \.element) { index, category in
                let isSelected = selection == index

                Button {
                    UISelectionFeedbackGenerator().selectionChanged()
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selection = index
                    }
                } label: {
                    Text(category.title)
                        .font(.system(size: 11, weight: isSelected ? .heavy : .medium))
                        .foregroundStyle(isSelected ? Color(.label) : Color(.secondaryLabel))
                        .frame(width: 44, height: 62)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.aiqoAccent : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color(.systemGray6).opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 25))
        .padding(.top, 120)
        .animation(.easeInOut(duration: 0.3), value: selection)
        .accessibilityLabel(Text("فئات التمارين"))
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

    private func cardGradientPrimary(for index: Int) -> Color {
        index.isMultiple(of: 2) ? Color(hex: "E8F7F0") : Color(hex: "F7EDD8")
    }
}

private struct ClubWorkoutCard: View {
    let item: WorkoutCardItem
    let isFeatured: Bool
    let useMint: Bool
    let isVisible: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(Color(.label))
                    .lineLimit(2)

                if isFeatured, let subtitle = item.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }

            Spacer()

            Circle()
                .fill(Color(.systemBackground).opacity(0.7))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: item.iconName)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color(.label))
                        .flipsForRightToLeftLayoutDirection(false)
                )
                .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(minHeight: isFeatured ? 120 : 100)
        .background(
            RoundedRectangle(cornerRadius: 26)
                .fill(
                    useMint
                        ? LinearGradient(colors: [Color(red: 0.77, green: 0.94, blue: 0.86), Color(red: 0.77, green: 0.94, blue: 0.86).opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color(red: 0.97, green: 0.84, blue: 0.64), Color(red: 0.97, green: 0.84, blue: 0.64).opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
        )
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
        .opacity(isVisible ? 1 : 0.001)
        .offset(y: isVisible ? 0 : 22)
        .scaleEffect(isVisible ? 1 : 0.96)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(item.title))
    }
}

// Keep GlassWorkoutCard for detail view usage
struct GlassWorkoutCard: View {
    let item: WorkoutCardItem
    let backgroundColor: Color
    let isVisible: Bool

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if let subtitle = item.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.primary.opacity(0.70))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            Circle()
                .fill(Color(.systemBackground).opacity(0.7))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: item.iconName)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color(.label))
                        .flipsForRightToLeftLayoutDirection(false)
                )
                .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, minHeight: 76)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(backgroundColor)
        )
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
        .opacity(isVisible ? 1 : 0.001)
        .offset(y: isVisible ? 0 : 22)
        .scaleEffect(isVisible ? 1 : 0.96)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(item.title))
    }
}

private struct WorkoutPlaceholderDetailView: View {
    let item: WorkoutCardItem
    let backgroundColor: Color
    let linkedExercise: GymExercise?
    let onSelectExercise: (GymExercise) -> Void

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

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

private struct GlassCardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .rotation3DEffect(
                .degrees(configuration.isPressed ? 8.0 : 0),
                axis: (x: 1, y: 0, z: 0)
            )
            .animation(
                configuration.isPressed
                    ? .spring(response: 0.10, dampingFraction: 0.5)
                    : .spring(response: 1.2, dampingFraction: 0.85),
                value: configuration.isPressed
            )
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
