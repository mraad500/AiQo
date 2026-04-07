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
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        quantity: Double,
        unit: String? = nil,
        alchemyNoteKey: String? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.alchemyNoteKey = alchemyNoteKey
        self.updatedAt = updatedAt
    }

    var localizedAlchemyNote: String? {
        guard let alchemyNoteKey else { return nil }
        return alchemyNoteKey.localized
    }

    var emoji: String {
        IngredientEmojiResolver.emoji(for: name, fallback: "🧺")
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
    var ingredients: [KitchenIngredient]

    init(
        id: UUID = UUID(),
        dayIndex: Int,
        type: KitchenMealType,
        title: String,
        calories: Int? = nil,
        protein: Double? = nil,
        ingredients: [KitchenIngredient]
    ) {
        self.id = id
        self.dayIndex = dayIndex
        self.type = type
        self.title = title
        self.calories = calories
        self.protein = protein
        self.ingredients = ingredients
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
