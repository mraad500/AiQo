import Foundation
import SwiftData

@Model
final class SmartFridgeScannedItemRecord {
    var id: UUID
    var name: String
    var quantity: Double
    var unit: String?
    var alchemyNoteKey: String?
    var capturedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        quantity: Double,
        unit: String? = nil,
        alchemyNoteKey: String? = nil,
        capturedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.alchemyNoteKey = alchemyNoteKey
        self.capturedAt = capturedAt
    }

    convenience init(item: FridgeItem, capturedAt: Date = Date()) {
        self.init(
            name: item.name,
            quantity: item.quantity,
            unit: item.unit,
            alchemyNoteKey: item.alchemyNoteKey,
            capturedAt: capturedAt
        )
    }
}
