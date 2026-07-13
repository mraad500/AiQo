import SwiftUI

struct KitchenScreen: View {
    @State private var selectedMeal: Meal?
    @State private var showProfile = false

    let viewModel: KitchenViewModel
    @ObservedObject var kitchenStore: KitchenPersistenceStore

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .trailing, spacing: 24) {
                    // كروت الدخول السريع (أعلى الشاشة): الثلاجة + النظام الغذائي
                    topEntryCards

                    mealSection(titleKey: "screen.kitchen.breakfast", type: .breakfast)
                    mealSection(titleKey: "screen.kitchen.lunch", type: .lunch)
                    mealSection(titleKey: "screen.kitchen.dinner", type: .dinner)

                    // ملخص التغذية اليومي — مصغّر وفي أسفل الشاشة
                    DailyFoodLogView(kitchenStore: kitchenStore)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            topChrome
                .background {
                    // Opaque layer so scrolled content can't bleed through the
                    // header; extends past the safe-area top to cover the
                    // status-bar gutter, mirroring the Captain screen.
                    Color(.systemBackground)
                        .ignoresSafeArea(edges: .top)
                }
        }
        .task {
            await viewModel.loadMeals()
        }
        .aiqoProfileSheet(isPresented: $showProfile)
        .sheet(item: $selectedMeal) { meal in
            if #available(iOS 17.0, *) {
                MealDetailSheet(
                    meal: meal,
                    pinnedMeal: activePinnedPlanMeal(for: meal.meal_type)
                )
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(.ultraThinMaterial)
                    .presentationCornerRadius(28)
            } else {
                MealDetailSheet(
                    meal: meal,
                    pinnedMeal: activePinnedPlanMeal(for: meal.meal_type)
                )
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(28)
            }
        }
    }
}

private extension KitchenScreen {
    // Shared top chrome: title + date on the trailing side and the profile
    // avatar on the leading side, matching the Captain screen exactly (same
    // title font size, same profile button size and placement).
    var topChrome: some View {
        AiQoScreenTopChrome(
            horizontalInset: 10,
            profileVerticalOffset: -2,
            onProfileTap: { showProfile = true }
        ) {
            HStack(alignment: .center, spacing: 8) {
                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 5) {
                    Text("screen.kitchen.title".localized)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    HStack(spacing: 6) {
                        Text(formattedDate())
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)

                        Image(systemName: "calendar")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                .lineLimit(1)
            }
            .environment(\.layoutDirection, .rightToLeft)
        }
    }

    func mealSection(titleKey: String, type: MealType) -> some View {
        VStack(alignment: .trailing, spacing: 12) {
            Text(titleKey.localized)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            if let meal = displayedMeal(type: type) {
                AnimatedMealButton(meal: meal) {
                    selectedMeal = meal
                }
            } else {
                Text("screen.kitchen.noMeals".localized)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.gray)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    func displayedMeal(type: MealType) -> Meal? {
        if let pinnedMeal = pinnedPlanMeal(for: type) {
            return pinnedMeal
        }
        return viewModel.displayedMeal(for: type)
    }

    func pinnedPlanMeal(for type: MealType) -> Meal? {
        guard let plan = kitchenStore.pinnedPlan else { return nil }

        let calendar = Calendar.current
        let startOfPlan = calendar.startOfDay(for: plan.startDate)
        let today = calendar.startOfDay(for: Date())
        let dayOffset = calendar.dateComponents([.day], from: startOfPlan, to: today).day ?? 0
        let activeDay = min(max(dayOffset + 1, 1), max(plan.days, 1))

        let targetType = KitchenMealType.from(mealType: type)
        let candidate = plan.meals.first(where: { $0.dayIndex == activeDay && $0.type == targetType })
            ?? plan.meals.first(where: { $0.dayIndex == 1 && $0.type == targetType })
            ?? plan.meals.first(where: { $0.type == targetType })

        guard let candidate else { return nil }

        return Meal(
            id: generatedMealID(from: candidate),
            name_ar: candidate.title,
            name_en: nil,
            calories_kcal: candidate.calories ?? candidate.type.defaultCalories,
            meal_type: type
        )
    }

    func generatedMealID(from meal: KitchenPlannedMeal) -> Int {
        let titleSeed = meal.title.unicodeScalars.reduce(0) { partialResult, scalar in
            partialResult + Int(scalar.value)
        }
        return 90_000 + titleSeed + (meal.dayIndex * 10) + mealTypeSeed(meal.type)
    }

    func mealTypeSeed(_ type: KitchenMealType) -> Int {
        switch type {
        case .breakfast:
            return 1
        case .lunch:
            return 2
        case .dinner:
            return 3
        case .snack:
            return 4
        }
    }

    // كرتان أعلى المطبخ بلون البيج (نفس بطاقات الشاشة الرئيسية): الثلاجة + النظام الغذائي.
    // كل كرت يفتح شاشته: الثلاجة ← الثلاجة التفاعلية، النظام الغذائي ← إنشاء خطة وية الكابتن.
    var topEntryCards: some View {
        HStack(spacing: 14) {
            kitchenEntryCard(
                titleKey: "kitchen.fridge.title",
                systemImage: "refrigerator.fill"
            ) {
                InteractiveFridgeView()
                    .environmentObject(kitchenStore)
            }

            kitchenEntryCard(
                titleKey: "kitchen.mealplan.title",
                systemImage: "fork.knife.circle.fill"
            ) {
                MealPlanView()
                    .environmentObject(kitchenStore)
            }
        }
    }

    func kitchenEntryCard<Destination: View>(
        titleKey: String,
        systemImage: String,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        NavigationLink(destination: destination) {
            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.45))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.white.opacity(0.5)))

