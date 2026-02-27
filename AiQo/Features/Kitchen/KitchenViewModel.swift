// Features/Kitchen/KitchenViewModel.swift

import Foundation
import Observation

@Observable
final class KitchenViewModel {

    enum LoadingState {
        case idle
        case loading
        case loaded
        case error(String)
    }

    // MARK: - Services
    private let repository: MealsRepository
    private let generator: MealPlanGenerator
    private let defaults: UserDefaults
    private let hasMealPlanKey = "aiqo.quest.kitchen.hasMealPlan"
    private let savedAtKey = "aiqo.quest.kitchen.savedAt"

    // MARK: - State
    var allMeals: [Meal] = []
    var loadingState: LoadingState = .idle
    var currentPlan: DailyMealPlan?
    var targetCalories: Int = 2200

    // MARK: - Init
    init(repository: MealsRepository,
         generator: MealPlanGenerator = MealPlanGenerator(),
         defaults: UserDefaults = .standard) {
        self.repository = repository
        self.generator = generator
        self.defaults = defaults
    }

    // MARK: - Derived
    func meals(for type: MealType) -> [Meal] {
        allMeals.filter { $0.mealType == type }
    }

    func displayedMeal(for type: MealType) -> Meal? {
        if let plan = currentPlan {
            switch type {
            case .breakfast: return plan.breakfast
            case .lunch:     return plan.lunch
            case .dinner:    return plan.dinner
            }
        } else {
            return meals(for: type).first
        }
    }

    // MARK: - Actions
    func loadMeals() async {
        loadingState = .loading

        do {
            let meals = try await repository.fetchAllMeals()
            await MainActor.run {
                print("🍽 loaded meals count =", meals.count)
                self.allMeals = meals
                self.loadingState = .loaded
                self.generatePlan()
            }
        } catch {
            await MainActor.run {
                print("❌ loadMeals error:", error)
                self.loadingState = .error(error.localizedDescription)
            }
        }
    }

    // Features/Kitchen/KitchenViewModel.swift

    func generatePlan() {
        guard !allMeals.isEmpty else {
            print("⚠️ generatePlan: no meals available")
            return
        }

        do {
            let plan = try generator.generateDailyPlan(
                targetCalories: targetCalories,
                from: allMeals,
                excluding: currentPlan   // حتى يختار غير الوجبات السابقة
            )
            self.currentPlan = plan
            print("✅ Daily plan generated: \(plan.breakfast.name_ar), \(plan.lunch.name_ar), \(plan.dinner.name_ar)")
        } catch {
            print("❌ generatePlan error:", error)
        }
    }

    @discardableResult
    func saveCurrentPlan() -> Bool {
        guard currentPlan != nil else { return false }

        defaults.set(true, forKey: hasMealPlanKey)
        defaults.set(Date().timeIntervalSince1970, forKey: savedAtKey)
        NotificationCenter.default.post(name: .questKitchenPlanSaved, object: nil)
        return true
    }
}
