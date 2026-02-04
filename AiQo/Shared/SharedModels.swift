import Foundation

// MARK: - WC Keys
enum WCKey {
    static let kind = "kind"
    static let workoutID = "workoutID"
    static let payload = "payload"
    static let timestamp = "timestamp"
}

enum WCKind: String {
    case startWorkout
    case stopWorkout
    case liveMetrics
    case requestState
    case state
}

// MARK: - Payloads
struct LiveMetricsPayload: Codable {
    let timestamp: TimeInterval
    let elapsed: TimeInterval
    let heartRate: Double
    let activeEnergy: Double
    let distance: Double
    let isRunning: Bool
}

struct WorkoutStatePayload: Codable {
    let timestamp: TimeInterval
    let workoutID: String?
    let isRunning: Bool
    let elapsed: TimeInterval
}

// MARK: - Codable helpers
enum WCCoding {
    static func encode<T: Encodable>(_ value: T) -> Data? {
        try? JSONEncoder().encode(value)
    }
    static func decode<T: Decodable>(_ type: T.Type, from data: Data) -> T? {
        try? JSONDecoder().decode(type, from: data)
    }
}
