import Foundation

struct KitchenPlanGenerationService {
    private let orchestrator: BrainOrchestrator

    init(orchestrator: BrainOrchestrator = BrainOrchestrator()) {
        self.orchestrator = orchestrator
    }

    func generatePlan(
        days: Int,
        triggerText: String,
        fridgeItems: [FridgeItem],
        userGoal: String?,
        cookingTimeMinutes: Int = 30
    ) async throws -> KitchenMealPlan {
        let normalizedDays = days == 7 ? 7 : 3
        let weeks = max(1, Int(ceil(Double(normalizedDays) / 7.0)))
        if !DevOverride.unlockAllFeatures {
            guard TierGate.shared.canAccess(.multiWeekPlan(weeks: weeks)) else {
                throw BrainError.tierRequired(TierGate.shared.requiredTier(for: .multiWeekPlan(weeks: weeks)))
            }
        }

        let prefersArabic = KitchenLanguageRouter.route(for: triggerText) == .arabicGPT
        let language: AppLanguage = prefersArabic ? .arabic : .english

        let prompt = buildStructuredPlanPrompt(
            days: normalizedDays,
            triggerText: triggerText,
            fridgeItems: fridgeItems,
            userGoal: userGoal,
            cookingTimeMinutes: cookingTimeMinutes
        )

        let request = HybridBrainRequest(
            conversation: [
                CaptainConversationMessage(role: .user, content: prompt)
            ],
            screenContext: .kitchen,
            language: language,
            contextData: CaptainContextData(steps: 0, calories: 0, vibe: "General", level: 1),
            userProfileSummary: "",
            intentSummary: triggerText,
            workingMemorySummary: "",
            attachedImageData: nil,
            purpose: .kitchen
        )

        do {
            let reply = try await orchestrator.processMessage(
                request: request,
                userName: kitchenUserFirstName()
            )

            if let parsed = parsePlan(from: reply.message, expectedDays: normalizedDays) {
                return parsed
            }

            if let mealPlan = reply.mealPlan,
               let mapped = mapCaptainMealPlan(
                   mealPlan,
                   expectedDays: normalizedDays
               ) {
                return mapped
            }
        } catch {
            // Fall back to deterministic local generation.
        }

        return deterministicFallbackPlan(
            days: normalizedDays,
            prefersArabic: prefersArabic,
            fridgeItems: fridgeItems
        )
    }

    // MARK: - Prompt Builders

    private func buildStructuredPlanPrompt(
        days: Int,
        triggerText: String,
        fridgeItems: [FridgeItem],
        userGoal: String?,
        cookingTimeMinutes: Int
    ) -> String {
        let goal = trimmedOrNil(userGoal) ?? "general fitness"

        return """
        You are Captain Hamoudi in Kitchen mode.
        Generate a \(days)-day meal plan and respond ONLY with valid JSON inside the message field.

        Rules:
        - Keep each day practical.
        - Use fridge ingredients first when possible.
        - Include breakfast, lunch, and dinner daily.
        - Ingredient names must be short.

        Context:
        - User goal: \(goal)
        - Preferred cooking time: \(cookingTimeMinutes) minutes
        - Fridge items: \(fridgeSnapshot(fridgeItems))
        - User trigger: \(triggerText)

        JSON schema (return this exact shape as the message value):
        {
          "days": \(days),
          "meals": [
            {
              "dayIndex": 1,
              "type": "breakfast|lunch|dinner|snack",
              "title": "Meal title",
              "calories": 450,
              "protein": 30,
              "carbs": 45,
              "fat": 15,
              "fiber": 5,
              "ingredients": [
                {
                  "name": "ingredient",
                  "amount": 1,
                  "unit": "cup"
                }
              ]
            }
          ]
        }
        """
    }

    private func fridgeSnapshot(_ fridgeItems: [FridgeItem]) -> String {
        guard !fridgeItems.isEmpty else { return "none" }

        return fridgeItems
            .map {
                let unit = (trimmedOrNil($0.unit) != nil)
                    ? " \(trimmedOrNil($0.unit) ?? "")"
                    : ""
                return "\($0.name): \(formatNumber($0.quantity))\(unit)"
            }
            .joined(separator: ", ")
    }

    // MARK: - Parsing

