import Foundation

final class AiQoCoachService {
    static let shared = AiQoCoachService()
    private init() {}

    func sendToCoach(message: String) async throws -> String {
        try await CaptainService.shared.sendCoachPrompt(message)
    }

    func generateSmartNotification(currentSteps: Int) async -> String {
        let prompt = """
        User current steps today: \(currentSteps).
        Write one short Iraqi Arabic motivational line (max 14 words).
        """

        do {
            return try await sendToCoach(message: prompt)
        } catch {
            if currentSteps < 2000 {
                return "يلا بطل، قوم هسه وخلي أول ألف خطوة باسمك اليوم."
            } else if currentSteps < 6000 {
                return "ممتاز، كمل نفس الهمة وخل نرفعها شوي شوي."
            } else {
                return "عفية عليك، تقدمك واضح اليوم، استمر وخليها عادة."
            }
        }
    }
}