                Spacer(minLength: 12)

                Text(titleKey.localized)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.black.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 124, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.aiqoSand, Color.aiqoSand.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(
                        color: Color(red: 0.85, green: 0.70, blue: 0.45).opacity(0.35),
                        radius: 12, x: 0, y: 6
                    )
            )
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private static let headerDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = "d/M"
        return formatter
    }()

    func formattedDate() -> String {
        Self.headerDateFormatter.string(from: Date())
    }

    func activePinnedPlanMeal(for type: MealType) -> KitchenPlannedMeal? {
        guard let plan = kitchenStore.pinnedPlan else { return nil }

        let calendar = Calendar.current
        let startOfPlan = calendar.startOfDay(for: plan.startDate)
        let today = calendar.startOfDay(for: Date())
        let dayOffset = calendar.dateComponents([.day], from: startOfPlan, to: today).day ?? 0
        let activeDay = min(max(dayOffset + 1, 1), max(plan.days, 1))
        let targetType = KitchenMealType.from(mealType: type)

        return plan.meals.first(where: { $0.dayIndex == activeDay && $0.type == targetType })
            ?? plan.meals.first(where: { $0.dayIndex == 1 && $0.type == targetType })
            ?? plan.meals.first(where: { $0.type == targetType })
    }
}

private extension KitchenMealType {
    static func from(mealType: MealType) -> KitchenMealType {
        switch mealType {
        case .breakfast:
            return .breakfast
        case .lunch:
            return .lunch
        case .dinner:
            return .dinner
        }
    }
}

struct MealDetailSheet: View {
    let meal: Meal
    let pinnedMeal: KitchenPlannedMeal?

    private var presentation: MealDetailPresentation {
        MealImageSpecFactory.details(for: meal, pinnedMeal: pinnedMeal)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                Capsule()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 40, height: 4)
                    .padding(.top, 8)

                MealIllustrationView(spec: presentation.imageSpec)
                    .frame(width: 188, height: 188)
                    .shadow(color: .black.opacity(0.12), radius: 14, x: 0, y: 6)

                Text(meal.name_ar)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                HStack(spacing: 10) {
                    detailStatCard(
                        title: "\(meal.calories_kcal) " + "screen.kitchen.caloriesUnit".localized,
                        subtitle: "kitchen.mealdetail.calories".localized
                    )

                    detailStatCard(
                        title: "\(presentation.proteinGrams)g",
                        subtitle: "kitchen.mealdetail.protein".localized
                    )
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("kitchen.mealdetail.contents".localized)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: 10) {
                        ForEach(presentation.ingredientItems) { ingredient in
                            HStack(spacing: 12) {
                                IngredientIconView(
                                    emoji: ingredient.emoji,
                                    size: 36,
                                    cornerRadius: 12
                                )

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 8) {
                                        Text(ingredient.name)
                                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                                            .foregroundStyle(.primary)
                                            .multilineTextAlignment(.leading)

                                        if ingredient.count > 1 {
                                            Text("×\(ingredient.count)")
                                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                                .foregroundStyle(.secondary)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(
                                                    Capsule(style: .continuous)
                                                        .fill(Color(.tertiarySystemFill))
                                                )
                                        }
                                    }

                                    if let quantityText = ingredient.quantityText {
                                        Text(quantityText)
                                            .font(.system(size: 13, weight: .medium, design: .rounded))
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color(.secondarySystemBackground))
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .safeAreaPadding(.bottom, 12)
    }

    func detailStatCard(title: String, subtitle: String) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

struct AnimatedMealButton: View {
    let meal: Meal
    let action: () -> Void

    @State private var isPressed: Bool = false
    @State private var floatOffsetY: CGFloat = -1.2
    @State private var idleRotation: Double = -0.45
    @State private var tapRotation: Double = 0

    var body: some View {
        RecipeCardView(meal: meal)
            .offset(y: floatOffsetY)
            .scaleEffect(x: 1.0, y: isPressed ? 0.94 : 1.0, anchor: .center)
            .rotationEffect(.degrees(idleRotation + tapRotation))
            .rotation3DEffect(
                .degrees((idleRotation + tapRotation) * 0.35),
                axis: (x: 0, y: 0, z: 1),
                anchor: .center
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                    floatOffsetY = 1.2
                    idleRotation = 0.45
                }
            }
            .onTapGesture {
                triggerWaveAnimation()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                    action()
                }
            }
    }

    private func triggerWaveAnimation() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()

        withAnimation(.easeInOut(duration: 0.12)) {
            isPressed = true
            tapRotation = 0.65
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(.easeOut(duration: 0.18)) {
                isPressed = false
                tapRotation = 0
            }
        }
    }
}
