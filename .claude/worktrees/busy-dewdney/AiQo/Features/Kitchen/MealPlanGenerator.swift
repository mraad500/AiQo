// Features/Kitchen/MealPlanGenerator.swift

import Foundation

struct DailyMealPlan: Equatable {
    let breakfast: Meal
    let lunch: Meal
    let dinner: Meal
}

enum MealPlanError: Error {
    case notEnoughMeals
}

struct MealPlanGenerator {

    func generateDailyPlan(
        targetCalories: Int,
        from meals: [Meal],
        excluding previousPlan: DailyMealPlan? = nil
    ) throws -> DailyMealPlan {

        let breakfasts = meals.filter { $0.mealType == .breakfast }
        let lunches    = meals.filter { $0.mealType == .lunch }
        let dinners    = meals.filter { $0.mealType == .dinner }

        guard !breakfasts.isEmpty, !lunches.isEmpty, !dinners.isEmpty else {
            throw MealPlanError.notEnoughMeals
        }

        func pick(
            from items: [Meal],
            avoiding id: Int?
        ) -> Meal {

            let filtered: [Meal]

            if let id = id {
                filtered = items.filter { $0.id != id }
            } else {
                filtered = items
            }

            return filtered.randomElement() ?? items[0]
        }

        let breakfast = pick(
            from: breakfasts,
            avoiding: previousPlan?.breakfast.id
        )

        let lunch = pick(
            from: lunches,
            avoiding: previousPlan?.lunch.id
        )

        let dinner = pick(
            from: dinners,
            avoiding: previousPlan?.dinner.id
        )

        return DailyMealPlan(
            breakfast: breakfast,
            lunch: lunch,
            dinner: dinner
        )
    }
}
