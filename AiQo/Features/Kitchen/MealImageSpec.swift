import Foundation

struct MealImageSpec {
    let template: PlateTemplate
    let ingredients: [IngredientKey]
}

struct MealDetailPresentation {
    let imageSpec: MealImageSpec
    let ingredientNames: [String]
    let proteinGrams: Int
}

enum MealImageSpecFactory {
    static func make(for meal: Meal) -> MealImageSpec {
        let title = meal.localizedName
        let template = template(forTitle: title, mealType: meal.mealType)
        let extracted = IngredientCatalog.extractAll(from: [meal.name_ar, meal.localizedName])
        return MealImageSpec(
            template: template,
            ingredients: composedIngredients(from: extracted, template: template)
        )
    }

    static func make(for meal: KitchenPlannedMeal) -> MealImageSpec {
        let template = template(forTitle: meal.title, mealType: meal.type)

        let ingredientMatches = meal.ingredients.compactMap { IngredientCatalog.match(from: $0.name) }
        let titleMatches = IngredientCatalog.extractAll(from: meal.title)
        let merged = unique(ingredientMatches + titleMatches)

        return MealImageSpec(
            template: template,
            ingredients: composedIngredients(from: merged, template: template)
        )
    }

    static func details(for meal: Meal, pinnedMeal: KitchenPlannedMeal? = nil) -> MealDetailPresentation {
        if let pinnedMeal {
            return details(for: pinnedMeal)
        }

        let template = template(forTitle: meal.localizedName, mealType: meal.mealType)
        let extracted = IngredientCatalog.extractAll(from: [meal.name_ar, meal.localizedName])
        let imageSpec = MealImageSpec(
            template: template,
            ingredients: composedIngredients(from: extracted, template: template)
        )

        let contentKeys = extracted.isEmpty ? Array(imageSpec.ingredients.prefix(4)) : extracted

        return MealDetailPresentation(
            imageSpec: imageSpec,
            ingredientNames: contentKeys.map(\.localizedTitle),
            proteinGrams: estimateProteinGrams(from: contentKeys, fallback: fallbackProtein(for: meal.mealType))
        )
    }

    static func details(for meal: KitchenPlannedMeal) -> MealDetailPresentation {
        let imageSpec = make(for: meal)
        let contentKeys = meal.ingredients.compactMap { IngredientCatalog.match(from: $0.name) }

        return MealDetailPresentation(
            imageSpec: imageSpec,
            ingredientNames: meal.ingredients.isEmpty ? imageSpec.ingredients.prefix(4).map(\.localizedTitle) : meal.ingredients.map(\.name),
            proteinGrams: Int(meal.protein?.rounded() ?? Double(estimateProteinGrams(from: contentKeys, fallback: fallbackProtein(for: meal.type))))
        )
    }

    private static func template(forTitle title: String, mealType: MealType) -> PlateTemplate {
        let normalizedTitle = IngredientCatalog.normalize(title)

        if isDrinkTitle(normalizedTitle) {
            return .drinkCup
        }
        if isSaladTitle(normalizedTitle) {
            return .saladBowl
        }

        switch mealType {
        case .breakfast:
            return .breakfastBowl
        case .lunch:
            return .lunchPlate
        case .dinner:
            return .dinnerPlate
        }
    }

    private static func template(forTitle title: String, mealType: KitchenMealType) -> PlateTemplate {
        let normalizedTitle = IngredientCatalog.normalize(title)

        if isDrinkTitle(normalizedTitle) {
            return .drinkCup
        }
        if isSaladTitle(normalizedTitle) {
            return .saladBowl
        }

        switch mealType {
        case .breakfast:
            return .breakfastBowl
        case .lunch:
            return .lunchPlate
        case .dinner:
            return .dinnerPlate
        case .snack:
            return .snackBowl
        }
    }

    private static func composedIngredients(from extracted: [IngredientKey], template: PlateTemplate) -> [IngredientKey] {
        var result = unique(extracted)
        let defaults = defaultIngredients(for: template)
        let minimumCount = 3

        for candidate in defaults where result.count < 6 {
            let hasSameCategory = result.contains(where: { $0.category == candidate.category })
            if !hasSameCategory || result.count < minimumCount {
                if !result.contains(candidate) {
                    result.append(candidate)
                }
            }
        }

        for candidate in defaults where result.count < minimumCount {
            if !result.contains(candidate) {
                result.append(candidate)
            }
        }

        return Array(result.prefix(6))
    }

    private static func defaultIngredients(for template: PlateTemplate) -> [IngredientKey] {
        switch template {
        case .breakfastBowl:
            return [.ing_egg_whole, .ing_oats, .ing_banana, .ing_yogurt, .ing_berries, .ing_nuts_mixed]
        case .lunchPlate:
            return [.ing_chicken_breast, .ing_rice_white, .ing_broccoli, .ing_tomato, .ing_avocado, .ing_olive_oil]
        case .dinnerPlate:
            return [.ing_white_fish, .ing_potato, .ing_lettuce, .ing_tomato, .ing_cucumber, .ing_olive_oil]
        case .saladBowl:
            return [.ing_lettuce, .ing_tomato, .ing_cucumber, .ing_avocado, .ing_chicken_breast, .ing_olive_oil]
        case .snackBowl:
            return [.ing_yogurt, .ing_banana, .ing_berries, .ing_nuts_mixed, .ing_dates, .ing_milk]
        case .drinkCup:
            return [.ing_juice_glass, .ing_milk, .ing_berries, .ing_banana, .ing_orange, .ing_water_bottle]
        }
    }

    private static func unique(_ keys: [IngredientKey]) -> [IngredientKey] {
        var seen: Set<IngredientKey> = []
        var result: [IngredientKey] = []

        for key in keys where !seen.contains(key) {
            seen.insert(key)
            result.append(key)
        }

        return result
    }

    private static func isSaladTitle(_ normalizedTitle: String) -> Bool {
        normalizedTitle.contains("سلطه") || normalizedTitle.contains("salad")
    }

    private static func isDrinkTitle(_ normalizedTitle: String) -> Bool {
        let keywords = ["ماء", "مي", "عصير", "حليب", "juice", "milk", "water", "smoothie", "shake"]
        return keywords.contains(where: { normalizedTitle.contains($0) })
    }

    private static func estimateProteinGrams(from keys: [IngredientKey], fallback: Int) -> Int {
        guard !keys.isEmpty else { return fallback }

        let total = keys.reduce(0) { partialResult, key in
            partialResult + key.estimatedProteinGrams
        }

        return max(fallback, min(total, 48))
    }

    private static func fallbackProtein(for mealType: MealType) -> Int {
        switch mealType {
        case .breakfast:
            return 18
        case .lunch:
            return 30
        case .dinner:
            return 26
        }
    }

    private static func fallbackProtein(for mealType: KitchenMealType) -> Int {
        switch mealType {
        case .breakfast:
            return 18
        case .lunch:
            return 30
        case .dinner:
            return 26
        case .snack:
            return 12
        }
    }
}
