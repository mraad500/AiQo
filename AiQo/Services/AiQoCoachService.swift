import Foundation

struct CoachReplyResponse: Decodable {
    let reply: String
}

final class AiQoCoachService {

    static let shared = AiQoCoachService()

    private let baseURL = URL(string: "https://aiqo-proxy.mraad8000.workers.dev")!

    // لازم تكون نفس APP_KEY في Cloudflare
    private let appKey = "super_secret_aiqo_key_123"

    private let profileID = "demo-hamoudi-001"

    private init() {}

    private struct CoachRequest: Encodable {
        let profile_id: String
        let prompt: String
    }

    func sendToCoach(message: String) async throws -> String {
        var url = baseURL
        url.appendPathComponent("coach")

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(appKey, forHTTPHeaderField: "x-app-key")

        let body = CoachRequest(profile_id: profileID, prompt: message)
        req.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: req)

        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "AiQoCoachService",
                          code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "No HTTP response"])
        }

        guard (200..<300).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            print("Coach error: \(http.statusCode) - \(text)")
            throw NSError(domain: "AiQoCoachService",
                          code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "Server error \(http.statusCode)"])
        }

        let decoded = try JSONDecoder().decode(CoachReplyResponse.self, from: data)
        return decoded.reply
    }
}
