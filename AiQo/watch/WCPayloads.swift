import Foundation

struct LiveMetricsPayload: Codable {
    let heartRate: Double
    let activeEnergy: Double
    let elapsed: TimeInterval
    let distance: Double // المسافة بالأمتار
    let timestamp: Date
}
