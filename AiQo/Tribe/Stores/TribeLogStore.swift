import Foundation
import Combine

@MainActor
final class TribeLogStore: ObservableObject {
    @Published private(set) var events: [TribeEvent] = []

    func load(from source: [TribeEvent]) {
        events = source
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(30)
            .map { $0 }
    }

    func record(_ event: TribeEvent) {
        events.insert(event, at: 0)
        if events.count > 30 {
            events = Array(events.prefix(30))
        }
    }

    var latestEvents: [TribeEvent] {
        Array(events.prefix(10))
    }
}