    private func parsePlan(from reply: String, expectedDays: Int) -> KitchenMealPlan? {
        guard let jsonString = extractJSONBlock(from: reply),
              let data = jsonString.data(using: .utf8),
              let payload = try? JSONDecoder().decode(GeneratedPlanPayload.self, from: data)
        else {
            return nil
        }

        let days = payload.days ?? expectedDays
        guard !payload.meals.isEmpty else { return nil }

        var mappedMeals: [KitchenPlannedMeal] = []
        for (index, rawMeal) in payload.meals.enumerated() {
            let dayIndexCandidate = rawMeal.dayIndex ?? rawMeal.day ?? (index / 3 + 1)
            let dayIndex = min(max(dayIndexCandidate, 1), expectedDays)

            let title = rawMeal.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { continue }

            let type = KitchenMealType.from(rawValue: rawMeal.type)
            let ingredients = (rawMeal.ingredients ?? [])
                .map { ingredient in
                    KitchenIngredient(
                        name: ingredient.name,
                        amount: ingredient.amount,
                        unit: ingredient.unit
                    )
                }
                .filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

            let resolvedIngredients = ingredients.isEmpty
                ? [KitchenIngredient(name: "Basic ingredients", amount: nil, unit: nil)]
                : ingredients

            mappedMeals.append(
                KitchenPlannedMeal(
                    dayIndex: dayIndex,
                    type: type,
                    title: title,
                    calories: rawMeal.calories,
                    protein: rawMeal.protein,
                    carbs: rawMeal.carbs,
                    fat: rawMeal.fat,
                    fiber: rawMeal.fiber,
                    ingredients: resolvedIngredients
                )
            )
        }

        guard !mappedMeals.isEmpty else { return nil }

        return KitchenMealPlan(startDate: Date(), days: min(max(days, 3), 7), meals: mappedMeals)
    }

    private func mapCaptainMealPlan(
        _ mealPlan: MealPlan,
        expectedDays: Int
    ) -> KitchenMealPlan? {
        guard !mealPlan.meals.isEmpty else { return nil }

        var mappedMeals: [KitchenPlannedMeal] = []
        for (index, meal) in mealPlan.meals.enumerated() {
            let dayIndex = min(max(index / 3 + 1, 1), expectedDays)
            let type = KitchenMealType.from(rawValue: meal.type)
            let title = meal.description.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { continue }

            mappedMeals.append(
                KitchenPlannedMeal(
                    dayIndex: dayIndex,
                    type: type,
                    title: title,
                    calories: meal.calories,
                    ingredients: [KitchenIngredient(name: "Basic ingredients", amount: nil, unit: nil)]
                )
            )
        }

        guard !mappedMeals.isEmpty else { return nil }

        return KitchenMealPlan(startDate: Date(), days: expectedDays, meals: mappedMeals)
    }

    private func extractJSONBlock(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.hasPrefix("```") {
            let components = trimmed.components(separatedBy: "```")
            for block in components where !block.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let cleaned = block
                    .replacingOccurrences(of: "json", with: "", options: [.caseInsensitive])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if cleaned.first == "{" && cleaned.last == "}" {
                    return cleaned
                }
            }
        }

        guard let start = trimmed.firstIndex(of: "{"),
              let end = trimmed.lastIndex(of: "}")
        else {
            return nil
        }

