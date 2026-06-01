import Foundation

// AiQo Brain OS — 00_Foundation
// Status: IMPLEMENTED & LOAD-BEARING (not scaffolding). Minimal in-memory
// pub/sub for decoupled cross-component signals. Live consumer:
// BrainBusObserver, subscribed exactly once at AppDelegate launch, which
// wires the 11_Directives lifecycle (directiveLearned / directiveFired /
// workoutCompleted) into Observability + CaptainMetricsCounter — i.e. the
// "teach Captain standing instructions" feature depends on this working.

public actor BrainBus {
    public static let shared = BrainBus()
    private init() {}

    public enum Event {
        case userMessageSent(String)
        case captainReplied(String)
        case notificationDelivered(UUID)
        case memoryExtracted([UUID])
        case tierChanged
        // 11_Directives — standing-order lifecycle signals so any layer
        // (Observability, Learning, Memory) can react without tight coupling.
        case directiveLearned(UUID)
        case directiveFired(UUID)
        case workoutCompleted
    }

    private var subscribers: [(Event) -> Void] = []

    public func subscribe(_ handler: @escaping (Event) -> Void) {
        subscribers.append(handler)
    }

    public func publish(_ event: Event) {
        subscribers.forEach { $0(event) }
    }
}
