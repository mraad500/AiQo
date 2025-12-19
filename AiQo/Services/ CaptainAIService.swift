import Foundation

// نفس الحقول اللي نرسلها للـ Edge Function
struct CaptainNotificationContext: Codable {
    let name: String
    let age: Int
    let height_cm: Int
    let weight_kg: Int
    let goal_text: String
    let steps_today: Int
    let steps_goal: Int
    let active_kcal_today: Int
    let active_kcal_goal: Int
    let language: String
}

// شكل الرد من Supabase function
private struct CaptainNotificationResponse: Decodable {
    let message: String?
    let error: String?
}

final class CaptainAIService {
    
    static let shared = CaptainAIService()
    
    private let session = URLSession.shared
    
    // ⬅️ هذا هو اللينك مالك
    private let functionURL = URL(string: "https://zidbsrepqpbucqzxnwgk.supabase.co/functions/v1/captain_notification")!
    
    // ⚠️ خزن الـ anon key بالـ Info.plist و اقراه هنا
    // مؤقتاً للتجارب اكدر تخليه نص مباشر بس انتبه لا ترفعه على Git
    private let anonKey: String = "<SUPABASE_ANON_KEY_HERE>"
    
    private init() {}
    
    /// ترجع رسالة الكابتن الجاهزة للنوتيفيكيشن
    func generateMessage(context: CaptainNotificationContext) async throws -> String {
        var request = URLRequest(url: functionURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        
        // body: { "context": { ... } }
        let body: [String: Any] = ["context": [
            "name": context.name,
            "age": context.age,
            "height_cm": context.height_cm,
            "weight_kg": context.weight_kg,
            "goal_text": context.goal_text,
            "steps_today": context.steps_today,
            "steps_goal": context.steps_goal,
            "active_kcal_today": context.active_kcal_today,
            "active_kcal_goal": context.active_kcal_goal,
            "language": context.language
        ]]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        
        let (data, response) = try await session.data(for: request)
        
        if let http = response as? HTTPURLResponse {
            print("🌐 captain_notification status:", http.statusCode)
        }
        
        let decoded = try JSONDecoder().decode(CaptainNotificationResponse.self, from: data)
        
        if let error = decoded.error {
            print("⚠️ captain_notification error:", error)
        }
        
        return decoded.message ?? "اليوم بعدك تكدر تلحق هدفك، قوم تحرك شوية وخليها أقوى نسخة منك 💛"
    }
}
