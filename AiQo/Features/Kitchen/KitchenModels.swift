import Foundation

enum KitchenMealType: String, Codable, CaseIterable, Identifiable {
    case breakfast
    case lunch
    case dinner
    case snack

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .breakfast:
            return "screen.kitchen.breakfast".localized
        case .lunch:
            return "screen.kitchen.lunch".localized
        case .dinner:
            return "screen.kitchen.dinner".localized
        case .snack:
            return "kitchen.mealtype.snack".localized
        }
    }

    var defaultAssetImageName: String {
        switch self {
        case .breakfast:
            return "breakfast"
        case .lunch:
            return "lunch"
        case .dinner:
            return "dinner"
        case .snack:
            return "breakfast"
        }
    }

    var defaultSymbolName: String {
        switch self {
        case .breakfast:
            return "sunrise.fill"
        case .lunch:
            return "sun.max.fill"
        case .dinner:
            return "moon.stars.fill"
        case .snack:
            return "leaf.fill"
        }
    }

    var defaultCalories: Int {
        switch self {
        case .breakfast:
            return 380
        case .lunch:
            return 560
        case .dinner:
            return 430
        case .snack:
            return 180
        }
    }
}

enum IngredientAvailabilityState: String, Codable {
    case available
    case low
    case missing

    var icon: String {
        switch self {
        case .available:
            return "✅"
        case .low:
            return "⚠️"
        case .missing:
            return "❌"
        }
    }

    var localizedTitle: String {
        switch self {
        case .available:
            return "kitchen.availability.available".localized
        case .low:
            return "kitchen.availability.low".localized
        case .missing:
            return "kitchen.availability.missing".localized
        }
    }
}

struct FridgeItem: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var quantity: Double
    var unit: String?
    var alchemyNoteKey: String?
    var addedAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        quantity: Double,
        unit: String? = nil,
        alchemyNoteKey: String? = nil,
        addedAt: Date? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.alchemyNoteKey = alchemyNoteKey
        self.addedAt = addedAt ?? updatedAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id, name, quantity, unit, alchemyNoteKey, addedAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.name = try c.decode(String.self, forKey: .name)
        self.quantity = try c.decode(Double.self, forKey: .quantity)
        self.unit = try c.decodeIfPresent(String.self, forKey: .unit)
        self.alchemyNoteKey = try c.decodeIfPresent(String.self, forKey: .alchemyNoteKey)
        let updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        self.updatedAt = updatedAt
        self.addedAt = try c.decodeIfPresent(Date.self, forKey: .addedAt) ?? updatedAt
    }

    var localizedAlchemyNote: String? {
        guard let alchemyNoteKey else { return nil }
        return alchemyNoteKey.localized
    }

    var emoji: String {
        IngredientEmojiResolver.emoji(for: name, fallback: "🧺")
    }

    /// Days since the item first entered the fridge.
    func daysInFridge(now: Date = Date()) -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: addedAt)
        let end = calendar.startOfDay(for: now)
        return max(calendar.dateComponents([.day], from: start, to: end).day ?? 0, 0)
    }

    /// Lightweight freshness label. Categories are rough — purely a UX hint, not a safety guarantee.
    enum FreshnessState {
        case fresh
        case staleSoon
        case stale

        var icon: String {
            switch self {
            case .fresh:
                return ""
            case .staleSoon:
                return "⏳"
            case .stale:
                return "⚠️"
            }
        }
    }

    func freshness(now: Date = Date(), staleSoonAfterDays: Int = 5, staleAfterDays: Int = 8) -> FreshnessState {
        let days = daysInFridge(now: now)
        if days >= staleAfterDays {
            return .stale
        }
        if days >= staleSoonAfterDays {
            return .staleSoon
        }
        return .fresh
    }
}

struct KitchenIngredient: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var amount: Double?
    var unit: String?

    init(id: UUID = UUID(), name: String, amount: Double? = nil, unit: String? = nil) {
        self.id = id
        self.name = name
        self.amount = amount
        self.unit = unit
    }

    var emoji: String {
        IngredientEmojiResolver.emoji(for: name)
    }
}

struct KitchenPlannedMeal: Identifiable, Codable, Equatable {
    let id: UUID
    var dayIndex: Int
    var type: KitchenMealType
    var title: String
    var calories: Int?
    var protein: Double?
    var carbs: Double?
    var fat: Double?
    var fiber: Double?
    var ingredients: [KitchenIngredient]
    var steps: [String]
    var cookingMinutes: Int?

    init(
        id: UUID = UUID(),
        dayIndex: Int,
        type: KitchenMealType,
        title: String,
        calories: Int? = nil,
        protein: Double? = nil,
        carbs: Double? = nil,
        fat: Double? = nil,
        fiber: Double? = nil,
        ingredients: [KitchenIngredient],
        steps: [String] = [],
        cookingMinutes: Int? = nil
    ) {
        self.id = id
        self.dayIndex = dayIndex
        self.type = type
        self.title = title
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fiber = fiber
        self.ingredients = ingredients
        self.steps = steps
        self.cookingMinutes = cookingMinutes
    }

