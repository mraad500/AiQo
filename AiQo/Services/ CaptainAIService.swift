import Foundation

// ✅ تخصيص المستخدم للكابتن (يجي من شاشة التخصيص)
struct CaptainUserCustomization: Codable {
    let preferred_name: String
    let preferred_address: String
    let captain_tone: String
    let age: Int?
    let height_cm: Int?
    let weight_kg: Int?
}

// ✅ body اللي يفهمه Cloudflare Worker (/coach)
private struct CaptainCoachRequest: Codable {
    let profile_id: String
    let prompt: String
    let customization: CaptainUserCustomization
}

// ✅ رد الووركر
private struct CaptainCoachResponse: Decodable {
    let reply: String?
    let error: String?
    let details: String?
}

final class CaptainAIService {

    static let shared = CaptainAIService()
    private let session = URLSession.shared

    // ✅ Cloudflare Worker endpoint
    // مثال: https://aiqo-proxy.mraad8000.workers.dev/coach
    private let coachURL = URL(string: "https://aiqo-proxy.mraad8000.workers.dev/coach")!

    // ✅ نفس APP_KEY اللي حاطه بالـWorker env
    // حطه بـ Info.plist أفضل، بس هسه خليته نص للتجربة
    private let appKey: String = "<APP_KEY_HERE>"

    private init() {}

    // MARK: - Read customization from UserDefaults
    private enum CustomKeys {
        static let name = "captain_user_name"
        static let age = "captain_user_age"
        static let height = "captain_user_height"
        static let weight = "captain_user_weight"
        static let calling = "captain_calling"
        static let tone = "captain_tone"
    }

    private func loadCustomization() -> CaptainUserCustomization {
        let d = UserDefaults.standard

        let preferredName = (d.string(forKey: CustomKeys.name) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let preferredAddress = (d.string(forKey: CustomKeys.calling) ?? "حبيبي").trimmingCharacters(in: .whitespacesAndNewlines)
        let tone = (d.string(forKey: CustomKeys.tone) ?? "عملي").trimmingCharacters(in: .whitespacesAndNewlines)

        // age/height/weight إذا المستخدم خزنهم كنص
        let ageInt = Int((d.string(forKey: CustomKeys.age) ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
        let heightInt = Int((d.string(forKey: CustomKeys.height) ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
        let weightInt = Int((d.string(forKey: CustomKeys.weight) ?? "").trimmingCharacters(in: .whitespacesAndNewlines))

        return CaptainUserCustomization(
            preferred_name: preferredName.isEmpty ? "Unknown" : preferredName,
            preferred_address: preferredAddress.isEmpty ? "حبيبي" : preferredAddress,
            captain_tone: tone.isEmpty ? "عملي" : tone,
            age: ageInt,
            height_cm: heightInt,
            weight_kg: weightInt
        )
    }

    // MARK: - ✅ Send chat to Cloudflare Worker (/coach) with customization
    func sendChatMessage(profileID: String, message: String) async throws -> String {
        let customization = loadCustomization()

        let payload = CaptainCoachRequest(
            profile_id: profileID,
            prompt: message,
            customization: customization
        )

        var request = URLRequest(url: coachURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(appKey, forHTTPHeaderField: "x-app-key")

        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)

        if let http = response as? HTTPURLResponse {
            print("🌐 /coach status:", http.statusCode)
        }

        let decoded = try JSONDecoder().decode(CaptainCoachResponse.self, from: data)

        if let error = decoded.error {
            print("⚠️ /coach error:", error, decoded.details ?? "")
        }

        return decoded.reply ?? "تمام \(customization.preferred_address)، خلّ نسوي خطوة بسيطة هسه."
    }
}
