import SwiftUI

struct KitchenScreen: View {
    @State private var selectedMeal: Meal?
    @State private var isProfileSheetPresented = false
    @State private var regenerateFeedbackTrigger = 0

    let viewModel: KitchenViewModel
    @ObservedObject var kitchenStore: KitchenPersistenceStore

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.top, 8)
                    .padding(.bottom, 16)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .trailing, spacing: 24) {
                        mealSection(titleKey: "screen.kitchen.breakfast", type: .breakfast)
                        mealSection(titleKey: "screen.kitchen.lunch", type: .lunch)
                        mealSection(titleKey: "screen.kitchen.dinner", type: .dinner)

                        buttonsSection
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
        }
        .task {
            await viewModel.loadMeals()
        }
        .sheet(isPresented: $isProfileSheetPresented) {
            NavigationStack {
                ProfileScreen()
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedMeal) { meal in
            if #available(iOS 17.0, *) {
                MealDetailSheet(
                    meal: meal,
                    pinnedMeal: activePinnedPlanMeal(for: meal.meal_type)
                )
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(.ultraThinMaterial)
            } else {
                MealDetailSheet(
                    meal: meal,
                    pinnedMeal: activePinnedPlanMeal(for: meal.meal_type)
                )
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}

private extension KitchenScreen {
    var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text("screen.kitchen.title".localized)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundColor(.primary)

                HStack(spacing: 6) {
                    Text(formattedDate())
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)

                    Image(systemName: "calendar")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            FloatingProfileButton(size: 48) {
                openProfile()
            }
        }
        .frame(height: 74)
        .padding(.horizontal, 24)
    }

    func mealSection(titleKey: String, type: MealType) -> some View {
        VStack(alignment: .trailing, spacing: 12) {
            Text(titleKey.localized)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            if let meal = displayedMeal(type: type) {
                AnimatedMealButton(meal: meal) {
                    selectedMeal = meal
                }
            } else {
                Text("screen.kitchen.noMeals".localized)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.gray)
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

    var buttonsSection: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                smallEntryLink(
                    title: "kitchen.fridge.title".localized,
                    icon: "refrigerator.fill"
                ) {
                    FridgeInventoryView()
                        .environmentObject(kitchenStore)
                }

                smallEntryLink(
                    title: "kitchen.mealplan.title".localized,
                    icon: "fork.knife.circle.fill"
                ) {
                    MealPlanView()
                        .environmentObject(kitchenStore)
                }
            }

            NavigationLink {
                KitchenSceneView()
                    .environmentObject(kitchenStore)
            } label: {
                Text("screen.kitchen.regenerate".localized)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color.kitchenMint)
                    )
            }
            .frame(maxWidth: 320)
            .contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture().onEnded {
                    regenerateFeedbackTrigger += 1
                }
            )
            .sensoryFeedback(.selection, trigger: regenerateFeedbackTrigger)
        }
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    func smallEntryLink<Destination: View>(
        title: String,
        icon: String,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .lineLimit(1)
            }
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 48)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.aiqoSand)
            )
        }
        .contentShape(Rectangle())
    }

    func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = "d/M"
        return formatter.string(from: Date())
    }

    func openProfile() {
        isProfileSheetPresented = true
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
                                Image(systemName: "fork.knife.circle.fill")
                                    .foregroundStyle(Color.yellow)
                                    .font(.system(size: 18, weight: .semibold))

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 8) {
                                        Text(ingredient.name)
                                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                                            .foregroundColor(.primary)
                                            .multilineTextAlignment(.leading)

                                        if ingredient.count > 1 {
                                            Text("×\(ingredient.count)")
                                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                                .foregroundColor(.secondary)
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
                                            .foregroundColor(.secondary)
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
                .foregroundColor(.primary)
            Text(subtitle)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
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
