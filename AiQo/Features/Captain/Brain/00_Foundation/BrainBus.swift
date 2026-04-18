import Foundation

// AiQo Brain OS — 00_Foundation
// Status: SCAFFOLDING (P1.1)
// TODO(P3+): implement pub/sub for cross-component signals.

public actor BrainBus {
    public static let shared = BrainBus()
    private init() {}

    public enum Event {
        case userMessageSent(String)
        case captainReplied(String)
        case notificationDelivered(UUID)
        case memoryExtracted([UUID])
        case tierChanged
    }

    private var subscribers: [(Event) -> Void] = []

    public func subscribe(_ handler: @escaping (Event) -> Void) {
        subscribers.append(handler)
    }

    public func publish(_ event: Event) {
        subscribers.forEach { $0(event) }
    }
}