    enum CodingKeys: String, CodingKey {
        case id, dayIndex, type, title, calories, protein, carbs, fat, fiber
        case ingredients, steps, cookingMinutes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.dayIndex = try c.decode(Int.self, forKey: .dayIndex)
        self.type = try c.decode(KitchenMealType.self, forKey: .type)
        self.title = try c.decode(String.self, forKey: .title)
        self.calories = try c.decodeIfPresent(Int.self, forKey: .calories)
        self.protein = try c.decodeIfPresent(Double.self, forKey: .protein)
        self.carbs = try c.decodeIfPresent(Double.self, forKey: .carbs)
        self.fat = try c.decodeIfPresent(Double.self, forKey: .fat)
        self.fiber = try c.decodeIfPresent(Double.self, forKey: .fiber)
        self.ingredients = try c.decode([KitchenIngredient].self, forKey: .ingredients)
        self.steps = try c.decodeIfPresent([String].self, forKey: .steps) ?? []
        self.cookingMinutes = try c.decodeIfPresent(Int.self, forKey: .cookingMinutes)
    }

    var localImageName: String {
        let lowercasedTitle = title.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()

        if containsAny(["بيض", "egg", "omelette", "شوفان", "oat"], in: lowercasedTitle) {
            return "breakfast"
        }
        if containsAny(["ستيك", "beef", "لحم", "rice", "رز"], in: lowercasedTitle) {
            return "lunch"
        }
        if containsAny(["تونة", "tuna", "fish", "سمك", "salad", "سلطة", "chicken", "دجاج"], in: lowercasedTitle) {
            return "dinner"
        }

        return type.defaultAssetImageName
    }

    private func containsAny(_ needles: [String], in haystack: String) -> Bool {
        needles.contains(where: { haystack.contains($0) })
    }
}

struct KitchenMealPlan: Identifiable, Codable, Equatable {
    let id: UUID
    var startDate: Date
    var days: Int
    var meals: [KitchenPlannedMeal]

    init(id: UUID = UUID(), startDate: Date = Date(), days: Int, meals: [KitchenPlannedMeal]) {
        self.id = id
        self.startDate = startDate
        self.days = days
        self.meals = meals
    }
}

struct KitchenInsight: Identifiable, Equatable {
    enum Tone: Equatable {
        case positive
        case attention
        case warning
        case info
    }

    let id: String
    let tone: Tone
    let icon: String
    let title: String
    let detail: String
}

enum MealAdherenceState: String, Codable {
    case pending
    case ate
    case skipped
    case swapped

    var icon: String {
        switch self {
        case .pending:
            return "circle"
        case .ate:
            return "checkmark.circle.fill"
        case .skipped:
            return "xmark.circle.fill"
        case .swapped:
            return "arrow.triangle.2.circlepath.circle.fill"
        }
    }

    var localizedTitle: String {
        switch self {
        case .pending:
            return "kitchen.adherence.pending".localized
        case .ate:
            return "kitchen.adherence.ate".localized
        case .skipped:
            return "kitchen.adherence.skipped".localized
        case .swapped:
            return "kitchen.adherence.swapped".localized
        }
    }

    /// Whether this state contributes to today's nutrition totals.
    var countsTowardTotals: Bool {
        switch self {
        case .ate, .swapped:
            return true
        case .pending, .skipped:
            return false
        }
    }
}

struct MealAdherenceRecord: Codable, Equatable {
    var state: MealAdherenceState
    var loggedAt: Date

    init(state: MealAdherenceState, loggedAt: Date = Date()) {
        self.state = state
        self.loggedAt = loggedAt
    }
}

struct LoggedMeal: Identifiable, Codable, Equatable {
    let id: UUID
    var meal: KitchenPlannedMeal
    var loggedAt: Date
    var servings: Double

    init(
        id: UUID = UUID(),
        meal: KitchenPlannedMeal,
        loggedAt: Date = Date(),
        servings: Double = 1.0
    ) {
        self.id = id
        self.meal = meal
        self.loggedAt = loggedAt
        self.servings = max(0.25, servings)
    }

    enum CodingKeys: String, CodingKey {
        case id, meal, loggedAt, servings
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.meal = try c.decode(KitchenPlannedMeal.self, forKey: .meal)
        self.loggedAt = try c.decode(Date.self, forKey: .loggedAt)
        self.servings = try c.decodeIfPresent(Double.self, forKey: .servings) ?? 1.0
    }

    /// Returns the meal scaled by `servings` for accurate totals.
    var scaledMeal: KitchenPlannedMeal {
        guard servings != 1.0 else { return meal }
        var scaled = meal
        scaled.calories = meal.calories.map { Int(Double($0) * servings) }
        scaled.protein = meal.protein.map { $0 * servings }
        scaled.carbs = meal.carbs.map { $0 * servings }
        scaled.fat = meal.fat.map { $0 * servings }
        scaled.fiber = meal.fiber.map { $0 * servings }
        return scaled
    }
}

struct FavoriteMeal: Identifiable, Codable, Equatable {
    let id: UUID
    var meal: KitchenPlannedMeal
    var savedAt: Date
    var lastUsedAt: Date

    init(
        id: UUID = UUID(),
        meal: KitchenPlannedMeal,
        savedAt: Date = Date(),
        lastUsedAt: Date = Date()
    ) {
        self.id = id
        self.meal = meal
        self.savedAt = savedAt
        self.lastUsedAt = lastUsedAt
    }
}

struct WaterEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var cups: Int
    var loggedAt: Date

    init(id: UUID = UUID(), cups: Int = 1, loggedAt: Date = Date()) {
        self.id = id
        self.cups = max(1, cups)
        self.loggedAt = loggedAt
    }
}

struct ShoppingListItem: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var amount: Double?
    var unit: String?
    var isChecked: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        amount: Double? = nil,
        unit: String? = nil,
        isChecked: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.unit = unit
        self.isChecked = isChecked
        self.createdAt = createdAt
    }

    var emoji: String {
        IngredientEmojiResolver.emoji(for: name, fallback: "🛒")
    }
}
