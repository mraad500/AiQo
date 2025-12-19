import Foundation

// هدف التغذية
enum NutritionGoal: String, Codable {
    case fatLoss      = "fat_loss"
    case muscleGain   = "muscle_gain"
    case maintenance  = "maintenance"
}

// شكل الوجبة جاية من الـ API
private struct APIMealItem: Codable {
    let title: String
    let calories: Int
}

private struct APIMealCard: Codable {
    let section: String              // Breakfast / Lunch / Dinner
    let totalCaloriesText: String    // "Approx. 400–500 kcal"
    let imageName: String?          // اسم الصورة أو URL كنص
    let items: [APIMealItem]
}

private struct APIMealPlanResponse: Codable {
    let meals: [APIMealCard]
}

// خدمة واحدة لكل التطبيق
final class KitchenAIService {

    static let shared = KitchenAIService()

    private let session: URLSession = .shared
    private let baseURL: URL
    private let anonKey: String

    private init() {
        // نقرأ بيانات Supabase من Info.plist
        let info = Bundle.main.infoDictionary ?? [:]
        let supabaseURLString = (info["SUPABASE_URL"] as? String) ?? ""
        let anon = (info["SUPABASE_ANON_KEY"] as? String) ?? ""

        // مثال: https://bupiijjcbfchauedcisl.supabase.co
        // دوال Edge: https://bupiijjcbfchauedcisl.functions.supabase.co
        if let url = URL(string: supabaseURLString
            .replacingOccurrences(of: ".supabase.co", with: ".functions.supabase.co")) {
            self.baseURL = url
        } else {
            self.baseURL = URL(string: "https://example.functions.supabase.co")!
        }
        self.anonKey = anon
    }

    struct MealPlanRequest: Codable {
        let goal: NutritionGoal
        let targetCalories: Int
        let gender: String          // "male" / "female"
        let age: Int
        let heightCm: Int
        let weightKg: Int
        let activityLevel: String   // "low" / "medium" / "high"
    }

    /// نداء رئيسي: يرجع Meals جاهزة للـ UI
    func fetchTodayPlan(request: MealPlanRequest) async throws -> [MealCardData] {
        // اسم الـ Edge Function بس غيّره إذا سويته باسم ثاني
        let functionPath = "/generate-meal-plan"
        let url = baseURL.appendingPathComponent(functionPath)

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue(anonKey, forHTTPHeaderField: "apikey")

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await session.data(for: urlRequest)

        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "KitchenAIService",
                          code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])
        }

        let decoder = JSONDecoder()
        let api = try decoder.decode(APIMealPlanResponse.self, from: data)

        // تحويل شكل الـ API → شكل الـ UI
        let mapped: [MealCardData] = api.meals.map { meal in
            MealCardData(
                sectionTitle: meal.section,
                items: meal.items.map { MealItem(title: $0.title, calories: $0.calories) },
                totalCaloriesText: meal.totalCaloriesText,
                imageName: meal.imageName ?? ""   // تقدر تخلي nil إذا تريد
            )
        }
        return mapped
    }
}
