import Foundation

enum BrainError: LocalizedError {
    case tierRequired(SubscriptionTier)
    case consentRequired
    case rateLimited
    case networkUnavailable
    case invalidResponse
    case sanitizerRejected
    case backgroundTimeExpired

    var errorDescription: String? {
        switch self {
        case .tierRequired(let tier):
            return "This feature requires \(tier.displayName)."
        case .consentRequired:
            return "AI consent required."
        case .rateLimited:
            return "Please wait before trying again."
        case .networkUnavailable:
            return "Network unavailable."
        case .invalidResponse:
            return "Invalid response from AI."
        case .sanitizerRejected:
            return "Content rejected for privacy reasons."
        case .backgroundTimeExpired:
            return "Background task time expired."
        }
    }
}
