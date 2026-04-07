// Features/Kitchen/LocalMealsRepository.swift

import Foundation

// هذا الريبو يقرأ الوجبات من ملف JSON داخل الباندل
final class LocalMealsRepository: MealsRepository {

    // MARK: - Public

    func fetchAllMeals() async throws -> [Meal] {
        print("📂 LocalMealsRepository: trying to load meals_data.json ...")

        // نحاول نجيب الـ URL مال ملف JSON من الباندل
        guard let url = Bundle.main.url(forResource: "meals_data", withExtension: "json") else {
            print("❌ LocalMealsRepository: meals_data.json NOT FOUND in bundle")
            return []
        }

        do {
            let data = try Data(contentsOf: url)

            // فقط للدبسغ:
            // print("🔍 RAW JSON:", String(data: data, encoding: .utf8) ?? "nil")

            let decoder = JSONDecoder()

            // انتبه: ماكو keyDecodingStrategy هنا
            // حتى يبقى متوقع نفس أسماء الحقول تماماً مثل JSON

            let meals = try decoder.decode([Meal].self, from: data)
            print("✅ LocalMealsRepository: loaded \(meals.count) meals")
            return meals
        } catch {
            print("❌ LocalMealsRepository decode error:", error)
            return []
        }
    }

    // وجبات حسب نوعها (فطور / غداء / عشاء)
    func fetchMeals(of type: MealType) async throws -> [Meal] {
        let all = try await fetchAllMeals()
        let filtered = all.filter { $0.mealType == type }
        print("📊 LocalMealsRepository: filtered \(filtered.count) meals for type \(type)")
        return filtered
    }
}
