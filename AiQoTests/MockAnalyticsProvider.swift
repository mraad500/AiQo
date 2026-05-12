import Foundation
@testable import AiQo

/// Captures analytics events for verification in unit tests.
/// Internally serial — safe to use from concurrent contexts; assertions
/// always read a stable snapshot.
final class MockAnalyticsProvider: AnalyticsProvider, @unchecked Sendable {
    private let queue = DispatchQueue(label: "test.analytics.mock")
    private var _events: [(name: String, properties: [String: Any])] = []
    private var _identifyCalls: [(userId: String, traits: [String: Any])] = []
    private var _resetCount = 0

    var events: [(name: String, properties: [String: Any])] {
        queue.sync { _events }
    }

    var eventNames: [String] {
        queue.sync { _events.map(\.name) }
    }

    var identifyCalls: [(userId: String, traits: [String: Any])] {
        queue.sync { _identifyCalls }
    }

    var resetCount: Int {
        queue.sync { _resetCount }
    }

    func track(_ event: AnalyticsEvent) {
        queue.sync { _events.append((event.name, event.properties)) }
    }

    func identify(userId: String, traits: [String: Any]) {
        queue.sync { _identifyCalls.append((userId, traits)) }
    }

    func reset() {
        queue.sync { _resetCount += 1 }
    }

    func clear() {
        queue.sync {
            _events.removeAll()
            _identifyCalls.removeAll()
            _resetCount = 0
        }
    }

    func eventCount(named name: String) -> Int {
        queue.sync { _events.filter { $0.name == name }.count }
    }
}
