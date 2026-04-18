import Foundation
import os.log

/// On-device-only audit trail for every outbound cloud LLM request.
///
/// Each entry records metadata (not content) about a cloud call:
/// destination, tier, byte counts, latency, consent state, outcome.
/// The raw prompt and response are NEVER persisted — only their sizes.
///
/// File: `~/Documents/brain_audit.log.json` (ring of last `maxEntries`).
/// Caller: `CloudBrainService.generateReply` wraps every Gemini call.
/// Viewer: BrainDashboard (future debug surface) reads `recentEntries()`.
actor AuditLogger {
    static let shared = AuditLogger()

    struct Entry: Codable, Identifiable, Sendable {
        let id: UUID
        let timestamp: Date
        /// Model identifier — e.g. "gemini-3-flash-preview" or "gemini-2.5-flash".
        let destination: String
        /// Tier label — "max" | "pro" | "trial" | "none".
        let tier: String
        let promptBytes: Int
        let responseBytes: Int
        let latencyMs: Int
        let consentGranted: Bool
        let sanitizationApplied: Bool
        /// Purpose label from `RequestPurpose.rawValue`.
        let purpose: String
        let outcome: Outcome

        enum Outcome: String, Codable, Sendable {
            case success
            case failure
            case sanitizerBlocked
            case consentDenied
            case rateLimit
        }
    }

    private let logger = Logger(subsystem: "com.mraad500.aiqo", category: "BrainAudit")
    private let maxEntries: Int
    private var entries: [Entry] = []
    private let fileURL: URL
    private var didLoad = false

    init(maxEntries: Int = 500) {
        self.maxEntries = maxEntries
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.fileURL = docs.appendingPathComponent("brain_audit.log.json")
    }

    func record(_ entry: Entry) {
        if !didLoad { loadFromDisk() }
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
        logger.log("\(entry.destination, privacy: .public) \(entry.outcome.rawValue, privacy: .public) \(entry.latencyMs, privacy: .public)ms tier=\(entry.tier, privacy: .public) purpose=\(entry.purpose, privacy: .public)")
        saveToDisk()
    }

    func recentEntries(limit: Int = 50) -> [Entry] {
        if !didLoad { loadFromDisk() }
        let clampedLimit = max(0, limit)
        return Array(entries.suffix(clampedLimit).reversed())
    }

    func clear() {
        entries.removeAll()
        try? FileManager.default.removeItem(at: fileURL)
    }

    // MARK: - Persistence

    private func loadFromDisk() {
        didLoad = true
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let decoded = try? decoder.decode([Entry].self, from: data) else { return }
        entries = decoded
    }

    private func saveToDisk() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

// MARK: - Tier Label Helper

extension SubscriptionTier {
    /// Stable label for audit persistence. Keep values stable so old logs stay readable.
    var auditLabel: String {
        switch self {
        case .none: return "none"
        case .core: return "max"
        case .intelligencePro: return "pro"
        }
    }
}
