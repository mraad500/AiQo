import Foundation

// MARK: - 📦 Response Models
struct CoachReplyResponse: Decodable {
    let reply: String
}

// MARK: - 🧠 The Service
final class AiQoCoachService {

    static let shared = AiQoCoachService()

    // Configuration
    private let baseURL = URL(string: "https://aiqo-proxy.mraad8000.workers.dev")!

    // ⚠️ بالمستقبل خليه بملف آمن او يجيبه من السيرفر
    private let appKey = "super_secret_aiqo_key_123"

    // ⚠️ لازم يصير Dynamic حسب اليوزر
    private let profileID = "demo-hamoudi-001"

    private init() {}

    // MARK: - ✅ Customization Keys (نفس اللي عند CaptainCustomizationViewController)
    private enum CustomKeys {
        static let name    = "captain_user_name"
        static let age     = "captain_user_age"
        static let height  = "captain_user_height"
        static let weight  = "captain_user_weight"
        static let calling = "captain_calling"
        static let tone    = "captain_tone"
    }

    // MARK: - ✅ Customization Model
    private struct CaptainUserCustomization: Encodable {
        let preferred_name: String
        let preferred_address: String
        let captain_tone: String
        let age: Int?
        let height_cm: Int?
        let weight_kg: Int?
    }

    private func loadCustomization() -> CaptainUserCustomization {
        let d = UserDefaults.standard

        let preferredName = (d.string(forKey: CustomKeys.name) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let preferredAddress = (d.string(forKey: CustomKeys.calling) ?? "حبيبي")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let tone = (d.string(forKey: CustomKeys.tone) ?? "عملي")
            .trimmingCharacters(in: .whitespacesAndNewlines)

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

    // MARK: - 📤 Request Models
    private struct CoachRequest: Encodable {
        let profile_id: String
        let prompt: String
        let customization: CaptainUserCustomization
    }

    private struct DailyMetricPayload: Encodable {
        let profile_id: String
        let date: String
        let steps: Int
        let calories: Int
        let water_ml: Int
    }

    // MARK: - 1️⃣ Chat with Captain
    /// يرسل رسالة للكابتن ويرجع الجواب + يرسل وياها تخصيص المستخدم
    func sendToCoach(message: String) async throws -> String {
        var url = baseURL
        url.appendPathComponent("coach")

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(appKey, forHTTPHeaderField: "x-app-key")

        let customization = loadCustomization()
        let body = CoachRequest(profile_id: profileID, prompt: message, customization: customization)
        req.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: req)

        guard let http = response as? HTTPURLResponse else {
            throw makeError(code: -1, message: "No HTTP response")
        }

        guard (200..<300).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Coach API Error: \(http.statusCode) - \(text)")
            throw makeError(code: http.statusCode, message: "Server error: \(text)")
        }

        do {
            let decoded = try JSONDecoder().decode(CoachReplyResponse.self, from: data)
            return decoded.reply
        } catch {
            print("❌ Decoding Error: \(error)")
            throw makeError(code: -2, message: "Invalid data format")
        }
    }

    // MARK: - 2️⃣ Sync Metrics
    func syncDailyMetrics(steps: Int, calories: Int, water: Int) async {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let dateStr = formatter.string(from: Date())

        let payload = DailyMetricPayload(
            profile_id: profileID,
            date: dateStr,
            steps: steps,
            calories: calories,
            water_ml: water
        )

        var url = baseURL
        url.appendPathComponent("v1/metrics/upsert")

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(appKey, forHTTPHeaderField: "x-app-key")

        do {
            req.httpBody = try JSONEncoder().encode(payload)
            let (_, response) = try await URLSession.shared.data(for: req)

            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                print("✅ Data synced: Steps=\(steps)")
            } else {
                print("⚠️ Sync Warning: non-200")
            }
        } catch {
            print("❌ Sync Failed: \(error.localizedDescription)")
        }
    }

    // MARK: - 3️⃣ Smart Notification
    func generateSmartNotification(currentSteps: Int) async -> String {
        let hiddenPrompt = """
        [System Instruction: Act as Captain Hamoudi]
        [Context: User Steps = \(currentSteps)]

        Task: Write a ONE-SENTENCE push notification in Iraqi Arabic dialect.

        Rules:
        - If steps > 8000: Be super excited and proud. Use emojis like 🔥🦁.
        - If steps < 2000: Gentle encouragement to start moving. Use emojis like 🚶‍♂️⚠️.
        - Tone: Friendly, brotherly, motivating.
        - Output: ONLY the Arabic text. No quotes. No English.
        """

        do {
            let reply = try await sendToCoach(message: hiddenPrompt)
            return reply.replacingOccurrences(of: "\"", with: "")
        } catch {
            if currentSteps > 5000 {
                return "عاشت ايدك يا بطل! استمر هيج 🔥"
            } else {
                return "حمودي.. المشي ينتظرك، كوم تحرك شوية! 🚶‍♂️"
            }
        }
    }

    // MARK: - Helpers
    private func makeError(code: Int, message: String) -> NSError {
        NSError(domain: "AiQoCoachService",
                code: code,
                userInfo: [NSLocalizedDescriptionKey: message])
    }
}
