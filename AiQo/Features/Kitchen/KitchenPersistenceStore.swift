import Foundation
import SwiftUI
import Combine

@MainActor
final class KitchenPersistenceStore: ObservableObject {
    @Published var fridgeItems: [FridgeItem] = [] {
        didSet {
            guard !isBootstrapping else { return }
            persist(fridgeItems, forKey: fridgeItemsKey)
        }
    }

    @Published var pinnedPlan: KitchenMealPlan? {
        didSet {
            guard !isBootstrapping else { return }
            persistOptional(pinnedPlan, forKey: pinnedPlanKey)
        }
    }

    @Published var shoppingList: [ShoppingListItem] = [] {
        didSet {
            guard !isBootstrapping else { return }
            persist(shoppingList, forKey: shoppingListKey)
        }
    }

    @Published var needsPurchaseOverrides: Set<String> = [] {
        didSet {
            guard !isBootstrapping else { return }
            persist(Array(needsPurchaseOverrides), forKey: needsPurchaseOverridesKey)
        }
    }

    @Published var loggedMeals: [LoggedMeal] = [] {
        didSet {
            guard !isBootstrapping else { return }
            persist(loggedMeals, forKey: loggedMealsKey)
        }
    }

    @Published var adherence: [String: MealAdherenceRecord] = [:] {
        didSet {
            guard !isBootstrapping else { return }
            persist(adherence, forKey: adherenceKey)
        }
    }

    @Published var waterEntries: [WaterEntry] = [] {
        didSet {
            guard !isBootstrapping else { return }
            persist(waterEntries, forKey: waterEntriesKey)
        }
    }

    @Published var favoriteMeals: [FavoriteMeal] = [] {
        didSet {
            guard !isBootstrapping else { return }
            persist(favoriteMeals, forKey: favoriteMealsKey)
        }
    }

    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private var isBootstrapping = false

    private let fridgeItemsKey = "aiqo.kitchen.fridge.items"
    private let pinnedPlanKey = "aiqo.kitchen.plan.pinned"
    private let shoppingListKey = "aiqo.kitchen.shopping.list"
    private let needsPurchaseOverridesKey = "aiqo.kitchen.needs.purchase"
    private let loggedMealsKey = "aiqo.kitchen.log.meals"
    private let adherenceKey = "aiqo.kitchen.adherence"
    private let waterEntriesKey = "aiqo.kitchen.water.entries"
    private let favoriteMealsKey = "aiqo.kitchen.favorites"

    private let questHasMealPlanKey = "aiqo.quest.kitchen.hasMealPlan"
    private let questSavedAtKey = "aiqo.quest.kitchen.savedAt"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()

        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601

