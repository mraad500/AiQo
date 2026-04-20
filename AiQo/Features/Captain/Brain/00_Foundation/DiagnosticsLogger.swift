import Foundation
import os.log

final class DiagnosticsLogger: @unchecked Sendable {
    nonisolated static let shared = DiagnosticsLogger()

    nonisolated private let logger = Logger(subsystem: "app.aiqo", category: "Brain")

    nonisolated private init() {}

    nonisolated func debug(_ message: String, file: String = #fileID, line: Int = #line) {
#if DEBUG
        logger.debug("\(Self.loc(file, line), privacy: .public) \(message, privacy: .public)")
#endif
    }

    nonisolated func info(_ message: String, file: String = #fileID, line: Int = #line) {
        logger.info("\(Self.loc(file, line), privacy: .public) \(message, privacy: .public)")
    }

    nonisolated func warning(_ message: String, file: String = #fileID, line: Int = #line) {
        logger.warning("\(Self.loc(file, line), privacy: .public) \(message, privacy: .public)")
    }

    nonisolated func error(_ message: String, error: Error? = nil, file: String = #fileID, line: Int = #line) {
        if let error {
            logger.error(
                "\(Self.loc(file, line), privacy: .public) \(message, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
        } else {
            logger.error("\(Self.loc(file, line), privacy: .public) \(message, privacy: .public)")
        }
    }

    nonisolated func logTierGate(
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

    nonisolated private static func loc(_ file: String, _ line: Int) -> String {
        "[\((file as NSString).lastPathComponent):\(line)]"
    }
}

nonisolated let diag = DiagnosticsLogger.shared
