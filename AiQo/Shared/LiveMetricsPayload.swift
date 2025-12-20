import Foundation

struct LiveMetricsPayload: Codable {
    let heartRate: Double
    let activeEnergy: Double // ✅ تأكد من وجود هذا السطر
    let distance: Double     // ✅ وهذا
    let elapsed: TimeInterval // ✅ وهذا
    let timestamp: TimeInterval
}
