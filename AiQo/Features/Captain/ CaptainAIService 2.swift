import Foundation

struct CaptainUserCustomization: Codable {
    let preferred_name: String
    let preferred_address: String
    let captain_tone: String
    let age: Int?
    let height_cm: Int?
    let weight_kg: Int?
}

final class CaptainAIService {
    static let shared = CaptainAIService()
    private init() {}

    func sendChatMessage(profileID: String, message: String) async throws -> String {
        _ = profileID
        return try await CaptainService.shared.sendUserText(message)
    }
}