        return String(trimmed[start...end])
    }

    // MARK: - Fallback Plan

    private func deterministicFallbackPlan(
        days: Int,
        prefersArabic: Bool,
        fridgeItems: [FridgeItem]
    ) -> KitchenMealPlan {
        var meals: [KitchenPlannedMeal] = []

        for day in 1...days {
            for type in [KitchenMealType.breakfast, .lunch, .dinner] {
                let template = fallbackTemplate(type: type, dayIndex: day, prefersArabic: prefersArabic)
                var ingredients = template.ingredients

                if let fridgeSuggestion = fridgeItems.first(where: { $0.quantity > 0 }) {
                    ingredients.insert(
                        KitchenIngredient(name: fridgeSuggestion.name, amount: 1, unit: fridgeSuggestion.unit),
                        at: 0
                    )
                }

                meals.append(
                    KitchenPlannedMeal(
                        dayIndex: day,
                        type: type,
                        title: template.title,
                        calories: template.calories,
                        protein: template.protein,
                        ingredients: ingredients
                    )
                )
            }
        }

        return KitchenMealPlan(startDate: Date(), days: days, meals: meals)
    }

    private func fallbackTemplate(
        type: KitchenMealType,
        dayIndex: Int,
        prefersArabic: Bool
    ) -> (title: String, calories: Int, protein: Double, ingredients: [KitchenIngredient]) {
        switch type {
        case .breakfast:
            if prefersArabic {
                return (
                    title: dayIndex % 2 == 0 ? "لبن يوناني مع شوفان" : "بيض مخفوق مع خبز أسمر",
                    calories: 380,
                    protein: 24,
                    ingredients: [
                        KitchenIngredient(name: "بيض", amount: 2, unit: "حبة"),
                        KitchenIngredient(name: "شوفان", amount: 0.5, unit: "كوب"),
                        KitchenIngredient(name: "خضار", amount: 1, unit: "كوب")
                    ]
                )
            }
            return (
                title: dayIndex % 2 == 0 ? "Greek yogurt with oats" : "Scrambled eggs with wholegrain toast",
                calories: 380,
                protein: 24,
                ingredients: [
                    KitchenIngredient(name: "Eggs", amount: 2, unit: "pcs"),
                    KitchenIngredient(name: "Oats", amount: 0.5, unit: "cup"),
                    KitchenIngredient(name: "Vegetables", amount: 1, unit: "cup")
                ]
            )

        case .lunch:
            if prefersArabic {
                return (
                    title: dayIndex % 2 == 0 ? "دجاج مشوي مع رز" : "ستيك مع خضار مطبوخة",
                    calories: 560,
                    protein: 42,
                    ingredients: [
                        KitchenIngredient(name: "صدر دجاج", amount: 200, unit: "غم"),
                        KitchenIngredient(name: "رز", amount: 1, unit: "كوب"),
                        KitchenIngredient(name: "بروكلي", amount: 1, unit: "كوب")
                    ]
                )
            }
            return (
                title: dayIndex % 2 == 0 ? "Grilled chicken and rice" : "Steak with cooked vegetables",
                calories: 560,
                protein: 42,
                ingredients: [
                    KitchenIngredient(name: "Chicken breast", amount: 200, unit: "g"),
                    KitchenIngredient(name: "Rice", amount: 1, unit: "cup"),
                    KitchenIngredient(name: "Broccoli", amount: 1, unit: "cup")
                ]
            )

        case .dinner:
            if prefersArabic {
                return (
                    title: dayIndex % 2 == 0 ? "تونة مع سلطة" : "سمك مشوي مع بطاطا",
                    calories: 430,
                    protein: 34,
                    ingredients: [
                        KitchenIngredient(name: "تونة", amount: 1, unit: "علبة"),
                        KitchenIngredient(name: "خس", amount: 1, unit: "كوب"),
                        KitchenIngredient(name: "خيار", amount: 1, unit: "حبة")
                    ]
                )
            }
            return (
                title: dayIndex % 2 == 0 ? "Tuna salad" : "Grilled fish with potatoes",
                calories: 430,
                protein: 34,
                ingredients: [
                    KitchenIngredient(name: "Tuna", amount: 1, unit: "can"),
                    KitchenIngredient(name: "Lettuce", amount: 1, unit: "cup"),
                    KitchenIngredient(name: "Cucumber", amount: 1, unit: "pc")
                ]
            )

        case .snack:
            if prefersArabic {
                return (
                    title: "سناك سريع",
                    calories: 180,
                    protein: 10,
                    ingredients: [KitchenIngredient(name: "مكسرات", amount: 30, unit: "غم")]
                )
            }
            return (
                title: "Quick snack",
                calories: 180,
                protein: 10,
                ingredients: [KitchenIngredient(name: "Nuts", amount: 30, unit: "g")]
            )
        }
    }

    private func formatNumber(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }

    private func trimmedOrNil(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func kitchenUserFirstName() -> String? {
        let raw = UserProfileStore.shared.current.name
            .components(separatedBy: " ")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let raw, !raw.isEmpty else { return nil }
        return raw
    }
}

private struct GeneratedPlanPayload: Decodable {
    let days: Int?
    let meals: [GeneratedMealPayload]
}

private struct GeneratedMealPayload: Decodable {
    let dayIndex: Int?
    let day: Int?
    let type: String
    let title: String
    let calories: Int?
    let protein: Double?
    let carbs: Double?
    let fat: Double?
    let fiber: Double?
    let ingredients: [GeneratedIngredientPayload]?
}

private struct GeneratedIngredientPayload: Decodable {
    let name: String
    let amount: Double?
    let unit: String?
}

private extension KitchenMealType {
    static func from(rawValue: String) -> KitchenMealType {
        let normalized = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        switch normalized {
        case "breakfast", "fatoor", "فطور", "الفطور":
            return .breakfast
        case "lunch", "ghada", "غداء", "الغداء":
            return .lunch
        case "dinner", "asha", "عشاء", "العشاء":
            return .dinner
        case "snack", "سناك", "خفيفة":
            return .snack
        default:
            return .lunch
        }
    }
}
