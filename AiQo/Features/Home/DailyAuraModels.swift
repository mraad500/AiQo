import Foundation

struct DailyRecord: Codable, Identifiable, Equatable, Sendable {
    let dateKey: String
    var steps: Int
    var calories: Double

    var id: String { dateKey }
}
