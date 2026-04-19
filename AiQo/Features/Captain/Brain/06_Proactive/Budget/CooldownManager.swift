import Foundation

/// Tracks when each NotificationKind was last delivered.
/// Used to prevent back-to-back duplicate kinds.
public actor CooldownManager {
    public static let shared = CooldownManager()

    private var lastDelivered: [NotificationKind: Date] = [:]
    private var lastAnyDelivery: Date?

    // Global minimum spacing between any two notifications
    private let globalCooldownSeconds: TimeInterval = 2 * 3600   // 2h

    // Per-kind minimum spacing — different kinds can still interleave
    private let perKindCooldownSeconds: TimeInterval = 6 * 3600  // 6h

    private init() {}

    /// Returns true if delivering this kind right now would violate cooldown.
    public func isOnCooldown(_ kind: NotificationKind, now: Date = Date()) -> Bool {
        if let last = lastAnyDelivery,
           now.timeIntervalSince(last) < globalCooldownSeconds {
            return true
        }
        if let last = lastDelivered[kind],
           now.timeIntervalSince(last) < perKindCooldownSeconds {
            return true
        }
        return false
    }

    public func recordDelivery(_ kind: NotificationKind, at date: Date = Date()) {
        lastDelivered[kind] = date
        lastAnyDelivery = date
    }

    public func resetAll() {
        lastDelivered.removeAll()
        lastAnyDelivery = nil
    }

    /// Testing aid.
    #if DEBUG
    public func _force(lastDelivery: Date?, forKind: NotificationKind?) {
        if let kind = forKind {
            lastDelivered[kind] = lastDelivery
        }
        lastAnyDelivery = lastDelivery
    }
    #endif
}
