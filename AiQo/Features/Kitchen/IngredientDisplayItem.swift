import Foundation

struct IngredientDisplayItem: Identifiable, Equatable {
    let id: String
    let name: String
    let count: Int
    let quantityText: String?
    let ingredientKey: IngredientKey?
}

enum IngredientDisplayBuilder {
    static func mergedItems(from ingredients: [KitchenIngredient]) -> [IngredientDisplayItem] {
        var order: [String] = []
        var buckets: [String: Bucket] = [:]

        for ingredient in ingredients {
            let normalizedName = normalizedKey(for: ingredient.name)
            guard !normalizedName.isEmpty else { continue }

            if buckets[normalizedName] == nil {
                order.append(normalizedName)
                buckets[normalizedName] = Bucket(
                    displayName: ingredient.name,
                    count: 0,
                    totalAmount: 0,
                    unit: cleanedUnit(ingredient.unit),
                    canSumAmounts: ingredient.amount != nil,
                    firstQuantityText: quantityText(amount: ingredient.amount, unit: ingredient.unit),
                    hasQuantity: ingredient.amount != nil,
                    ingredientKey: IngredientCatalog.match(from: ingredient.name)
                )
            }

            guard var bucket = buckets[normalizedName] else { continue }
            bucket.count += 1
            if bucket.ingredientKey == nil {
                bucket.ingredientKey = IngredientCatalog.match(from: ingredient.name)
            }

            if let amount = ingredient.amount {
                let unit = cleanedUnit(ingredient.unit)
                if bucket.count == 1 {
                    bucket.totalAmount = amount
                    bucket.unit = unit
                } else if bucket.canSumAmounts && bucket.unit == unit {
                    bucket.totalAmount += amount
                } else {
                    bucket.canSumAmounts = false
                }
                bucket.hasQuantity = true
            } else if bucket.hasQuantity {
                bucket.canSumAmounts = false
            }

            buckets[normalizedName] = bucket
        }

        return order.compactMap { key in
            guard let bucket = buckets[key] else { return nil }
            return IngredientDisplayItem(
                id: key,
                name: bucket.displayName,
                count: bucket.count,
                quantityText: bucket.quantityDisplayText,
                ingredientKey: bucket.ingredientKey
            )
        }
    }

    static func mergedItems(from names: [String]) -> [IngredientDisplayItem] {
        var order: [String] = []
        var buckets: [String: (displayName: String, count: Int)] = [:]

        for name in names {
            let normalizedName = normalizedKey(for: name)
            guard !normalizedName.isEmpty else { continue }

            if buckets[normalizedName] == nil {
                order.append(normalizedName)
                buckets[normalizedName] = (displayName: name, count: 0)
            }

            buckets[normalizedName]?.count += 1
        }

        return order.compactMap { key in
            guard let bucket = buckets[key] else { return nil }
            return IngredientDisplayItem(
                id: key,
                name: bucket.displayName,
                count: bucket.count,
                quantityText: nil,
                ingredientKey: IngredientCatalog.match(from: bucket.displayName)
            )
        }
    }

    private static func normalizedKey(for text: String) -> String {
        IngredientCatalog.normalize(text)
    }

    private static func cleanedUnit(_ unit: String?) -> String? {
        guard let unit else { return nil }
        let trimmed = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func quantityText(amount: Double?, unit: String?) -> String? {
        guard let amount else { return nil }
        let value: String
        if amount.rounded() == amount {
            value = "\(Int(amount))"
        } else {
            value = String(format: "%.1f", amount)
        }

        if let unit = cleanedUnit(unit) {
            return "\(value) \(unit)"
        }

        return value
    }
}

private struct Bucket {
    var displayName: String
    var count: Int
    var totalAmount: Double
    var unit: String?
    var canSumAmounts: Bool
    var firstQuantityText: String?
    var hasQuantity: Bool
    var ingredientKey: IngredientKey?

    var quantityDisplayText: String? {
        guard hasQuantity else { return nil }
        if canSumAmounts {
            let value: String
            if totalAmount.rounded() == totalAmount {
                value = "\(Int(totalAmount))"
            } else {
                value = String(format: "%.1f", totalAmount)
            }

            if let unit, !unit.isEmpty {
                return "\(value) \(unit)"
            }
            return value
        }

        return firstQuantityText
    }
}
