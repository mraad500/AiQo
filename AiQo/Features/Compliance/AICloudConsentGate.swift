import Foundation

enum AICloudConsentGate {
    static func hasConsent() async -> Bool {
        await MainActor.run {
            AIDataConsentManager.shared.hasUserConsented
        }
    }

    static func requireConsent(presentIfPossible: Bool = false) async throws {
        let hasConsent = await MainActor.run {
            AIDataConsentManager.shared.ensureConsent(presentIfPossible: presentIfPossible)
        }

        guard hasConsent else {
            throw AIDataConsentError.consentRequired
        }
    }
}
