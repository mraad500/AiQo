import SwiftUI

struct MealPlanView: View {
    @EnvironmentObject private var kitchenStore: KitchenPersistenceStore

    @State private var selectedDays: Int = 3
    @State private var isGenerating: Bool = false

    private let generationService = KitchenPlanGenerationService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                durationPicker
                generateButton
                pinnedPlanSection
                shoppingListSection
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("kitchen.mealplan.title".localized)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let pinnedPlan = kitchenStore.pinnedPlan {
                selectedDays = pinnedPlan.days
            }
        }
    }
}

private extension MealPlanView {
    var durationPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("kitchen.mealplan.duration".localized)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)

            Picker("kitchen.mealplan.duration".localized, selection: $selectedDays) {
                Text("3 " + "kitchen.mealplan.days".localized).tag(3)
                Text("7 " + "kitchen.mealplan.days".localized).tag(7)
            }
            .pickerStyle(.segmented)
        }
    }

    var generateButton: some View {
        Button {
            generatePlan()
        } label: {
            HStack {
                if isGenerating {
                    ProgressView()
                        .controlSize(.small)
                }
                Text("kitchen.mealplan.generateButton".localized)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.kitchenMint)
            )
        }
        .disabled(isGenerating)
    }

    var pinnedPlanSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("kitchen.mealplan.pinned".localized)
                .font(.system(size: 20, weight: .heavy, design: .rounded))

            if let plan = kitchenStore.pinnedPlan {
                ForEach(1...plan.days, id: \.self) { day in
                    daySection(day: day, plan: plan)
                }
            } else {
                emptyStateCard
            }
        }
    }

    var shoppingListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("kitchen.shopping.title".localized)
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                Spacer()
                Button {
                    kitchenStore.addMissingIngredientsToShoppingList()
                } label: {
                    Text("kitchen.shopping.addMissing".localized)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
                .buttonStyle(.bordered)
            }

            if kitchenStore.shoppingList.isEmpty {
                Text("kitchen.shopping.empty".localized)
                    .foregroundColor(.secondary)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
            } else {
                VStack(spacing: 8) {
                    ForEach(kitchenStore.shoppingList) { item in
                        HStack(spacing: 12) {
                            Button {
                                kitchenStore.toggleShoppingItem(item.id)
                            } label: {
                                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(item.isChecked ? .green : .secondary)
                            }
                            .buttonStyle(.plain)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .strikethrough(item.isChecked, color: .secondary)
                                if let amount = item.amount {
                                    Text(amountText(amount: amount, unit: item.unit))
                                        .font(.system(size: 13, weight: .regular, design: .rounded))
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            Button(role: .destructive) {
                                if let index = kitchenStore.shoppingList.firstIndex(where: { $0.id == item.id }) {
                                    kitchenStore.removeShoppingItems(at: IndexSet(integer: index))
                                }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        )
                    }
                }
            }
        }
    }

    var emptyStateCard: some View {
        Text("kitchen.mealplan.empty".localized)
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
    }

    func daySection(day: Int, plan: KitchenMealPlan) -> some View {
        let meals = mealsForDay(day: day, plan: plan)

        return VStack(alignment: .leading, spacing: 10) {
            Text("\("kitchen.mealplan.day".localized) \(day)")
                .font(.system(size: 18, weight: .bold, design: .rounded))

            if meals.isEmpty {
                Text("kitchen.mealplan.noMealsDay".localized)
                    .foregroundColor(.secondary)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
            } else {
                ForEach(meals) { meal in
                    mealCard(meal)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.separator).opacity(0.2), lineWidth: 1)
        )
    }

    func mealCard(_ meal: KitchenPlannedMeal) -> some View {
        let unresolvedMissingIngredients = meal.ingredients.filter {
            kitchenStore.availability(for: $0) == .missing &&
            !kitchenStore.isMarkedAsNeedsPurchase(mealID: meal.id, ingredientName: $0.name)
        }

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                mealImageThumb(meal)

                VStack(alignment: .leading, spacing: 4) {
                    Text(meal.title)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                    Text(meal.type.localizedTitle)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    if let calories = meal.calories {
                        Text("\(calories) \("screen.kitchen.caloriesUnit".localized)")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                    }
                    if let protein = meal.protein {
                        Text("\("kitchen.mealplan.protein".localized): \(String(format: "%.0f", protein))g")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(meal.ingredients) { ingredient in
                    ingredientRow(ingredient, meal: meal)
                }
            }

            if let missingIngredient = unresolvedMissingIngredients.first {
                impactCard(meal: meal, missingIngredient: missingIngredient)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    @ViewBuilder
    func mealImageThumb(_ meal: KitchenPlannedMeal) -> some View {
        MealIllustrationView(spec: MealImageSpecFactory.make(for: meal))
            .frame(width: 54, height: 54)
    }

    func ingredientRow(_ ingredient: KitchenIngredient, meal: KitchenPlannedMeal) -> some View {
        let state = kitchenStore.availability(for: ingredient)
        let markedNeedsPurchase = kitchenStore.isMarkedAsNeedsPurchase(
            mealID: meal.id,
            ingredientName: ingredient.name
        )

        return HStack {
            Text(state.icon)
            Text(ingredient.name)
                .font(.system(size: 14, weight: .medium, design: .rounded))
            Spacer()
            Text(state.localizedTitle)
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)

            if markedNeedsPurchase {
                Text("kitchen.impact.needsPurchase".localized)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.orange)
            }

            if let amount = ingredient.amount {
                Text(amountText(amount: amount, unit: ingredient.unit))
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
    }

    func impactCard(meal: KitchenPlannedMeal, missingIngredient: KitchenIngredient) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("kitchen.impact.title".localized)
                .font(.system(size: 14, weight: .bold, design: .rounded))
            Text("\("kitchen.impact.missingItem".localized): \(missingIngredient.name)")
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                Button {
                    _ = kitchenStore.replaceIngredient(mealID: meal.id, ingredientName: missingIngredient.name)
                } label: {
                    Text("kitchen.impact.replace".localized)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .buttonStyle(.bordered)

                Button {
                    kitchenStore.addIngredientToShoppingList(missingIngredient)
                } label: {
                    Text("kitchen.impact.addShopping".localized)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .buttonStyle(.bordered)

                Button {
                    kitchenStore.markAsNeedsPurchase(mealID: meal.id, ingredientName: missingIngredient.name)
                } label: {
                    Text("kitchen.impact.keepNeedsPurchase".localized)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.orange.opacity(0.12))
        )
    }

    func mealsForDay(day: Int, plan: KitchenMealPlan) -> [KitchenPlannedMeal] {
        plan.meals
            .filter { $0.dayIndex == day }
            .sorted {
                mealTypeOrder($0.type) < mealTypeOrder($1.type)
            }
    }

    func mealTypeOrder(_ type: KitchenMealType) -> Int {
        switch type {
        case .breakfast:
            return 0
        case .lunch:
            return 1
        case .dinner:
            return 2
        case .snack:
            return 3
        }
    }

    func amountText(amount: Double, unit: String?) -> String {
        let value = amount.rounded() == amount ? "\(Int(amount))" : String(format: "%.1f", amount)
        if let unit, !unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "\(value) \(unit)"
        }
        return value
    }

    func generatePlan() {
        guard !isGenerating else { return }

        isGenerating = true
        let goal = UserProfileStore.shared.current.goalText
        let trigger = selectedDays == 7
            ? "kitchen.quick.week".localized
            : "kitchen.quick.3days".localized

        Task {
            let plan = await generationService.generatePlan(
                days: selectedDays,
                triggerText: trigger,
                fridgeItems: kitchenStore.fridgeItems,
                userGoal: goal,
                cookingTimeMinutes: 30
            )

            await MainActor.run {
                kitchenStore.setPinnedPlan(plan)
                selectedDays = plan.days
                isGenerating = false
            }
        }
    }
}
