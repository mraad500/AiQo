import Foundation

/// أخطاء التطبيق الموحدة — كل الأخطاء تمر من هنا
enum AiQoError: LocalizedError {
    // Network
    case noInternet
    case serverUnreachable
    case timeout
    case serverError(statusCode: Int)

    // AI / Captain
    case captainUnavailable
    case captainRateLimited
    case captainResponseInvalid
    case visionAnalysisFailed

    // Health
    case healthKitUnavailable
    case healthKitPermissionDenied

    // Premium
    case purchaseFailed(reason: String)
    case trialExpired

    // Tribe
    case tribeNotFound
    case tribeAccessDenied
    case tribeFull
    case tribeAlreadyJoined

    // Auth
    case notAuthenticated

    // General
    case unknown(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .noInternet:
            return "error.noInternet".localized
        case .serverUnreachable:
            return "error.serverUnreachable".localized
        case .timeout:
            return "error.timeout".localized
        case .serverError(let code):
            return String(format: "error.server".localized, code)
        case .captainUnavailable:
            return "error.captainUnavailable".localized
        case .captainRateLimited:
            return "error.captainRateLimited".localized
        case .captainResponseInvalid:
            return "error.captainResponseInvalid".localized
        case .visionAnalysisFailed:
            return "error.visionAnalysisFailed".localized
        case .healthKitUnavailable:
            return "error.healthKitUnavailable".localized
        case .healthKitPermissionDenied:
            return "error.healthKitPermissionDenied".localized
        case .purchaseFailed(let reason):
            return String(format: "error.purchaseFailed".localized, reason)
        case .trialExpired:
            return "error.trialExpired".localized
        case .tribeNotFound:
            return "error.tribeNotFound".localized
        case .tribeAccessDenied:
            return "error.tribeAccessDenied".localized
        case .tribeFull:
            return "error.tribeFull".localized
        case .tribeAlreadyJoined:
            return "error.tribeAlreadyJoined".localized
        case .notAuthenticated:
            return "error.notAuthenticated".localized
        case .unknown(let error):
            return error.localizedDescription
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .noInternet:
            return "error.noInternet.recovery".localized
        case .serverUnreachable, .timeout:
            return "error.server.recovery".localized
        case .captainUnavailable, .captainRateLimited:
            return "error.captain.recovery".localized
        case .healthKitPermissionDenied:
            return "error.healthKit.recovery".localized
        case .trialExpired:
            return "error.trialExpired.recovery".localized
        default:
            return nil
        }
    }

    /// يحوّل أي خطأ عام إلى AiQoError
    static func from(_ error: Error) -> AiQoError {
        if let aiqoError = error as? AiQoError {
            return aiqoError
        }

        let nsError = error as NSError

        // Network errors
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
                return .noInternet
            case NSURLErrorTimedOut:
                return .timeout
            case NSURLErrorCannotConnectToHost, NSURLErrorCannotFindHost:
                return .serverUnreachable
            default:
                return .unknown(underlying: error)
            }
        }

        return .unknown(underlying: error)
    }
}