        loadFromStorage()
    }

    func addFridgeItem(name: String, quantity: Double, unit: String?) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let normalized = normalizedName(trimmedName)
        if let index = fridgeItems.firstIndex(where: { normalizedName($0.name) == normalized }) {
            fridgeItems[index].quantity += max(0, quantity)
            if let unit, !unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                fridgeItems[index].unit = unit
            }
            fridgeItems[index].updatedAt = Date()
        } else {
            fridgeItems.append(
                FridgeItem(
                    name: trimmedName,
                    quantity: max(0, quantity),
                    unit: cleanedUnit(unit),
                    updatedAt: Date()
                )
            )
        }
    }

    func addFridgeItems(_ items: [FridgeItem]) {
        for item in items {
            addOrMergeFridgeItem(item)
        }
    }

    func removeFridgeItems(at offsets: IndexSet) {
        fridgeItems.remove(atOffsets: offsets)
    }

    func removeFridgeItem(id: UUID) {
        fridgeItems.removeAll { $0.id == id }
    }

    func updateFridgeItemQuantity(id: UUID, quantity: Double) {
        guard let index = fridgeItems.firstIndex(where: { $0.id == id }) else { return }
        fridgeItems[index].quantity = max(0, quantity)
        fridgeItems[index].updatedAt = Date()
    }

    func incrementFridgeItem(id: UUID, by step: Double = 1) {
        guard let index = fridgeItems.firstIndex(where: { $0.id == id }) else { return }
        fridgeItems[index].quantity += max(0, step)
        fridgeItems[index].updatedAt = Date()
    }

    func decrementFridgeItem(id: UUID, by step: Double = 1) {
        guard let index = fridgeItems.firstIndex(where: { $0.id == id }) else { return }
        fridgeItems[index].quantity = max(0, fridgeItems[index].quantity - max(0, step))
        fridgeItems[index].updatedAt = Date()
    }

    func setPinnedPlan(_ plan: KitchenMealPlan) {
        pinnedPlan = plan

        // Quest compatibility bridge.
        defaults.set(true, forKey: questHasMealPlanKey)
        defaults.set(Date().timeIntervalSince1970, forKey: questSavedAtKey)
        NotificationCenter.default.post(name: .questKitchenPlanSaved, object: nil)
    }

    func clearPinnedPlan() {
        pinnedPlan = nil
    }

    func addShoppingItem(name: String, amount: Double? = nil, unit: String? = nil) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let normalized = normalizedName(trimmedName)
        if let index = shoppingList.firstIndex(where: { normalizedName($0.name) == normalized }) {
            if let amount, amount > 0 {
                shoppingList[index].amount = amount
            }
            if let unit, !unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                shoppingList[index].unit = unit
            }
            return
        }

        shoppingList.append(
            ShoppingListItem(
                name: trimmedName,
                amount: amount,
                unit: cleanedUnit(unit),
                isChecked: false,
                createdAt: Date()
            )
        )
    }

    func addIngredientToShoppingList(_ ingredient: KitchenIngredient) {
        addShoppingItem(name: ingredient.name, amount: ingredient.amount, unit: ingredient.unit)
    }

    func containsShoppingItem(named name: String) -> Bool {
        let normalized = normalizedName(name)
        return shoppingList.contains { normalizedName($0.name) == normalized }
    }

    func addMissingIngredientsToShoppingList() {
        guard let pinnedPlan else { return }
        let missing = missingIngredients(in: pinnedPlan)
        for ingredient in missing {
            addIngredientToShoppingList(ingredient)
        }
    }

    func removeShoppingItems(at offsets: IndexSet) {
        shoppingList.remove(atOffsets: offsets)
    }

    func toggleShoppingItem(_ itemID: UUID) {
        guard let index = shoppingList.firstIndex(where: { $0.id == itemID }) else { return }
        shoppingList[index].isChecked.toggle()
    }

    func availability(for ingredient: KitchenIngredient) -> IngredientAvailabilityState {
        let normalizedIngredientName = normalizedName(ingredient.name)
        guard let fridgeItem = fridgeItems.first(where: { normalizedName($0.name) == normalizedIngredientName }) else {
            return .missing
        }

        if let requiredAmount = ingredient.amount, requiredAmount > 0, fridgeItem.quantity < requiredAmount {
            return .low
        }

        return .available
    }

    func missingIngredients(in plan: KitchenMealPlan) -> [KitchenIngredient] {
        var unique: [String: KitchenIngredient] = [:]

        for meal in plan.meals {
            for ingredient in meal.ingredients {
                guard availability(for: ingredient) == .missing else { continue }
                guard !isMarkedAsNeedsPurchase(mealID: meal.id, ingredientName: ingredient.name) else { continue }

                let key = normalizedName(ingredient.name)
                if unique[key] == nil {
                    unique[key] = ingredient
                }
            }
        }

        return Array(unique.values)
    }

    func replacementSuggestion(for ingredient: KitchenIngredient) -> KitchenIngredient? {
        let current = normalizedName(ingredient.name)
        guard let candidate = fridgeItems.first(where: {
            $0.quantity > 0 && normalizedName($0.name) != current
        }) else {
            return nil
        }

        return KitchenIngredient(name: candidate.name, amount: ingredient.amount, unit: ingredient.unit)
    }

    @discardableResult
    func replaceIngredient(mealID: UUID, ingredientName: String) -> Bool {
        guard var pinnedPlan else { return false }

        guard let mealIndex = pinnedPlan.meals.firstIndex(where: { $0.id == mealID }) else {
            return false
        }

        guard let ingredientIndex = pinnedPlan.meals[mealIndex].ingredients.firstIndex(where: {
            normalizedName($0.name) == normalizedName(ingredientName)
        }) else {
            return false
        }

        let oldIngredient = pinnedPlan.meals[mealIndex].ingredients[ingredientIndex]
        guard let replacement = replacementSuggestion(for: oldIngredient) else {
            return false
        }

        pinnedPlan.meals[mealIndex].ingredients[ingredientIndex] = replacement
        let oldKey = needsPurchaseKey(mealID: mealID, ingredientName: oldIngredient.name)
        needsPurchaseOverrides.remove(oldKey)

        self.pinnedPlan = pinnedPlan
        return true
    }

    func markAsNeedsPurchase(mealID: UUID, ingredientName: String) {
        needsPurchaseOverrides.insert(needsPurchaseKey(mealID: mealID, ingredientName: ingredientName))
    }

    func isMarkedAsNeedsPurchase(mealID: UUID, ingredientName: String) -> Bool {
        needsPurchaseOverrides.contains(needsPurchaseKey(mealID: mealID, ingredientName: ingredientName))
    }

    // MARK: - Daily Food Log

    func logManualMeal(_ meal: KitchenPlannedMeal, servings: Double = 1.0, loggedAt: Date = Date()) {
        loggedMeals.append(LoggedMeal(meal: meal, loggedAt: loggedAt, servings: servings))
    }

    func updateLoggedMealServings(id: UUID, servings: Double) {
        guard let index = loggedMeals.firstIndex(where: { $0.id == id }) else { return }
        loggedMeals[index].servings = max(0.25, servings)
    }

    func removeLoggedMeal(id: UUID) {
        loggedMeals.removeAll { $0.id == id }
    }

    func loggedMealsToday(now: Date = Date()) -> [LoggedMeal] {
        let calendar = Calendar.current
        return loggedMeals
            .filter { calendar.isDate($0.loggedAt, inSameDayAs: now) }
            .sorted { $0.loggedAt < $1.loggedAt }
    }

    // MARK: - Adherence

    func adherenceState(for mealID: UUID, on date: Date = Date()) -> MealAdherenceState {
        adherence[adherenceKey(mealID: mealID, date: date)]?.state ?? .pending
    }

    func setAdherence(_ state: MealAdherenceState, for mealID: UUID, on date: Date = Date()) {
        let key = adherenceKey(mealID: mealID, date: date)
        if state == .pending {
            adherence.removeValue(forKey: key)
        } else {
            adherence[key] = MealAdherenceRecord(state: state, loggedAt: Date())
        }
    }

    /// Planned meals from the pinned plan that the user marked as eaten today (or swapped — still counts).
    func adheredPlannedMealsToday(now: Date = Date()) -> [KitchenPlannedMeal] {
        guard let plan = pinnedPlan else { return [] }
        let calendar = Calendar.current
        let dayOffset = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: plan.startDate),
            to: calendar.startOfDay(for: now)
        ).day ?? 0
        let activeDay = min(max(dayOffset + 1, 1), max(plan.days, 1))

        return plan.meals
            .filter { $0.dayIndex == activeDay }
            .filter { adherenceState(for: $0.id, on: now).countsTowardTotals }
    }

    private func adherenceKey(mealID: UUID, date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return "\(mealID.uuidString.lowercased())|\(formatter.string(from: date))"
    }

    // MARK: - Water Tracking

    func addWaterCup(now: Date = Date()) {
        waterEntries.append(WaterEntry(cups: 1, loggedAt: now))
    }

    func removeWaterEntry(id: UUID) {
        waterEntries.removeAll { $0.id == id }
    }

    func removeLastWaterCupToday(now: Date = Date()) {
        let calendar = Calendar.current
        guard let last = waterEntries
            .filter({ calendar.isDate($0.loggedAt, inSameDayAs: now) })
            .max(by: { $0.loggedAt < $1.loggedAt })
        else { return }
        removeWaterEntry(id: last.id)
    }

    func waterCupsToday(now: Date = Date()) -> Int {
        let calendar = Calendar.current
        return waterEntries
            .filter { calendar.isDate($0.loggedAt, inSameDayAs: now) }
            .map(\.cups)
            .reduce(0, +)
    }

    // MARK: - Fridge Expiry

    /// Items that have been sitting in the fridge long enough to need attention. Excludes pantry-style essentials.
    func staleFridgeItems(now: Date = Date()) -> [FridgeItem] {
        fridgeItems.filter { item in
            switch item.freshness(now: now) {
            case .fresh:
                return false
            case .staleSoon, .stale:
                return !isPantryEssential(item)
            }
        }
        .sorted { $0.daysInFridge() > $1.daysInFridge() }
    }

    // MARK: - Favorites

    func toggleFavorite(_ meal: KitchenPlannedMeal) {
        if let index = favoriteMeals.firstIndex(where: { $0.meal.id == meal.id || mealsAreSimilar($0.meal, meal) }) {
            favoriteMeals.remove(at: index)
        } else {
            favoriteMeals.append(FavoriteMeal(meal: meal))
        }
    }

    func isFavorite(_ meal: KitchenPlannedMeal) -> Bool {
        favoriteMeals.contains(where: { $0.meal.id == meal.id || mealsAreSimilar($0.meal, meal) })
    }

    func touchFavorite(id: UUID) {
        guard let index = favoriteMeals.firstIndex(where: { $0.id == id }) else { return }
        favoriteMeals[index].lastUsedAt = Date()
    }

    func recentlyUsedFavorites(limit: Int = 6) -> [FavoriteMeal] {
        favoriteMeals
            .sorted { $0.lastUsedAt > $1.lastUsedAt }
            .prefix(limit)
            .map { $0 }
    }

    /// Recently logged manual meals — used for "log again" suggestions in the add-meal sheet.
    func recentlyLoggedMeals(limit: Int = 5, now: Date = Date()) -> [KitchenPlannedMeal] {
        var seenTitles: Set<String> = []
        var result: [KitchenPlannedMeal] = []
        let recent = loggedMeals.sorted { $0.loggedAt > $1.loggedAt }

        for entry in recent {
            let key = entry.meal.title.lowercased()
            if seenTitles.contains(key) { continue }
            seenTitles.insert(key)
            result.append(entry.meal)
            if result.count >= limit { break }
        }
        return result
    }

    private func mealsAreSimilar(_ a: KitchenPlannedMeal, _ b: KitchenPlannedMeal) -> Bool {
        let titleA = a.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let titleB = b.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return titleA == titleB && a.type == b.type
    }

    // MARK: - Streak + Weekly Snapshot

    struct DailyNutrition: Identifiable, Equatable {
        var id: Date { day }
        let day: Date
        let calories: Int
        let protein: Double
        let carbs: Double
        let fat: Double
        let waterCups: Int
        let met80PctGoal: Bool
    }

    /// Returns the user's running streak: consecutive days where the user reached
    /// at least 80% of their kcal goal. Today is a grace day — if nothing has been
    /// logged yet today, we don't break the streak; we just look at yesterday.
    func currentStreak(calorieGoal: Int, now: Date = Date()) -> Int {
        let calendar = Calendar.current
        var streak = 0
        var cursor = calendar.startOfDay(for: now)

        while true {
            let snapshot = nutritionSnapshot(for: cursor, calorieGoal: calorieGoal)
            let isToday = calendar.isDate(cursor, inSameDayAs: now)

            if isToday && snapshot.calories == 0 {
                guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
                cursor = previous
                continue
            }

            if snapshot.met80PctGoal {
                streak += 1
                guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
                cursor = previous
            } else {
                break
            }
        }

        return streak
    }

    func nutritionSnapshot(for day: Date, calorieGoal: Int) -> DailyNutrition {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: day)

        let logged = loggedMeals.filter { calendar.isDate($0.loggedAt, inSameDayAs: dayStart) }
        let plannedAdhered = adherentPlannedMeals(forDay: dayStart)

        var calories = 0
        var protein = 0.0
        var carbs = 0.0
        var fat = 0.0

        for entry in logged {
            let scaled = entry.scaledMeal
            calories += scaled.calories ?? 0
            protein += scaled.protein ?? 0
            carbs += scaled.carbs ?? 0
            fat += scaled.fat ?? 0
        }

        for meal in plannedAdhered {
            calories += meal.calories ?? 0
            protein += meal.protein ?? 0
            carbs += meal.carbs ?? 0
            fat += meal.fat ?? 0
        }

        let waterCups = waterEntries
            .filter { calendar.isDate($0.loggedAt, inSameDayAs: dayStart) }
            .map(\.cups)
            .reduce(0, +)

        let goal = max(calorieGoal, 1)
        let met80 = Double(calories) >= 0.8 * Double(goal) && Double(calories) <= 1.15 * Double(goal)

        return DailyNutrition(
            day: dayStart,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            waterCups: waterCups,
            met80PctGoal: met80
        )
    }

    func weeklySnapshot(calorieGoal: Int, now: Date = Date()) -> [DailyNutrition] {
        let calendar = Calendar.current
        return (0..<7).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: now) else { return nil }
            return nutritionSnapshot(for: day, calorieGoal: calorieGoal)
        }
    }

    // MARK: - Insights

    struct InsightInputs {
        let calorieGoal: Int
        let proteinGoal: Double
        let waterGoal: Int
    }

    /// Returns up to 3 actionable insights for today, ranked by importance.
    func computeInsights(inputs: InsightInputs, now: Date = Date()) -> [KitchenInsight] {
        let snapshot = nutritionSnapshot(for: now, calorieGoal: inputs.calorieGoal)
        let streak = currentStreak(calorieGoal: inputs.calorieGoal, now: now)
        let stale = staleFridgeItems(now: now)

        let calendar = Calendar.current
        let plannedToday = pinnedPlan.map { plan -> [KitchenPlannedMeal] in
            let dayOffset = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: plan.startDate),
                to: calendar.startOfDay(for: now)
            ).day ?? 0
            let activeDay = dayOffset + 1
            guard activeDay >= 1 && activeDay <= plan.days else { return [] }
            return plan.meals.filter { $0.dayIndex == activeDay }
        } ?? []

        let skippedToday = plannedToday.filter { adherenceState(for: $0.id, on: now) == .skipped }
        let pendingToday = plannedToday.filter { adherenceState(for: $0.id, on: now) == .pending }

        var insights: [KitchenInsight] = []

        // 1) Streak motivation (highest priority when active)
        if streak >= 3 {
            insights.append(
                KitchenInsight(
                    id: "streak",
                    tone: .positive,
                    icon: "flame.fill",
                    title: String(format: "kitchen.insight.streak.title".localized, streak),
                    detail: "kitchen.insight.streak.detail".localized
                )
            )
        }

        // 2) Calorie balance
        let kcalRemaining = inputs.calorieGoal - snapshot.calories
        let kcalOver = -kcalRemaining
        let isLateInDay = calendar.component(.hour, from: now) >= 19

        if kcalOver > 150 {
            insights.append(
                KitchenInsight(
                    id: "kcal-over",
                    tone: .warning,
                    icon: "exclamationmark.triangle.fill",
                    title: String(format: "kitchen.insight.kcalOver.title".localized, kcalOver),
                    detail: "kitchen.insight.kcalOver.detail".localized
                )
            )
        } else if isLateInDay && Double(snapshot.calories) < 0.6 * Double(inputs.calorieGoal) && snapshot.calories > 0 {
            insights.append(
                KitchenInsight(
                    id: "kcal-low",
                    tone: .attention,
                    icon: "fork.knife",
                    title: String(format: "kitchen.insight.kcalLow.title".localized, kcalRemaining),
                    detail: "kitchen.insight.kcalLow.detail".localized
                )
            )
        }

        // 3) Protein gap
        let proteinDeficit = inputs.proteinGoal - snapshot.protein
        if proteinDeficit >= 30 && snapshot.calories > 200 {
            insights.append(
                KitchenInsight(
                    id: "protein-gap",
                    tone: .attention,
                    icon: "fish.fill",
                    title: String(format: "kitchen.insight.proteinGap.title".localized, Int(proteinDeficit)),
                    detail: "kitchen.insight.proteinGap.detail".localized
                )
            )
        }

        // 4) Hydration
        let waterRemaining = inputs.waterGoal - snapshot.waterCups
        if waterRemaining >= 4 && calendar.component(.hour, from: now) >= 12 {
            insights.append(
                KitchenInsight(
                    id: "hydration",
                    tone: .info,
                    icon: "drop.fill",
                    title: String(format: "kitchen.insight.water.title".localized, waterRemaining),
                    detail: "kitchen.insight.water.detail".localized
                )
            )
        }

        // 5) Skipped meal nudge
        if let skipped = skippedToday.first {
            insights.append(
                KitchenInsight(
                    id: "skipped-\(skipped.id.uuidString)",
                    tone: .info,
                    icon: "arrow.uturn.left.circle.fill",
                    title: String(format: "kitchen.insight.skipped.title".localized, skipped.type.localizedTitle),
                    detail: "kitchen.insight.skipped.detail".localized
                )
            )
        }

        // 6) Stale fridge items
        if stale.count >= 2 {
            insights.append(
                KitchenInsight(
                    id: "stale-fridge",
                    tone: .attention,
                    icon: "refrigerator.fill",
                    title: String(format: "kitchen.insight.staleFridge.title".localized, stale.count),
                    detail: "kitchen.insight.staleFridge.detail".localized
                )
            )
        }

        // 7) Pending meals reminder mid-day
        if !pendingToday.isEmpty && plannedToday.count > pendingToday.count {
            // already eating, just nudging the rest — lower priority, only if no other insights
            if insights.count < 2 {
                insights.append(
                    KitchenInsight(
                        id: "pending-meals",
                        tone: .info,
                        icon: "list.bullet.rectangle",
                        title: String(format: "kitchen.insight.pending.title".localized, pendingToday.count),
                        detail: "kitchen.insight.pending.detail".localized
                    )
                )
            }
        }

        return Array(insights.prefix(3))
    }

    private func adherentPlannedMeals(forDay day: Date) -> [KitchenPlannedMeal] {
        guard let plan = pinnedPlan else { return [] }
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: day)

        let dayOffset = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: plan.startDate),
            to: startOfDay
        ).day ?? 0
        let activeDay = dayOffset + 1
        guard activeDay >= 1 && activeDay <= plan.days else { return [] }

        return plan.meals
            .filter { $0.dayIndex == activeDay }
            .filter { adherenceState(for: $0.id, on: startOfDay).countsTowardTotals }
    }

    private func isPantryEssential(_ item: FridgeItem) -> Bool {
        guard let key = IngredientCatalog.match(from: item.name) else {
            return false
        }
        switch key.category {
        case .carb, .fat, .drink, .other:
            return true
        case .protein, .dairy, .veg, .fruit:
            return false
        }
    }

    // MARK: - Private

    private func loadFromStorage() {
        isBootstrapping = true
        defer { isBootstrapping = false }

        fridgeItems = load([FridgeItem].self, fromKey: fridgeItemsKey) ?? []
        pinnedPlan = load(KitchenMealPlan.self, fromKey: pinnedPlanKey)
        shoppingList = load([ShoppingListItem].self, fromKey: shoppingListKey) ?? []

        let overridesArray = load([String].self, fromKey: needsPurchaseOverridesKey) ?? []
        needsPurchaseOverrides = Set(overridesArray)

        loggedMeals = load([LoggedMeal].self, fromKey: loggedMealsKey) ?? []
        adherence = load([String: MealAdherenceRecord].self, fromKey: adherenceKey) ?? [:]
        waterEntries = load([WaterEntry].self, fromKey: waterEntriesKey) ?? []
        favoriteMeals = load([FavoriteMeal].self, fromKey: favoriteMealsKey) ?? []

        pruneStaleEntries()
    }

    /// Drop log/water/adherence rows older than 30 days so storage doesn't grow forever.
    private func pruneStaleEntries() {
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()

        let filteredLogs = loggedMeals.filter { $0.loggedAt >= cutoff }
        if filteredLogs.count != loggedMeals.count {
            loggedMeals = filteredLogs
        }

        let filteredWater = waterEntries.filter { $0.loggedAt >= cutoff }
        if filteredWater.count != waterEntries.count {
            waterEntries = filteredWater
        }

        let filteredAdherence = adherence.filter { _, record in record.loggedAt >= cutoff }
        if filteredAdherence.count != adherence.count {
            adherence = filteredAdherence
        }
    }

    private func load<T: Decodable>(_ type: T.Type, fromKey key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    private func persist<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? encoder.encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    private func persistOptional<T: Encodable>(_ value: T?, forKey key: String) {
        guard let value else {
            defaults.removeObject(forKey: key)
            return
        }
        persist(value, forKey: key)
    }

    private func normalizedName(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }

    private func cleanedUnit(_ unit: String?) -> String? {
        guard let unit else { return nil }
        let trimmed = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func needsPurchaseKey(mealID: UUID, ingredientName: String) -> String {
        "\(mealID.uuidString.lowercased())|\(normalizedName(ingredientName))"
    }

    private func addOrMergeFridgeItem(_ item: FridgeItem) {
        let trimmedName = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let normalized = normalizedName(trimmedName)
        if let index = fridgeItems.firstIndex(where: { normalizedName($0.name) == normalized }) {
            fridgeItems[index].quantity += max(0, item.quantity)
            if let unit = cleanedUnit(item.unit) {
                fridgeItems[index].unit = unit
            }
            if let alchemyNoteKey = item.alchemyNoteKey {
                fridgeItems[index].alchemyNoteKey = alchemyNoteKey
            }
            fridgeItems[index].updatedAt = Date()
        } else {
            fridgeItems.append(
                FridgeItem(
                    name: trimmedName,
                    quantity: max(0, item.quantity),
                    unit: cleanedUnit(item.unit),
                    alchemyNoteKey: item.alchemyNoteKey,
                    updatedAt: Date()
                )
            )
        }
    }
}
