import Foundation
import os.log

final class DiagnosticsLogger {
    static let shared = DiagnosticsLogger()

    private let logger = Logger(subsystem: "app.aiqo", category: "Brain")

    private init() {}

    func debug(_ message: String, file: String = #fileID, line: Int = #line) {
#if DEBUG
        logger.debug("\(Self.loc(file, line), privacy: .public) \(message, privacy: .public)")
#endif
    }

    func info(_ message: String, file: String = #fileID, line: Int = #line) {
        logger.info("\(Self.loc(file, line), privacy: .public) \(message, privacy: .public)")
    }

    func warning(_ message: String, file: String = #fileID, line: Int = #line) {
        logger.warning("\(Self.loc(file, line), privacy: .public) \(message, privacy: .public)")
    }

    func error(_ message: String, error: Error? = nil, file: String = #fileID, line: Int = #line) {
        if let error {
            logger.error(
                "\(Self.loc(file, line), privacy: .public) \(message, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
        } else {
            logger.error("\(Self.loc(file, line), privacy: .public) \(message, privacy: .public)")
        }
    }

    func logTierGate(
        feature: String,
        tier: SubscriptionTier,
        requiredTier: SubscriptionTier,
        allowed: Bool,
        file: String,
        line: Int
    ) {
        let message = "TierGate feature=\(feature) tier=\(tier.displayName) required=\(requiredTier.displayName) allowed=\(allowed)"
        if allowed {
            logger.info("\(Self.loc(file, line), privacy: .public) \(message, privacy: .public)")
        } else {
            logger.warning("\(Self.loc(file, line), privacy: .public) \(message, privacy: .public)")
        }
    }

    private static func loc(_ file: String, _ line: Int) -> String {
        "[\((file as NSString).lastPathComponent):\(line)]"
    }
}

let diag = DiagnosticsLogger.shared
