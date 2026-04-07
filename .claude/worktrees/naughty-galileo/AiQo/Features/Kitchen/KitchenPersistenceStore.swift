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

    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private var isBootstrapping = false

    private let fridgeItemsKey = "aiqo.kitchen.fridge.items"
    private let pinnedPlanKey = "aiqo.kitchen.plan.pinned"
    private let shoppingListKey = "aiqo.kitchen.shopping.list"
    private let needsPurchaseOverridesKey = "aiqo.kitchen.needs.purchase"

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

    // MARK: - Private

    private func loadFromStorage() {
        isBootstrapping = true
        defer { isBootstrapping = false }

        fridgeItems = load([FridgeItem].self, fromKey: fridgeItemsKey) ?? []
        pinnedPlan = load(KitchenMealPlan.self, fromKey: pinnedPlanKey)
        shoppingList = load([ShoppingListItem].self, fromKey: shoppingListKey) ?? []

        let overridesArray = load([String].self, fromKey: needsPurchaseOverridesKey) ?? []
        needsPurchaseOverrides = Set(overridesArray)
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
